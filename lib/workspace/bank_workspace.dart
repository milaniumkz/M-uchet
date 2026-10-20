import 'company_access.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'commercial_detail.dart';
import 'input_dialogs.dart';
import 'cash_workspace.dart';
import 'journal_editor.dart';

const bankCategories = {
  'INCOME': 'Доход',
  'EXPENSE': 'Расход',
  'CAPITAL': 'Вклад собственника',
  'DOCUMENT': 'Оплата документа',
  'EXISTING': 'Уже учтённая операция',
  'IGNORE': 'Не проводить',
};

class BankWorkspace extends StatefulWidget {
  const BankWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
    required this.onEditMoney,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  final Future<void> Function(Map<String, dynamic>) onEditMoney;
  @override
  State<BankWorkspace> createState() => _BankWorkspaceState();
}

class _BankWorkspaceState extends State<BankWorkspace> {
  List<Map<String, dynamic>> wallets = [], imports = [], rows = [];
  String? selectedImport, error;
  bool busy = false;
  bool opening = false;
  final pending = <String, RetriableCommand>{};
  List<String> path([String? id]) => [
    'v1',
    'companies',
    widget.companyId,
    'bank-imports',
    if (id != null) id,
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final money = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'wallets'],
          query: {'limit': '200'},
        ),
      );
      final statements = jsonObject(await widget.api.request('GET', path()));
      var next = <Map<String, dynamic>>[];
      if (selectedImport != null) {
        final details = jsonObject(
          await widget.api.request('GET', path(selectedImport)),
        );
        next = (details['items'] as List).map(jsonObject).toList();
      }
      if (mounted) {
        setState(() {
          wallets = (money['items'] as List).map(jsonObject).toList();
          imports = (statements['items'] as List).map(jsonObject).toList();
          rows = next;
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> upload() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BankUpload(
        api: widget.api,
        companyId: widget.companyId,
        wallets: wallets,
      ),
    );
    if (result != null && mounted) {
      setState(() => selectedImport = result['id'] as String);
      await load();
    }
  }

  Future<void> createWallet() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const TextPromptDialog(
        title: 'Новый денежный счёт',
        label: 'Название счёта',
        confirm: 'Создать',
      ),
    );
    if (name == null) {
      return;
    }
    final command = RetriableCommand(
      'POST',
      ['v1', 'companies', widget.companyId, 'wallets'],
      {'name': name, 'scope': 'ACCOUNTING'},
    );
    await execute('wallet', command);
  }

  Future<void> execute(String id, RetriableCommand command) async {
    pending.putIfAbsent(id, () => command);
    setState(() => busy = true);
    try {
      await pending[id]!.execute(widget.api);
      pending.remove(id);
      await widget.onChanged();
      await load();
    } on BackendException catch (e) {
      if (!RetriableCommand.uncertain(e)) {
        pending.remove(id);
      }
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> review(Map<String, dynamic> row) async {
    if (busy || opening) {
      return;
    }
    opening = true;
    try {
      await reviewSource(row);
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      opening = false;
    }
  }

  Future<void> reviewSource(Map<String, dynamic> row) async {
    if (row['journal_id'] != null) {
      if (row['document_id'] != null) {
        final doc = await CommercialRepository(
          widget.api,
          widget.companyId,
        ).get(row['document_id'] as String);
        if (!mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CommercialDetail(
              api: widget.api,
              companyId: widget.companyId,
              currency: widget.currency,
              document: doc,
              projects: widget.projects,
              onChanged: widget.onChanged,
            ),
          ),
        );
      } else if ([
        'TRANSFER_IN',
        'TRANSFER_OUT',
      ].contains(row['current_kind'])) {
        await showWalletTransfer(
          context,
          api: widget.api,
          companyId: widget.companyId,
          currency: widget.currency,
          transferId: row['current_reference_id'] as String,
        );
      } else if (![
        'INCOME',
        'EXPENSE',
        'CAPITAL',
      ].contains(row['current_kind'])) {
        if (!hasCompanyPermission(context, 'accounting.read')) {
          setState(
            () => error =
                'Для открытия проводки нужно право просмотра бухгалтерского журнала.',
          );
          return;
        }
        final entry = jsonObject(
          await widget.api.request('GET', [
            'v1',
            'companies',
            widget.companyId,
            'accounting',
            'journal',
            row['journal_id'] as String,
          ]),
        );
        if (!mounted) {
          return;
        }
        await showDialog<bool>(
          context: context,
          builder: (_) => JournalEditor(
            api: widget.api,
            companyId: widget.companyId,
            projects: widget.projects,
            entry: entry,
          ),
        );
      } else {
        await widget.onEditMoney({
          ...row,
          'id': row['wallet_entry_id'],
          'wallet_id': row['wallet_id'],
          'kind': row['current_kind'],
          'amount': row['current_amount'],
          'business_date': row['current_business_date'],
          'description': row['current_description'],
          'project_id': row['current_project_id'],
        });
      }
      await load();
      return;
    }
    await showDialog<bool>(
      context: context,
      builder: (_) => BankReview(
        api: widget.api,
        companyId: widget.companyId,
        importId: selectedImport!,
        row: row,
        projects: widget.projects,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 12,
        children: [
          const Text(
            'Деньги и банковские выписки',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed:
                busy ||
                    wallets.isEmpty ||
                    !hasCompanyPermission(context, 'bank.import')
                ? null
                : upload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Загрузить выписку'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          ...wallets.map(
            (w) => Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'] as String),
                    const SizedBox(height: 10),
                    Text(
                      moneyText(w['balance'] as num, widget.currency),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed:
                busy ||
                    pending.containsKey('wallet') ||
                    !hasCompanyPermission(context, 'wallets.write')
                ? null
                : createWallet,
            icon: const Icon(Icons.add),
            label: const Text('Добавить счёт'),
          ),
        ],
      ),
      if (pending.containsKey('wallet'))
        TextButton(
          onPressed: busy ? null : () => execute('wallet', pending['wallet']!),
          child: const Text('Повторить создание счёта'),
        ),
      const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      if (imports.isEmpty && !busy)
        const Text(
          'Выписок пока нет. Загрузите CSV, проверьте операции и подтвердите проведение.',
        ),
      ...imports.map(
        (item) => Card(
          elevation: 0,
          child: ListTile(
            selected: selectedImport == item['id'],
            title: Text(item['name'] as String),
            subtitle: Text(
              '${item['wallet_name']} · ${item['row_count']} операций · ${item['posted_count']} проведено',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy
                ? null
                : () {
                    setState(() => selectedImport = item['id'] as String);
                    load();
                  },
          ),
        ),
      ),
      if (selectedImport != null) ...[
        const SizedBox(height: 24),
        const Text(
          'Сопоставить операции',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Проверьте назначение каждой строки. Оплату уже созданного счёта или акта связывайте с документом, чтобы не учитывать доход дважды.',
        ),
        ...rows.map(
          (row) => Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['business_date']} · ${row['external_id']}',
                    style: const TextStyle(color: Color(0xFF626E84)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    row['description'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${row['counterparty']}'),
                  const SizedBox(height: 8),
                  Text(
                    moneyText(row['amount'] as num, widget.currency),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    row['payment_voided'] == true
                        ? 'Запись оплаты отменена'
                        : row['journal_id'] != null
                        ? 'Проведено'
                        : bankCategories[row['classification']] ??
                              'Требует сопоставления',
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed:
                            busy ||
                                !(row['journal_id'] == null
                                    ? hasCompanyPermission(
                                        context,
                                        'bank.review',
                                      )
                                    : row['document_id'] != null
                                    ? hasCompanyPermission(
                                        context,
                                        'documents.read',
                                      )
                                    : hasCompanyPermission(
                                        context,
                                        'wallets.transact',
                                      ))
                            ? null
                            : () => review(row),
                        child: Text(
                          row['journal_id'] != null
                              ? 'Открыть и исправить'
                              : 'Сопоставить',
                        ),
                      ),
                      if (row['journal_id'] == null &&
                          row['classification'] != null &&
                          row['classification'] != 'IGNORE')
                        FilledButton(
                          onPressed:
                              busy ||
                                  !hasCompanyPermission(context, 'bank.post') ||
                                  !hasCompanyPermission(
                                    context,
                                    'wallets.transact',
                                  ) ||
                                  (row['document_id'] != null &&
                                      !hasCompanyPermission(
                                        context,
                                        'documents.settle',
                                      ))
                              ? null
                              : () => execute(
                                  row['id'] as String,
                                  RetriableCommand(
                                    'POST',
                                    [
                                      ...path(selectedImport),
                                      'rows',
                                      row['id'] as String,
                                      'post',
                                    ],
                                    {'version': row['version']},
                                  ),
                                ),
                          child: Text(
                            pending.containsKey(row['id'])
                                ? 'Повторить проведение'
                                : 'Провести',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      TextButton.icon(
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ],
  );
}

class BankUpload extends StatefulWidget {
  const BankUpload({
    super.key,
    required this.api,
    required this.companyId,
    required this.wallets,
  });
  final BackendClient api;
  final String companyId;
  final List<Map<String, dynamic>> wallets;
  @override
  State<BankUpload> createState() => _BankUploadState();
}

class _BankUploadState extends State<BankUpload> {
  String? walletId, error;
  String csv = '', fileName = '', delimiter = ';';
  bool busy = false;
  List<Map<String, dynamic>>? preview;
  RetriableCommand? pending;
  final mapping = TextEditingController(
    text: 'date,reference,debit,credit,description,counterparty',
  );
  @override
  void initState() {
    super.initState();
    walletId = widget.wallets.isEmpty
        ? null
        : widget.wallets.first['id'] as String;
  }

  @override
  void dispose() {
    mapping.dispose();
    super.dispose();
  }

  Map<String, dynamic> body() {
    final columns = mapping.text.split(',').map((v) => v.trim()).toList();
    if (columns.length != 6) {
      throw const FormatException(
        'Укажите шесть названий колонок через запятую.',
      );
    }
    return {
      'csv': csv,
      'walletId': walletId,
      'name': fileName,
      'delimiter': delimiter,
      'mapping': Map.fromIterables([
        'date',
        'reference',
        'debit',
        'credit',
        'description',
        'counterparty',
      ], columns),
    };
  }

  Future<void> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size > 750000 || file.bytes == null) {
        throw const FormatException('Размер файла — до 750 КБ.');
      }
      final text = utf8.decode(file.bytes!);
      if (mounted) {
        setState(() {
          csv = text;
          fileName = file.name;
          preview = null;
          error = null;
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = '${e.message} Используйте CSV в UTF-8.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось прочитать файл.');
      }
    }
  }

  Future<void> check() async {
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request('POST', [
          'v1',
          'companies',
          widget.companyId,
          'bank-imports',
          'preview',
        ], body: body()),
      );
      if (mounted) {
        setState(() {
          preview = (result['items'] as List).map(jsonObject).toList();
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand('POST', [
        'v1',
        'companies',
        widget.companyId,
        'bank-imports',
      ], body());
      final result = await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } on BackendException catch (e) {
      if (!RetriableCommand.uncertain(e)) {
        pending = null;
      }
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Загрузить банковскую выписку'),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CSV в UTF-8, до 500 операций. Нужен уникальный идентификатор банковской операции, а не повторяющийся номер платёжного поручения. В выписке списание и поступление — отдельные колонки. Суммы в тенге с точностью до 0,01.',
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: walletId,
              items: widget.wallets
                  .map(
                    (w) => DropdownMenuItem(
                      value: w['id'] as String,
                      child: Text(w['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: busy || pending != null
                  ? null
                  : (v) => setState(() {
                      walletId = v;
                      preview = null;
                    }),
              decoration: const InputDecoration(labelText: 'Денежный счёт'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy || pending != null ? null : pick,
              icon: const Icon(Icons.attach_file),
              label: Text(fileName.isEmpty ? 'Выбрать CSV' : fileName),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: delimiter,
              items: const [
                DropdownMenuItem(value: ';', child: Text('Точка с запятой')),
                DropdownMenuItem(value: ',', child: Text('Запятая')),
                DropdownMenuItem(value: '\t', child: Text('Табуляция')),
              ],
              onChanged: busy || pending != null
                  ? null
                  : (v) => setState(() {
                      delimiter = v!;
                      preview = null;
                    }),
              decoration: const InputDecoration(labelText: 'Разделитель'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mapping,
              enabled: !busy && pending == null,
              decoration: const InputDecoration(
                labelText: 'Названия колонок в CSV',
                helperText:
                    'Дата, ID операции, списание, поступление, назначение, контрагент',
                helperMaxLines: 3,
              ),
              onChanged: (_) => setState(() => preview = null),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (preview != null) ...[
              const SizedBox(height: 18),
              Text(
                '${preview!.length} строк · ${preview!.where((r) => r['duplicate'] == true).length} дублей не будут загружены',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ...preview!
                  .take(8)
                  .map(
                    (row) => ListTile(
                      dense: true,
                      title: Text(
                        '${row['businessDate']} · ${row['externalId']}',
                      ),
                      subtitle: Text(row['description'] as String),
                      trailing: Text(
                        row['duplicate'] == true
                            ? 'Дубль'
                            : moneyText(row['amount'] as num, 'KZT'),
                      ),
                    ),
                  ),
              if (preview!.length > 8)
                const Text(
                  'Показаны первые восемь строк. Все операции доступны после загрузки.',
                ),
            ],
            if (pending != null)
              const Text(
                'При сетевом сбое повторите загрузку: используется тот же ключ операции.',
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy || pending != null
            ? null
            : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      OutlinedButton(
        onPressed: busy || csv.isEmpty || pending != null ? null : check,
        child: const Text('Проверить файл'),
      ),
      FilledButton(
        onPressed: busy || preview == null ? null : save,
        child: Text(
          pending == null
              ? 'Загрузить для сопоставления'
              : 'Повторить загрузку',
        ),
      ),
    ],
  );
}

class BankReview extends StatefulWidget {
  const BankReview({
    super.key,
    required this.api,
    required this.companyId,
    required this.importId,
    required this.row,
    required this.projects,
  });
  final BackendClient api;
  final String companyId, importId;
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> projects;
  @override
  State<BankReview> createState() => _BankReviewState();
}

class _BankReviewState extends State<BankReview> {
  String? classification, projectId, documentId, entryId, error;
  bool busy = false;
  final search = TextEditingController();
  List<Map<String, dynamic>> documents = [], candidates = [];
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    classification = widget.row['classification'] as String?;
    projectId = widget.row['project_id'] as String?;
    documentId = widget.row['document_id'] as String?;
    entryId = widget.row['matched_entry_id'] as String?;
    if (classification == 'EXISTING') {
      findCandidates();
    }
    if (classification == 'DOCUMENT') {
      findDocuments();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> findCandidates() async {
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request('GET', [
          'v1',
          'companies',
          widget.companyId,
          'bank-imports',
          widget.importId,
          'rows',
          widget.row['id'] as String,
          'candidates',
        ]),
      );
      if (mounted) {
        setState(() {
          candidates = (result['items'] as List).map(jsonObject).toList();
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> findDocuments() async {
    setState(() => busy = true);
    try {
      final result = await CommercialRepository(widget.api, widget.companyId)
          .list(
            direction: (widget.row['amount'] as num) > 0
                ? 'sales'
                : 'purchases',
            query: search.text,
          );
      if (mounted) {
        setState(() {
          documents = (result['items'] as List)
              .map(jsonObject)
              .where((d) => ['ISSUED', 'POSTED'].contains(d['status']))
              .toList();
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'bank-imports',
          widget.importId,
          'rows',
          widget.row['id'] as String,
        ],
        {
          'version': widget.row['version'],
          'classification': classification,
          'projectId': projectId,
          'documentId': documentId,
          'entryId': entryId,
        },
      );
      await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on BackendException catch (e) {
      if (!RetriableCommand.uncertain(e)) {
        pending = null;
      }
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Сопоставить операцию'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.row['description'] as String),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: classification,
              decoration: const InputDecoration(labelText: 'Вид операции'),
              items: bankCategories.entries
                  .where(
                    (e) =>
                        e.key == 'DOCUMENT' ||
                        e.key == 'EXISTING' ||
                        e.key == 'IGNORE' ||
                        ((widget.row['amount'] as num) > 0
                            ? e.key != 'EXPENSE'
                            : e.key == 'EXPENSE'),
                  )
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: busy || pending != null
                  ? null
                  : (v) {
                      setState(() => classification = v);
                      if (v == 'EXISTING') {
                        findCandidates();
                      }
                      if (v == 'DOCUMENT') {
                        findDocuments();
                      }
                    },
            ),
            const SizedBox(height: 16),
            if (!['DOCUMENT', 'EXISTING'].contains(classification))
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: projectId ?? 'unassigned',
                decoration: const InputDecoration(labelText: 'Проект'),
                items: [
                  const DropdownMenuItem(
                    value: 'unassigned',
                    child: Text('Общие операции фирмы'),
                  ),
                  ...widget.projects.map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  ),
                ],
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(
                        () => projectId = v == 'unassigned' ? null : v,
                      ),
              ),
            if (classification == 'EXISTING') ...[
              const Text(
                'Выберите уже внесённое движение с тем же счётом, датой и суммой. Новые проводки и оплаты не создаются.',
              ),
              TextButton(
                onPressed: busy || pending != null ? null : findCandidates,
                child: const Text('Обновить подходящие операции'),
              ),
              if (candidates.isEmpty && !busy)
                const Text('Подходящих несопоставленных операций нет.'),
              ...candidates.map(
                (e) => ListTile(
                  selected: entryId == e['id'],
                  leading: Icon(
                    entryId == e['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(e['description'] as String),
                  subtitle: Text(
                    '${e['business_date']} · ${moneyText(e['amount'] as num, 'KZT')}',
                  ),
                  onTap: busy || pending != null
                      ? null
                      : () => setState(() => entryId = e['id'] as String),
                ),
              ),
            ],
            if (classification == 'DOCUMENT') ...[
              TextField(
                controller: search,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Номер документа или контрагент',
                ),
                onSubmitted: (_) => findDocuments(),
              ),
              TextButton(
                onPressed: busy || pending != null ? null : findDocuments,
                child: const Text('Найти документы'),
              ),
              const Text(
                'Проект берётся из выбранного документа. Проверьте контрагента и сумму перед проведением.',
              ),
              ...documents.map(
                (doc) => ListTile(
                  selected: documentId == doc['id'],
                  leading: Icon(
                    documentId == doc['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: busy || pending != null
                      ? null
                      : () => setState(() => documentId = doc['id'] as String),
                  title: Text(
                    '${doc['number']} · ${jsonObject(jsonObject(doc['data'])['counterparty'])['name']}',
                  ),
                  subtitle: Text(
                    'Остаток ${moneyText(doc['outstanding'] as num, 'KZT')}',
                  ),
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy || pending != null
            ? null
            : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed:
            busy ||
                classification == null ||
                (classification == 'DOCUMENT' && documentId == null) ||
                (classification == 'EXISTING' && entryId == null)
            ? null
            : save,
        child: Text(
          pending == null ? 'Сохранить сопоставление' : 'Повторить сохранение',
        ),
      ),
    ],
  );
}
