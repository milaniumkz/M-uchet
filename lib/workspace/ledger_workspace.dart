import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'commercial_detail.dart';
import 'input_dialogs.dart';
import 'assets_workspace.dart';

const ledgerLabels = {
  'fixed_assets':'Основные средства',
  'accumulated_depreciation':'Накопленная амортизация',
  'depreciation':'Амортизационные расходы',
  'asset_disposal_loss':'Списание основных средств',
  'cash': 'Денежные средства',
  'capital': 'Капитал',
  'revenue': 'Доходы',
  'expenses': 'Расходы',
  'cogs': 'Себестоимость',
  'receivables': 'Дебиторская задолженность',
  'payables': 'Кредиторская задолженность',
  'inventory': 'Запасы',
  'customer_advances': 'Авансы покупателей',
  'supplier_advances': 'Авансы поставщикам',
  'vat_payable': 'НДС к уплате',
  'input_vat_pending': 'Входящий НДС на проверке',
  'inventory_loss': 'Списания запасов',
};
String accountName(String account) =>
    ledgerLabels[account] ??
    (account.startsWith('wallet:')
        ? 'Денежный счёт ${account.substring(7)}'
        : account);
String csvCell(Object? raw) {
  var value = '$raw';
  if (raw is! num && RegExp(r'^[=+@\-\t\r]').hasMatch(value)) {
    value = "'$value";
  }
  return '"${value.replaceAll('"', '""')}"';
}

class LedgerWorkspace extends StatefulWidget {
  const LedgerWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.mode,
    required this.projects,
    required this.onChanged,
    this.projectId,
    this.from,
    this.to,
  });
  final BackendClient api;
  final String companyId, currency, mode;
  final String? projectId, from, to;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<LedgerWorkspace> createState() => _LedgerWorkspaceState();
}

