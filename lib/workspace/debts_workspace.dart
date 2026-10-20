import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';
import 'commercial_repository.dart';
import 'debts_repository.dart';
import 'debts_editor.dart';
import 'debts_pdf.dart';

Future<void> showOpeningDebt(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String debtId,
  required String currency,
  required List<Map<String, dynamic>> projects,
  required Future<void> Function() onChanged,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DebtDetail(
      repo: DebtsRepository(api, companyId),
      debtId: debtId,
      currency: currency,
      projects: projects,
    ),
  );
  await onChanged();
}

class DebtsWorkspace extends StatefulWidget {
  const DebtsWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final String? projectId;
  final Future<void> Function() onChanged;
  @override
  State<DebtsWorkspace> createState() => _DebtsWorkspaceState();
}

class _DebtsWorkspaceState extends State<DebtsWorkspace> {
  late final repo = DebtsRepository(widget.api, widget.companyId);
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [], summary = [];
  String scope = 'ACCOUNTING', type = 'AR', status = 'ALL', today = '';
  String? error, cursor;
  bool busy = false, overdue = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    setState(() => busy = true);
    try {
      final data = await repo.list({
        'scope': scope,
        'limit': '50',
        if (type != 'ALL') 'type': type,
        if (status != 'ALL') 'status': status,
        if (widget.projectId != null) 'projectId': widget.projectId!,
        'q': search.text.trim(),
        'overdue': '$overdue',
        if (more && cursor != null) 'after': cursor!,
      });
      if (!mounted) {
        return;
      }
      setState(() {
        rows = [
          ...(more ? rows : <Map<String, dynamic>>[]),
          ...(data['items'] as List).map(jsonObject),
        ];
        summary = (data['summary'] as List).map(jsonObject).toList();
        today = data['businessDate'] as String;
        cursor = data['nextCursor'] as String?;
        error = null;
      });
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

  Future<void> open(String id) async {
    await showOpeningDebt(
      context,
      api: widget.api,
      companyId: widget.companyId,
      debtId: id,
      currency: widget.currency,
      projects: widget.projects,
      onChanged: () async {
        await load();
        await widget.onChanged();
      },
    );
  }

  Future<void> create() async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DebtEditor(
        repo: repo,
        currency: widget.currency,
        projects: widget.projects,
        today: today,
        initialType: type == 'AP' ? 'AP' : 'AR',
        initialScope: scope,
        projectId: widget.projectId == 'unassigned' ? null : widget.projectId,
      ),
    );
    if (id != null && mounted) {
      await load();
      if (mounted) {
        await open(id);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 16,
        children: [
          Text(
            'Начальные долги',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (hasCompanyPermission(context, 'debts.write') &&
              hasCompanyPermission(context, 'catalog.read'))
            FilledButton.icon(
              onPressed: busy || today.isEmpty ? null : create,
              icon: const Icon(Icons.add),
              label: const Text('Добавить начальный долг'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Остатки, перенесённые в начало учёта. Долги по актам, товарам и ОС здесь не создавайте повторно: они уже возникают из своих документов.',
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Вид долга'),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('Все долги')),
                for (final e in debtTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => type = v!);
                      load();
                    },
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: scope,
              decoration: const InputDecoration(labelText: 'Контур'),
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
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Начальный остаток'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Все записи')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Действующие')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Отменённые')),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => status = v!);
                      load();
                    },
            ),
          ),
          SizedBox(
            width: 300,
            child: TextField(
              controller: search,
              enabled: !busy,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Поиск контрагента или записи',
              ),
              onSubmitted: (_) => load(),
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => load(),
            icon: const Icon(Icons.search),
            label: const Text('Показать долги'),
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Только просроченные'),
        value: overdue,
        onChanged: busy
            ? null
            : (v) {
                setState(() => overdue = v!);
                load();
              },
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final s in summary)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debtTypes[s['type']]!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        moneyText(s['outstanding'] as num, widget.currency),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Авансы: ${moneyText(s['advance'] as num, widget.currency)}',
                      ),
                      Text('Записей: ${s['count']}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (rows.isEmpty && !busy)
        const Text('Начальных долгов по выбранным условиям нет.'),
      for (final d in rows)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            title: Text(
              jsonObject(jsonObject(d['data'])['counterparty'] ?? {})['name']
                      as String? ??
                  d['counterparty_id'] as String,
            ),
            subtitle: Text(
              '${d['business_date']} · ${debtStatuses[d['status']]}\nЗадолженность: ${moneyText(d['remaining'] as num, widget.currency)} · Аванс: ${moneyText(d['advance'] as num, widget.currency)}${d['sourceComplete'] != true ? '\nНужна сверка старых источников' : ''}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => open(d['id'] as String),
          ),
        ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Загрузить ещё долги'),
        ),
    ],
  );
}

