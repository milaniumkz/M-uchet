import '../backend/rest/repositories.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'company_access.dart';
import 'payroll_repository.dart';
import 'payroll_editor.dart';
import 'payroll_pdf.dart';

Future<void> showPayrollRecord(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String payrollId,
  required String currency,
  required List<Map<String, dynamic>> projects,
  required Future<void> Function() onChanged,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PayrollDetail(
      api: api,
      companyId: companyId,
      payrollId: payrollId,
      currency: currency,
      projects: projects,
    ),
  );
  await onChanged();
}

class PayrollWorkspace extends StatefulWidget {
  const PayrollWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
    required this.onEmployees,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final String? projectId;
  final Future<void> Function() onChanged;
  final VoidCallback onEmployees;
  @override
  State<PayrollWorkspace> createState() => _PayrollWorkspaceState();
}

class _PayrollWorkspaceState extends State<PayrollWorkspace> {
  late final repo = PayrollRepository(widget.api, widget.companyId);
  final month = TextEditingController();
  List<Map<String, dynamic>> employees = [], records = [];
  Map<String, dynamic> summary = {};
  String scope = 'ACCOUNTING';
  bool busy = false, verified = false;
  String? error, cursor;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    month.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    setState(() => busy = true);
    try {
      if (month.text.isEmpty) {
        final rules = jsonObject(
          await widget.api.request('GET', repo.path('rules')),
        );
        final current = (rules['businessDate'] as String).substring(0, 7);
        month.text = current.startsWith('2026-') ? current : '2026-12';
      }
      final data = jsonObject(
        await widget.api.request(
          'GET',
          repo.path(),
          query: {
            'month': month.text,
            'scope': scope,
            'limit': '100',
            if (widget.projectId != null) 'projectId': widget.projectId!,
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      final people = more ? employees : await repo.employees();
      if (mounted) {
        setState(() {
          final next = (data['items'] as List).map(jsonObject).toList();
          records = more ? [...records, ...next] : next;
          summary = jsonObject(data['summary']);
          cursor = data['nextCursor'] as String?;
          employees = people;
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

  Future<void> open(String id) async {
    await showPayrollRecord(
      context,
      api: widget.api,
      companyId: widget.companyId,
      payrollId: id,
      currency: widget.currency,
      projects: widget.projects,
      onChanged: widget.onChanged,
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> create([String? employeeId]) async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayrollEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        month: month.text,
        projectId: widget.projectId,
        employeeId: employeeId,
      ),
    );
    if (id != null && mounted) {
      await open(id);
    }
  }

  Widget action(Map<String, dynamic> e, Map<String, dynamic>? record) =>
      TextButton(
        onPressed: busy
            ? null
            : record != null
            ? () => open(record['id'] as String)
            : verified && hasCompanyPermission(context, 'payroll.write')
            ? () => create(e['id'] as String)
            : null,
        child: Text(record == null ? 'Рассчитать' : 'Открыть расчёт'),
      );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final byEmployee = {
        for (final r in records) r['employee_id'] as String: r,
      };
      final people = employees
          .where(
            (e) =>
                byEmployee.containsKey(e['id']) ||
                ((widget.projectId == null ||
                        e['project_id'] ==
                            (widget.projectId == 'unassigned'
                                ? null
                                : widget.projectId)) &&
                    (e['hire_date'] as String)
                            .substring(0, 7)
                            .compareTo(month.text) <=
                        0 &&
                    (e['termination_date'] == null ||
                        (e['termination_date'] as String)
                                .substring(0, 7)
                                .compareTo(month.text) >=
                            0)),
          )
          .toList();
      Widget card(Widget child) => Card(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      );
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text(
            'Расчёт зарплаты',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Начисления, удержания и расходы работодателя. Выплата в учёте не отправляет деньги в банк.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: month,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Месяц YYYY-MM'),
                  onChanged: (_) => setState(() => verified = false),
                  onSubmitted: (_) => load(),
                ),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() => verified = false);
                        load();
                      },
                child: const Text('Показать месяц'),
              ),
              SizedBox(
                width: 280,
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
                  decoration: const InputDecoration(labelText: 'Вид учёта'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Начисления сотрудникам',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (people.isEmpty && !busy)
                  const Text('За этот период сотрудников или начислений нет.'),
                if (size.maxWidth >= 950)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      horizontalMargin: 8,
                      columns: const [
                        DataColumn(label: Text('Сотрудник')),
                        DataColumn(label: Text('Начислено')),
                        DataColumn(label: Text('Удержания')),
                        DataColumn(label: Text('К выплате')),
                        DataColumn(label: Text('Проверка')),
                      ],
                      rows: people.map((e) {
                        final r = byEmployee[e['id']],
                            c = r == null
                                ? null
                                : jsonObject(
                                    jsonObject(r['data'])['calculation'],
                                  );
                        return DataRow(
                          cells: [
                            DataCell(Text(e['name'] as String)),
                            DataCell(
                              Text(
                                moneyText(
                                  c?['gross'] as num? ?? e['gross_base'] as num,
                                  widget.currency,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                c == null
                                    ? 'Не рассчитаны'
                                    : moneyText(
                                        c['employeeWithholdings'] as num,
                                        widget.currency,
                                      ),
                              ),
                            ),
                            DataCell(
                              Text(
                                c == null
                                    ? 'Требует расчёта'
                                    : moneyText(
                                        c['net'] as num,
                                        widget.currency,
                                      ),
                              ),
                            ),
                            DataCell(action(e, r)),
                          ],
                        );
                      }).toList(),
                    ),
                  )
                else
                  ...people.map((e) {
                    final r = byEmployee[e['id']],
                        c = r == null
                            ? null
                            : jsonObject(jsonObject(r['data'])['calculation']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Начислено: ${moneyText(c?['gross'] as num? ?? e['gross_base'] as num, widget.currency)}',
                          ),
                          Text(
                            c == null
                                ? 'Удержания требуют расчёта'
                                : 'Удержания: ${moneyText(c['employeeWithholdings'] as num, widget.currency)} · К выплате: ${moneyText(c['net'] as num, widget.currency)}',
                          ),
                          if (r != null) Text(payrollStatuses[r['status']]!),
                          action(e, r),
                          const Divider(),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5DE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Перед расчётом проверьте период, данные работника, заявление на вычет и применимость обычной зарплаты. Специальные категории и неподдержанные периоды автоматически не подменяются стандартным расчётом.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(
                width: size.maxWidth > 1000
                    ? (size.maxWidth - 84) / 2
                    : size.maxWidth - 64,
                child: card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Перед расчётом',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: verified,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => verified = v!),
                        title: const Text('Табель и начисления проверены'),
                        subtitle: const Text(
                          'Подтверждены суммы и выбранный период. Условия удержаний проверяются отдельно для сотрудника.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: size.maxWidth > 1000
                    ? (size.maxWidth - 84) / 2
                    : size.maxWidth - 64,
                child: card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Следующий шаг',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            busy ||
                                !verified ||
                                !hasCompanyPermission(context, 'payroll.write')
                            ? null
                            : () => create(),
                        child: const Text('Подготовить начисление'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : widget.onEmployees,
                        child: const Text('Проверить данные сотрудников'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Проведённые начисления за период',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Начислено: ${moneyText(summary['gross'] as num? ?? 0, widget.currency)} · К выплате: ${moneyText(summary['net'] as num? ?? 0, widget.currency)}',
                ),
                Text(
                  'Расходы работодателя сверх начисления: ${moneyText(summary['employer'] as num? ?? 0, widget.currency)}',
                ),
                Text(
                  'Общий расход фирмы: ${moneyText(summary['total_cost'] as num? ?? 0, widget.currency)}',
                ),
                Text('Черновики: ${summary['drafts'] ?? 0}'),
              ],
            ),
          ),
          if (cursor != null)
            TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: const Text('Загрузить ещё начисления'),
            ),
        ],
      );
    },
  );
}

class PayrollDetail extends StatefulWidget {
  const PayrollDetail({
    super.key,
    required this.api,
    required this.companyId,
    required this.payrollId,
    required this.currency,
    required this.projects,
  });
  final BackendClient api;
  final String companyId, payrollId, currency;
  final List<Map<String, dynamic>> projects;
  @override
  State<PayrollDetail> createState() => _PayrollDetailState();
}

class _PayrollDetailState extends State<PayrollDetail> {
  late final repo = PayrollRepository(widget.api, widget.companyId);
  Map<String, dynamic>? record;
  List<Map<String, dynamic>> payments = [], history = [];
  bool busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await Future.wait([
        repo.get(widget.payrollId),
        widget.api
            .request('GET', repo.path(widget.payrollId, 'payments'))
            .then(jsonObject),
        widget.api
            .request('GET', repo.path(widget.payrollId, 'history'))
            .then(jsonObject),
      ]);
      if (mounted) {
        setState(() {
          record = data[0];
          payments = (data[1]['items'] as List).map(jsonObject).toList();
          history = (data[2]['items'] as List).map(jsonObject).toList();
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

  Future<void> run([String? action, Map<String, dynamic>? payment]) async {
    pending ??= RetriableCommand(
      'POST',
      payment == null
          ? repo.path(widget.payrollId, action)
          : [
              ...repo.path(widget.payrollId, 'payments'),
              payment['id'] as String,
              action!,
            ],
      {'version': payment?['version'] ?? record!['version']},
    );
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

  Future<void> edit() async {
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayrollEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        month: record!['month'] as String,
        record: record,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> pay([Map<String, dynamic>? payment]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayrollPaymentDialog(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        record: record!,
        payment: payment,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> print() async {
    try {
      final data = await repo.get(widget.payrollId);
      await Printing.layoutPdf(
        onLayout: (_) => payrollPdf(data, widget.currency),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось сформировать расчётный листок.');
      }
    }
  }

  Future<void> deleteDraft() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand('DELETE', repo.path(widget.payrollId), {
        'version': record!['version'],
      });
      await pending!.execute(widget.api);
      pending = null;
      if (mounted) {
        Navigator.pop(context);
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

  Future<void> paymentHistory(Map<String, dynamic> p) async {
    try {
      final data = jsonObject(
        await widget.api.request('GET', [
          ...repo.path(widget.payrollId, 'payments'),
          p['id'] as String,
          'history',
        ]),
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('История выплаты зарплаты'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((data['items'] as List).isEmpty)
                    const Text('Исправлений пока нет.'),
                  ...(data['items'] as List).map(jsonObject).map((h) {
                    final old = jsonObject(h['snapshot']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${h['changed_at']} · ${h['actor_name']}\nБыло: ${moneyText(old['amount'] as num, widget.currency)} · ${old['business_date']}\n${old['reason'] ?? ''}',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть историю выплаты'),
            ),
          ],
        ),
      );
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = record == null
            ? <String, dynamic>{}
            : jsonObject(record!['data']),
        c = d['calculation'] == null ? null : jsonObject(d['calculation']),
        person = d['input'] == null
            ? <String, dynamic>{}
            : jsonObject(jsonObject(d['input'])['employee']);
    final enabled = !busy && pending == null,
        status = record?['status'],
        canPost = hasCompanyPermission(context, 'payroll.post'),
        canWrite = hasCompanyPermission(context, 'payroll.write'),
        canPay =
            hasCompanyPermission(context, 'payroll.settle') &&
            hasCompanyPermission(context, 'wallets.transact');
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text('Зарплата ${record?['month'] ?? ''}'),
        content: SizedBox(
          width: 1000,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (record != null) ...[
                  Text(
                    '${person['name']} · ${payrollStatuses[status]}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Дата начисления: ${d['businessDate']}'),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed:
                            enabled &&
                                canWrite &&
                                (status == 'DRAFT' || canPost)
                            ? edit
                            : null,
                        child: const Text('Изменить начисление'),
                      ),
                      OutlinedButton(
                        onPressed: enabled ? print : null,
                        child: const Text('Расчётный листок'),
                      ),
                      if (status == 'DRAFT')
                        FilledButton(
                          onPressed: enabled && canPost
                              ? () => run('post')
                              : null,
                          child: const Text('Провести зарплату'),
                        ),
                      if (status == 'DRAFT')
                        OutlinedButton(
                          onPressed: enabled && canWrite ? deleteDraft : null,
                          child: const Text('Удалить черновик зарплаты'),
                        ),
                      if (status == 'POSTED')
                        OutlinedButton(
                          onPressed: enabled && canPost
                              ? () => run('cancel')
                              : null,
                          child: const Text('Отменить начисление'),
                        ),
                      if (status == 'CANCELLED')
                        FilledButton(
                          onPressed: enabled && canPost
                              ? () => run('restore')
                              : null,
                          child: const Text('Восстановить начисление'),
                        ),
                      if (status != 'DRAFT' &&
                          (record!['outstanding'] as num) > 0)
                        FilledButton(
                          onPressed:
                              enabled &&
                                  canPay &&
                                  hasCompanyPermission(context, 'wallets.read')
                              ? () => pay()
                              : null,
                          child: const Text('Внести выплату зарплаты'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (d['policyAcknowledged'] != true)
                    const Text(
                      'До проведения откройте изменение начисления и зафиксируйте политику точности расчёта.',
                    ),
                  if (status == 'CANCELLED' &&
                      c != null &&
                      (c['sn'] as num) > 0)
                    const Text(
                      'Отмена зарплаты не отменяет социальный налог ИП за учтённого работника.',
                    ),
                  if (c != null) ...[
                    Text(
                      'Начислено: ${moneyText(c['gross'] as num, widget.currency)} · Удержания: ${moneyText(c['employeeWithholdings'] as num, widget.currency)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      'К выплате: ${moneyText(c['net'] as num, widget.currency)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Фактически выплачено: ${moneyText(record!['paid'] as num, widget.currency)} · Остаток: ${moneyText(record!['outstanding'] as num, widget.currency)}',
                    ),
                    if ((record!['employeeAdvance'] as num) > 0)
                      Text(
                        'Аванс сотруднику: ${moneyText(record!['employeeAdvance'] as num, widget.currency)}. Возврат или удержание из будущей зарплаты автоматически не выполняется.',
                      ),
                    const SizedBox(height: 16),
                    ...(c['breakdown'] as List)
                        .map(jsonObject)
                        .map(
                          (r) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '${payrollChargeLabels[r['code']]} · база ${moneyText(r['base'] as num, widget.currency)} · ${moneyText(r['amount'] as num, widget.currency)}',
                              ),
                            ),
                          ),
                        ),
                    Text(
                      'Общий расход фирмы: ${moneyText(c['totalCost'] as num, widget.currency)}',
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Фактические выплаты',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (payments.isEmpty) const Text('Выплат пока нет.'),
                  ...payments.map(
                    (p) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['business_date']} · ${p['wallet_name']} · ${moneyText(p['amount'] as num, widget.currency)}',
                            ),
                            if (p['voided'] == true)
                              const Text('Запись выплаты отменена'),
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: enabled
                                      ? () => paymentHistory(p)
                                      : null,
                                  child: const Text('История выплаты'),
                                ),
                                if (p['voided'] != true)
                                  TextButton(
                                    onPressed:
                                        enabled &&
                                            canPay &&
                                            hasCompanyPermission(
                                              context,
                                              'wallets.read',
                                            )
                                        ? () => pay(p)
                                        : null,
                                    child: const Text('Исправить выплату'),
                                  ),
                                TextButton(
                                  onPressed: enabled && canPay
                                      ? () => run(
                                          p['voided'] == true
                                              ? 'restore'
                                              : 'void',
                                          p,
                                        )
                                      : null,
                                  child: Text(
                                    p['voided'] == true
                                        ? 'Восстановить запись выплаты'
                                        : 'Отменить запись выплаты',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'История начисления',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (history.isEmpty) const Text('Изменений пока нет.'),
                  ...history.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${h['changed_at']} · ${h['actor_name']} · версия ${h['revision']}',
                      ),
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (pending != null)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => pending!.method == 'DELETE'
                              ? deleteDraft()
                              : run(),
                    child: const Text('Повторить подтверждение зарплаты'),
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
            child: const Text('Закрыть начисление'),
          ),
        ],
      ),
    );
  }
}

class PayrollPaymentDialog extends StatefulWidget {
  const PayrollPaymentDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.record,
    this.payment,
  });
  final BackendClient api;
  final String companyId, currency;
  final Map<String, dynamic> record;
  final Map<String, dynamic>? payment;
  @override
  State<PayrollPaymentDialog> createState() => _PayrollPaymentDialogState();
}

class _PayrollPaymentDialogState extends State<PayrollPaymentDialog> {
  final amount = TextEditingController(),
      date = TextEditingController(),
      reason = TextEditingController();
  List<Map<String, dynamic>> wallets = [];
  String? walletId, error;
  bool busy = false;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    amount.text = payrollMoneyInput(
      widget.payment?['amount'] as num? ?? widget.record['outstanding'] as num,
    );
    load();
  }

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await loadCompanyWallets(widget.api, widget.companyId),
      );
      if (mounted) {
        setState(() {
          wallets = (data['items'] as List)
              .map(jsonObject)
              .where((w) => w['scope'] == widget.record['scope'])
              .toList();
          walletId =
              widget.payment?['wallet_id'] as String? ??
              wallets.firstOrNull?['id'] as String?;
          date.text =
              widget.payment?['business_date'] as String? ??
              data['businessDate'] as String;
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
        widget.payment == null ? 'POST' : 'PUT',
        [
          ...PayrollRepository(
            widget.api,
            widget.companyId,
          ).path(widget.record['id'] as String, 'payments'),
          if (widget.payment != null) widget.payment!['id'] as String,
        ],
        {
          'walletId': walletId,
          'amount': parseMoney(amount.text),
          'businessDate': date.text,
          if (widget.payment != null) 'version': widget.payment!['version'],
          'reason': reason.text.trim().isEmpty
              ? 'Исправление выплаты зарплаты'
              : reason.text,
        },
      );
      await pending!.execute(widget.api);
      pending = null;
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
  Widget build(BuildContext context) {
    final enabled = !busy && pending == null;
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text(
          widget.payment == null
              ? 'Выплата зарплаты'
              : 'Исправление выплаты зарплаты',
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                const Text(
                  'Вносится фактически выполненная выплата. Деньги в банк автоматически не отправляются.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: walletId,
                  items: wallets
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text(w['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (v) => setState(() => walletId = v)
                      : null,
                  decoration: const InputDecoration(labelText: 'Счёт выплаты'),
                ),
                if (wallets.isEmpty && !busy)
                  const Text('Нужен денежный счёт с видом учёта начисления.'),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Сумма выплаты, KZT',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: date,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Дата выплаты YYYY-MM-DD',
                  ),
                ),
                if (widget.payment != null) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Причина исправления выплаты',
                    ),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: enabled ? () => Navigator.pop(context) : null,
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: busy || walletId == null ? null : save,
            child: Text(
              pending != null
                  ? 'Повторить выплату'
                  : widget.payment == null
                  ? 'Учесть выплату зарплаты'
                  : 'Сохранить выплату зарплаты',
            ),
          ),
        ],
      ),
    );
  }
}