class _LedgerWorkspaceState extends State<LedgerWorkspace> {
  bool busy = false;
  String? error, cursor, account;
  String scope = 'ACCOUNTING';
  Map<String, dynamic>? report;
  List<Map<String, dynamic>> accounts = [], entries = [], periods = [];
  RetriableCommand? pending;
  List<String> path(List<String> rest) => [
    'v1',
    'companies',
    widget.companyId,
    ...rest,
  ];
  Map<String, String> get query => {
    'scope': scope,
    if (widget.projectId != null) 'projectId': widget.projectId!,
    if (widget.from != null) 'from': widget.from!,
    if (widget.to != null) 'to': widget.to!,
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() => busy = true);
    try {
      if (widget.mode == 'reports') {
        final pl = jsonObject(
          await widget.api.request(
            'GET',
            path(['reports', 'profit-loss']),
            query: query,
          ),
        );
        final trial = jsonObject(
          await widget.api.request(
            'GET',
            path(['accounting', 'trial-balance']),
            query: query,
          ),
        );
        if (mounted) {
          setState(() {
            report = pl;
            accounts = (trial['accounts'] as List).map(jsonObject).toList();
          });
        }
      } else if (widget.mode == 'periods') {
        final data = jsonObject(
          await widget.api.request('GET', path(['periods'])),
        );
        if (mounted) {
          setState(
            () => periods = (data['items'] as List).map(jsonObject).toList(),
          );
        }
      } else {
        final data = jsonObject(
          await widget.api.request(
            'GET',
            path(['accounting', 'journal']),
            query: {
              ...query,
              'limit': '100',
              if (account != null) 'account': account!,
              if (more && cursor != null) 'after': cursor!,
            },
          ),
        );
        if (mounted) {
          setState(() {
            final next = (data['items'] as List).map(jsonObject).toList();
            entries = more ? [...entries, ...next] : next;
            cursor = data['nextCursor'] as String?;
          });
        }
      }
      if (mounted) {
        setState(() => error = null);
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

  Future<void> open(Map<String, dynamic> entry) async {
    try {
      final details = jsonObject(
        await widget.api.request(
          'GET',
          path(['accounting', 'journal', entry['id'] as String]),
        ),
      );
      if (!mounted) {
        return;
      }
      if(details['sourceAssetId']!=null){
        await showAssetDetails(context,api:widget.api,companyId:widget.companyId,assetId:details['sourceAssetId'] as String,currency:widget.currency,projects:widget.projects,onChanged:widget.onChanged);
      }else if (details['sourceDocumentId'] != null) {
        final doc = await CommercialRepository(
          widget.api,
          widget.companyId,
        ).get(details['sourceDocumentId'] as String);
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
      } else {
        await showDialog<bool>(
          context: context,
          builder: (_) => JournalEditor(
            api: widget.api,
            companyId: widget.companyId,
            projects: widget.projects,
            entry: details,
          ),
        );
      }
      if (mounted) {
        await widget.onChanged();
        await load();
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  Future<void> create() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => JournalEditor(
        api: widget.api,
        companyId: widget.companyId,
        projects: widget.projects,
        projectId: widget.projectId == 'unassigned' ? null : widget.projectId,
      ),
    );
    if (mounted) {
      await widget.onChanged();
      await load();
    }
  }

  Future<void> drilldown(String selected) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(accountName(selected))),
          body: _AccountJournal(
            api: widget.api,
            companyId: widget.companyId,
            query: {...query, 'account': selected},
            onOpen: open,
            currency: widget.currency,
          ),
        ),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> export() async {
    try {
      final rows = <List<Object?>>[
        [
          'Отчёт',
          widget.mode == 'reports'
              ? 'Финансовый отчёт'
              : 'Бухгалтерские записи',
        ],
        ['Контур', scope],
        ['Период', widget.from ?? 'Начало учёта', widget.to ?? 'Все даты'],
        ['Проект', widget.projectId ?? 'Вся фирма'],
        ['Валюта', widget.currency],
        if (widget.mode == 'reports') ...[
          ['Показатель', 'Сумма'],
          ...{
            'revenue': 'Доходы',
            'cogs': 'Себестоимость',
            'expenses': 'Расходы',
            'netProfit': 'Прибыль',
          }.entries.map(
            (e) => [e.value, moneyText(report![e.key] as num, widget.currency)],
          ),
          [
            'Счёт',
            'Начальный остаток',
            'Дебет за период',
            'Кредит за период',
            'Конечный остаток',
          ],
          ...accounts.map(
            (r) => [
              r['account'],
              r['opening'],
              r['debit'],
              r['credit'],
              r['balance'],
            ],
          ),
        ] else ...[
          [
            'Запись',
            'Дата',
            'Описание',
            'Счёт',
            'Дебет (минимальные единицы)',
            'Кредит (минимальные единицы)',
          ],
          ...entries.expand(
            (e) => (e['lines'] as List).map((raw) {
              final l = jsonObject(raw);
              return [
                e['id'],
                e['business_date'],
                e['description'],
                l['account'],
                l['debit'],
                l['credit'],
              ];
            }),
          ),
        ],
      ];
      if (widget.mode != 'reports' && cursor != null) {
        setState(
          () => error = 'Загрузите все страницы перед экспортом журнала.',
        );
        return;
      }
      final content =
          '\uFEFF${rows.map((r) => r.map(csvCell).join(';')).join('\r\n')}';
      await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить отчёт',
        fileName: 'm-uchet-${widget.mode}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось сохранить CSV.');
      }
    }
  }

  Future<void> markPeriod() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => PeriodStatusDialog(
        month: (widget.from ?? DateTime.now().toIso8601String()).substring(
          0,
          7,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    pending = RetriableCommand(
      'POST',
      path(['periods', result['month']!, result['action']!]),
      {'reason': result['reason']},
    );
    await executePeriod();
  }

  Future<void> executePeriod() async {
    setState(() => busy = true);
    try {
      await pending!.execute(widget.api);
      pending = null;
      await load();
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

  Widget metric(String label, String key) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 14),
            Text(
              moneyText(report![key] as num, widget.currency),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 12,
        children: [
          Text(switch (widget.mode) {
            'reports' => 'Финансовые отчёты',
            'periods' => 'Закрытие месяца',
            _ => 'Бухгалтерские записи',
          }, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          if (widget.mode == 'journal')
            FilledButton.icon(
              onPressed: busy ? null : create,
              icon: const Icon(Icons.add),
              label: const Text('Новая запись'),
            ),
          if (widget.mode == 'periods')
            FilledButton(
              onPressed: busy || pending != null ? null : markPeriod,
              child: const Text('Изменить состояние месяца'),
            ),
          if (widget.mode != 'periods')
            OutlinedButton.icon(
              onPressed: busy ? null : export,
              icon: const Icon(Icons.download),
              label: const Text('Экспорт CSV'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (widget.mode != 'periods')
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 250,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: scope,
              items: const [
                DropdownMenuItem(
                  value: 'ACCOUNTING',
                  child: Text('Бухгалтерский учёт'),
                ),
                DropdownMenuItem(
                  value: 'MANAGEMENT',
                  child: Text('Управленческий учёт'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => scope = v!);
                      load();
                    },
            ),
          ),
        ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      if (widget.mode == 'reports' && report != null) ...[
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            metric('Доходы', 'revenue'),
            metric('Себестоимость', 'cogs'),
            metric('Расходы', 'expenses'),
            metric('Прибыль', 'netProfit'),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Оборотно-сальдовая ведомость',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Выберите счёт, чтобы увидеть записи-основания. Все суммы в CSV ведомости — в минимальных денежных единицах.',
        ),
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Движений пока нет.'),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Счёт')),
              DataColumn(label: Text('На начало')),
              DataColumn(label: Text('Дебет')),
              DataColumn(label: Text('Кредит')),
              DataColumn(label: Text('На конец')),
            ],
            rows: accounts
                .map(
                  (r) => DataRow(
                    onSelectChanged: (_) => drilldown(r['account'] as String),
                    cells: [
                      DataCell(Text(accountName(r['account'] as String))),
                      ...['opening', 'debit', 'credit', 'balance'].map(
                        (key) => DataCell(
                          Text(moneyText(r[key] as num, widget.currency)),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
      if (widget.mode == 'journal') ...[
        const SizedBox(height: 20),
        ...entries.map(
          (e) => Card(
            elevation: 0,
            child: ListTile(
              title: Text(e['description'] as String),
              subtitle: Text('${e['business_date']} · ${e['scope']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : () => open(e),
            ),
          ),
        ),
        if (entries.isEmpty && !busy)
          const Text('Бухгалтерских записей за выбранный период нет.'),
        if (cursor != null)
          TextButton(
            onPressed: busy ? null : () => load(more: true),
            child: const Text('Загрузить ещё'),
          ),
      ],
      if (widget.mode == 'periods') ...[
        const SizedBox(height: 24),
        const Text(
          'Статус месяца общий для фирмы. Закрытие не запрещает редактирование документов: исправления сохраняют историю и пересчитывают отчёты. Эта отметка не означает отправку налоговой отчётности или автоматическое выполнение всех регламентных операций.',
        ),
        if (pending != null)
          TextButton(
            onPressed: busy ? null : executePeriod,
            child: const Text('Повторить изменение состояния'),
          ),
        ...periods.map(
          (p) => Card(
            elevation: 0,
            child: ListTile(
              title: Text(p['month'] as String),
              subtitle: Text(
                p['status'] == 'CLOSED'
                    ? 'Закрыт, редактирование доступно'
                    : 'Открыт',
              ),
            ),
          ),
        ),
        if (periods.isEmpty && !busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Все месяцы открыты.'),
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

class _AccountJournal extends StatefulWidget {
  const _AccountJournal({
    required this.api,
    required this.companyId,
    required this.query,
    required this.onOpen,
    required this.currency,
  });
  final BackendClient api;
  final String companyId, currency;
  final Map<String, String> query;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  @override
  State<_AccountJournal> createState() => _AccountJournalState();
}

class _AccountJournalState extends State<_AccountJournal> {
  List<Map<String, dynamic>> items = [];
  String? cursor, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'accounting', 'journal'],
          query: {
            ...widget.query,
            'limit': '100',
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      if (mounted) {
        setState(() {
          final next = (data['items'] as List).map(jsonObject).toList();
          items = more ? [...items, ...next] : next;
          cursor = data['nextCursor'] as String?;
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      if (busy) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      ...items.map(
        (e) => Card(
          elevation: 0,
          child: ListTile(
            title: Text(e['description'] as String),
            subtitle: Text(e['business_date'] as String),
            onTap: () async {
              await widget.onOpen(e);
              if (mounted) {
                await load();
              }
            },
          ),
        ),
      ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Загрузить ещё'),
        ),
      if (items.isEmpty && !busy)
        const Text('Записей в выбранном периоде нет.'),
    ],
  );
}

class JournalEditor extends StatefulWidget {
  const JournalEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.projects,
    this.entry,
    this.projectId,
  });
  final BackendClient api;
  final String companyId;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? entry;
  final String? projectId;
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final description = TextEditingController(
    text: widget.entry?['description'] as String? ?? '',
  );
  late final date = TextEditingController(
    text:
        widget.entry?['business_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10),
  );
  final reason = TextEditingController();
  final lines =
      <
        ({
          TextEditingController account,
          TextEditingController debit,
          TextEditingController credit,
        })
      >[];
  String? projectId, error;
  String scope = 'ACCOUNTING';
  bool busy = false;
  RetriableCommand? pending;
  List<Map<String, dynamic>> history = [];
  String decimal(num value) =>
      '${value.toInt() ~/ 100}.${(value.toInt() % 100).toString().padLeft(2, '0')}';
  void addLine([Map<String, dynamic>? line]) {
    lines.add((
      account: TextEditingController(text: line?['account'] as String? ?? ''),
      debit: TextEditingController(text: decimal(line?['debit'] as num? ?? 0)),
      credit: TextEditingController(
        text: decimal(line?['credit'] as num? ?? 0),
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    projectId = widget.entry?['project_id'] as String? ?? widget.projectId;
    scope = widget.entry?['scope'] as String? ?? 'ACCOUNTING';
    if (widget.entry == null) {
      addLine();
      addLine();
    } else {
      for (final line in widget.entry!['lines'] as List) {
        addLine(jsonObject(line));
      }
      loadHistory();
    }
  }

  Future<void> loadHistory() async {
    try {
      final data = jsonObject(
        await widget.api.request('GET', [
          'v1',
          'companies',
          widget.companyId,
          'accounting',
          'journal',
          widget.entry!['id'] as String,
          'history',
        ]),
      );
      if (mounted) {
        setState(
          () => history = (data['items'] as List).map(jsonObject).toList(),
        );
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  @override
  void dispose() {
    description.dispose();
    date.dispose();
    reason.dispose();
    for (final l in lines) {
      l.account.dispose();
      l.debit.dispose();
      l.credit.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.entry == null ? 'POST' : 'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'accounting',
          'journal',
          if (widget.entry != null) widget.entry!['id'] as String,
        ],
        {
          if (widget.entry != null)
            'expectedRevision': widget.entry!['revision'],
          'description': description.text,
          'businessDate': date.text,
          'scope': scope,
          'projectId': projectId,
          'reason': reason.text.trim().isEmpty
              ? 'Исправление записи'
              : reason.text.trim(),
          'lines': lines
              .map(
                (l) => {
                  'account': l.account.text,
                  'debit': parseMoney(l.debit.text),
                  'credit': parseMoney(l.credit.text),
                },
              )
              .toList(),
        },
      );
      await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
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
    title: Text(
      widget.entry == null
          ? 'Новая бухгалтерская запись'
          : 'Изменить бухгалтерскую запись',
    ),
    content: SizedBox(
      width: 800,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: description,
              enabled: !busy && pending == null,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: date,
              enabled: !busy && pending == null,
              decoration: const InputDecoration(labelText: 'Дата YYYY-MM-DD'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: scope,
              items: const [
                DropdownMenuItem(
                  value: 'ACCOUNTING',
                  child: Text('Бухгалтерский'),
                ),
                DropdownMenuItem(
                  value: 'MANAGEMENT',
                  child: Text('Управленческий'),
                ),
                DropdownMenuItem(value: 'BOTH', child: Text('Оба контура')),
              ],
              onChanged: busy || pending != null
                  ? null
                  : (v) => setState(() => scope = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: projectId ?? 'unassigned',
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
            const SizedBox(height: 16),
            const Text(
              'Каждая строка содержит дебет или кредит. Итоги должны совпадать. Технический код счёта указывается явно; для кошелька — wallet:ID.',
            ),
            ...lines.indexed.map((item) {
              final l = item.$2;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: l.account,
                        enabled: !busy && pending == null,
                        decoration: const InputDecoration(labelText: 'Счёт'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: l.debit,
                        enabled: !busy && pending == null,
                        decoration: const InputDecoration(labelText: 'Дебет'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: l.credit,
                        enabled: !busy && pending == null,
                        decoration: const InputDecoration(labelText: 'Кредит'),
                      ),
                    ),
                    IconButton(
                      onPressed: busy || pending != null || lines.length <= 2
                          ? null
                          : () {
                              setState(() => lines.removeAt(item.$1));
                              l.account.dispose();
                              l.debit.dispose();
                              l.credit.dispose();
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: busy || pending != null || lines.length >= 100
                  ? null
                  : () => setState(() => addLine()),
              icon: const Icon(Icons.add),
              label: const Text('Добавить строку'),
            ),
            if (widget.entry != null) ...[
              TextField(
                controller: reason,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Причина исправления',
                ),
              ),
              const SizedBox(height: 16),
              Text('История изменений: ${history.length}'),
              ...history.map(
                (h) => Text('${h['changed_at']} · ${h['reason'] ?? ''}'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (pending != null)
              const Text(
                'Повтор запроса использует исходные данные и ключ операции.',
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
        onPressed: busy ? null : save,
        child: Text(
          pending == null ? 'Сохранить запись' : 'Повторить сохранение',
        ),
      ),
    ],
  );
}