class DebtDetail extends StatefulWidget {
  const DebtDetail({
    super.key,
    required this.repo,
    required this.debtId,
    required this.currency,
    required this.projects,
  });
  final DebtsRepository repo;
  final String debtId, currency;
  final List<Map<String, dynamic>> projects;
  @override
  State<DebtDetail> createState() => _DebtDetailState();
}

class _DebtDetailState extends State<DebtDetail> {
  Map<String, dynamic>? record;
  bool busy = false;
  String? error;
  int tab = 0;
  RetriableCommand? pending;
  bool can(String permission) => hasCompanyPermission(context, permission);
  List<Map<String, dynamic>> get payments =>
      (record?['payments'] as List? ?? []).map(jsonObject).toList();
  bool get editable =>
      can('debts.write') &&
      (payments.every((p) => p['voided'] == true) || can('debts.settle')) &&
      record?['sourceComplete'] == true;
  bool get canPay =>
      can('debts.settle') &&
      can('wallets.transact') &&
      can('wallets.read') &&
      record?['sourceComplete'] == true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await widget.repo.get(widget.debtId);
      if (mounted) {
        setState(() {
          record = data;
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

  Future<void> edit() async {
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DebtEditor(
        repo: widget.repo,
        currency: widget.currency,
        projects: widget.projects,
        today: record!['companyBusinessDate'] as String,
        record: record,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> payment([Map<String, dynamic>? previous]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DebtPaymentEditor(
        repo: widget.repo,
        currency: widget.currency,
        debt: record!,
        payment: previous,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                if ((record!['sourceMismatches'] as List).isNotEmpty) ...[
                  const Text(
                    'Старые данные расходятся с журналом. Подтвердите применение текущих данных регистра.',
                  ),
                  for (final m in (record!['sourceMismatches'] as List).map(
                    jsonObject,
                  ))
                    Text(
                      '${m['kind']}: регистр ${moneyText(m['storedAmount'] as num, widget.currency)}, журнал ${moneyText(m['ledgerAmount'] as num, widget.currency)}',
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> action(String name, {Map<String, dynamic>? payment}) async {
    if (pending == null) {
      final message = payment == null
          ? (name == 'cancel'
                ? 'Начальный остаток будет сторнирован. Фактические оплаты сохранятся.'
                : 'Будет восстановлен начальный остаток с последними сохранёнными данными.')
          : (name == 'void'
                ? 'Запись оплаты будет отменена, денежный остаток пересчитается. Это исправление записи, а не фактический возврат денег.'
                : 'Оплата восстановится с последними сохранёнными суммой, счётом и датой. Превышение остатка будет авансом.');
      if (!await confirm(
            payment == null
                ? 'Изменить начальный остаток'
                : 'Изменить запись оплаты',
            message,
          ) ||
          !mounted) {
        return;
      }
      pending = widget.repo.command(
        'POST',
        [
          widget.debtId,
          if (payment != null) 'payments',
          if (payment != null) payment['id'] as String,
          name,
        ],
        {
          'version': payment?['version'] ?? record!['version'],
          'confirmRecalculation': true,
          if (payment != null && name == 'restore') 'allowAdvance': true,
        },
      );
    }
    await execute();
  }

  Future<void> execute() async {
    setState(() => busy = true);
    try {
      await pending!.execute(widget.repo.api);
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

  Future<void> printRecord() async {
    try {
      final bytes = await debtPdf(record!, widget.currency);
      await Printing.layoutPdf(
        name: 'Начальные взаиморасчёты.pdf',
        onLayout: (_) => bytes,
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось подготовить печатный регистр.');
      }
    }
  }

  Widget moneyCard(String title, String key) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(
            moneyText(record![key] as num, widget.currency),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && pending == null,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 1100,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Начальный долг и оплаты',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть долг',
                    onPressed: busy || pending != null
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (pending != null)
                FilledButton(
                  onPressed: busy ? null : execute,
                  child: const Text('Повторить операцию'),
                ),
              if (record != null)
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        jsonObject(
                                  jsonObject(record!['data'])['counterparty'] ??
                                      {},
                                )['name']
                                as String? ??
                            record!['counterparty_id'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${debtTypes[record!['type']]} · ${debtStatuses[record!['status']]} · ${record!['business_date']} · Версия ${record!['version']}',
                      ),
                      if (record!['sourceComplete'] != true)
                        const Text(
                          'Старые проводки не удалось однозначно связать с записью. Требуется сверка источников; автоматический пересчёт отключён, чтобы не задвоить деньги.',
                          style: TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          moneyCard('Начальный остаток', 'total'),
                          moneyCard('Задолженность', 'remaining'),
                          moneyCard(
                            record!['type'] == 'AR'
                                ? 'Аванс клиента'
                                : 'Аванс поставщику',
                            'advance',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Фактически получено: ${moneyText(record!['received'] as num, widget.currency)} · Фактически выплачено: ${moneyText(record!['paidOut'] as num, widget.currency)}',
                      ),
                      const Text(
                        'Отмена начального остатка не отменяет оплаты. Непогашенные денежные движения могут сохранять задолженность или аванс.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (editable)
                            OutlinedButton.icon(
                              onPressed: busy || pending != null ? null : edit,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Изменить долг'),
                            ),
                          if (canPay)
                            FilledButton.icon(
                              onPressed: busy || pending != null
                                  ? null
                                  : () => payment(),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Внести оплату долга'),
                            ),
                          if (editable)
                            OutlinedButton(
                              onPressed: busy || pending != null
                                  ? null
                                  : () => action(
                                      record!['status'] == 'ACTIVE'
                                          ? 'cancel'
                                          : 'restore',
                                    ),
                              child: Text(
                                record!['status'] == 'ACTIVE'
                                    ? 'Отменить начальный остаток'
                                    : 'Восстановить начальный остаток',
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: busy || pending != null
                                ? null
                                : printRecord,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Печатный регистр'),
                          ),
                          IconButton(
                            tooltip: 'Обновить долг',
                            onPressed: busy || pending != null ? null : load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => tab = 0),
                            child: const Text('Оплаты долга'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => tab = 1),
                            child: const Text('Проводки долга'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => tab = 2),
                            child: const Text('История долга'),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (tab == 0) ...[
                        if (payments.isEmpty) const Text('Оплат пока нет.'),
                        for (final p in payments)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p['direction'] == 'IN' ? 'Поступление' : 'Списание'} · ${moneyText(p['amount'] as num, widget.currency)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${p['business_date']} · ${p['voided'] == true ? 'Отменена' : 'Учтена'} · Версия ${p['version']}',
                                  ),
                                  if (canPay)
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        TextButton(
                                          onPressed: busy || pending != null
                                              ? null
                                              : () => payment(p),
                                          child: const Text(
                                            'Изменить оплату долга',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: busy || pending != null
                                              ? null
                                              : () => action(
                                                  p['voided'] == true
                                                      ? 'restore'
                                                      : 'void',
                                                  payment: p,
                                                ),
                                          child: Text(
                                            p['voided'] == true
                                                ? 'Восстановить оплату долга'
                                                : 'Отменить оплату долга',
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (tab == 1) ...[
                        const Text(
                          'Последние200 связанных проводок; полная история хранится в журнале.',
                        ),
                        for (final m in (record!['movements'] as List).map(
                          jsonObject,
                        ))
                          ExpansionTile(
                            title: Text('${m['business_date']} · ${m['kind']}'),
                            subtitle: Text(m['description'] as String),
                            children: [
                              for (final line in (m['lines'] as List).map(
                                jsonObject,
                              ))
                                ListTile(
                                  title: Text(line['account'] as String),
                                  subtitle: Text(
                                    'Дебет ${moneyText(line['debit'] as num, widget.currency)} · Кредит ${moneyText(line['credit'] as num, widget.currency)}',
                                  ),
                                ),
                            ],
                          ),
                      ],
                      if (tab == 2) ...[
                        const Text(
                          'Последние200 изменений. Сохранены прежние суммы, даты, счета и авторы.',
                        ),
                        if ((record!['history'] as List).isEmpty)
                          const Text('Исправлений пока нет.'),
                        for (final h in (record!['history'] as List).map(
                          jsonObject,
                        ))
                          Builder(
                            builder: (_) {
                              final old = jsonObject(h['snapshot']);
                              return ListTile(
                                title: Text(
                                  '${h['kind'] == 'opening_debt' ? 'Начальный долг' : 'Оплата'} · Версия ${old['version']}',
                                ),
                                subtitle: Text(
                                  '${h['actor_name']} · ${h['changed_at']}\n${old['business_date']} · ${moneyText((old['amount'] ?? old['total']) as num, widget.currency)}',
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
