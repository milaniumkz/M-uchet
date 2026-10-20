import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';
import 'commercial_repository.dart';
import 'payroll_repository.dart';

class PayrollEditor extends StatefulWidget {
  const PayrollEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.month,
    this.employeeId,
    this.record,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency, month;
  final String? employeeId, projectId;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? record;
  @override
  State<PayrollEditor> createState() => _PayrollEditorState();
}

class _PayrollEditorState extends State<PayrollEditor> {
  late final repo = PayrollRepository(widget.api, widget.companyId);
  final month = TextEditingController(),
      gross = TextEditingController(),
      date = TextEditingController(),
      note = TextEditingController(),
      reason = TextEditingController();
  List<Map<String, dynamic>> employees = [];
  String? employeeId, projectId, sex, error;
  String scope = 'ACCOUNTING';
  bool refreshEmployee = false, refreshCompany = false;
  bool declaration = false,
      singleEmployer = false,
      policy = false,
      busy = false;
  Map<String, dynamic>? preview;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    month.text = widget.month;
    employeeId = widget.employeeId;
    projectId = widget.projectId == 'unassigned' ? null : widget.projectId;
    if (widget.record != null) {
      final r = widget.record!,
          d = jsonObject(r['data']),
          i = jsonObject(d['input']),
          e = jsonObject(i['employee']);
      employeeId = r['employee_id'] as String;
      month.text = r['month'] as String;
      gross.text = payrollMoneyInput(i['gross'] as num);
      date.text = d['businessDate'] as String;
      note.text = d['note'] as String? ?? '';
      projectId = r['project_id'] as String?;
      scope = r['scope'] as String;
      sex = e['sex'] as String?;
      declaration = e['standardDeductionDeclaration'] == true;
      singleEmployer = i['singleEmployer'] == true;
      policy = d['policyAcknowledged'] == true;
    }
    load();
  }

  @override
  void dispose() {
    month.dispose();
    gross.dispose();
    date.dispose();
    note.dispose();
    reason.dispose();
    super.dispose();
  }

  void applyEmployee(Map<String, dynamic> e) {
    employeeId = e['id'] as String;
    gross.text = payrollMoneyInput(e['gross_base'] as num);
    final data = jsonObject(e['data']);
    sex = data['sex'] as String?;
    declaration = data['standardDeductionDeclaration'] == true;
    if (widget.projectId == null) {
      projectId = e['project_id'] as String?;
    }
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final rows = await repo.employees();
      if (mounted) {
        setState(() {
          employees = rows;
          if (widget.record == null) {
            final e =
                rows.where((e) => e['id'] == employeeId).firstOrNull ??
                rows.firstOrNull;
            if (e != null) {
              applyEmployee(e);
            }
          }
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

  void modified() => setState(() => preview = null);
  Map<String, dynamic> body() => {
    if (widget.record != null) 'payrollId': widget.record!['id'],
    if (widget.record != null) 'version': widget.record!['version'],
    if (preview != null)
      'expectedCompanyVersion': jsonObject(
        jsonObject(preview!['input'])['company'],
      )['version'],
    if (preview != null)
      'expectedEmployeeVersion': jsonObject(
        jsonObject(preview!['input'])['employee'],
      )['version'],
    'employeeId': employeeId,
    'month': month.text,
    'gross': parseMoney(gross.text),
    'sex': sex,
    'standardDeductionDeclaration': declaration,
    'category': 'ORDINARY_CASH_SALARY',
    'refreshEmployee': refreshEmployee,
    'refreshCompany': refreshCompany,
    'singleEmployer': singleEmployer,
    'policyAcknowledged': policy,
    'scope': scope,
    'projectId': projectId,
    if (date.text.trim().isNotEmpty) 'businessDate': date.text.trim(),
    'note': note.text,
    'reason': reason.text.trim().isEmpty
        ? 'Исправление начисления зарплаты'
        : reason.text,
  };
  Future<void> check() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request('POST', repo.path('preview'), body: body()),
      );
      if (mounted) {
        setState(() {
          preview = data;
          error = null;
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
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

  Future<void> opening() async {
    if (employeeId == null) {
      return;
    }
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayrollOpeningDialog(
        api: widget.api,
        companyId: widget.companyId,
        employeeId: employeeId!,
        month: month.text,
      ),
    );
    if (mounted) {
      modified();
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.record == null ? 'POST' : 'PUT',
        repo.path(widget.record?['id'] as String?),
        body(),
      );
      final data = jsonObject(await pending!.execute(widget.api));
      pending = null;
      if (mounted) {
        Navigator.pop(context, data['id'] as String);
      }
    } on BackendException catch (e) {
      if (!RetriableCommand.uncertain(e)) {
        pending = null;
      }
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

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && pending == null;
    final calculation = preview == null
        ? null
        : jsonObject(preview!['calculation']);
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text(
          widget.record == null
              ? 'Подготовить зарплату'
              : 'Изменить начисление зарплаты',
        ),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (widget.record?['status'] == 'CANCELLED')
                  const Text(
                    'Начисление отменено. Изменяется исходная сумма; она будет применена после восстановления. Текущий пересчёт показывает отменённый период.',
                  ),
                const Text(
                  'Обычная денежная зарплата гражданина РК — налогового резидента за 2026 год. Расчёт не охватывает нерезидентов, ГПХ, специальные льготы, вредные условия труда, отпускные и больничные. Расчёт не является платёжным поручением или декларацией.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: employeeId,
                  decoration: const InputDecoration(labelText: 'Сотрудник'),
                  items: employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(e['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: enabled && widget.record == null
                      ? (v) {
                          setState(
                            () => applyEmployee(
                              employees.firstWhere((e) => e['id'] == v),
                            ),
                          );
                          modified();
                        }
                      : null,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: month,
                  enabled: enabled && widget.record == null,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(
                    labelText: 'Месяц начисления YYYY-MM',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: gross,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Начислено до удержаний, KZT',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: sex ?? 'unknown',
                  items: const [
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text('Укажите пол'),
                    ),
                    DropdownMenuItem(value: 'M', child: Text('Мужской')),
                    DropdownMenuItem(value: 'F', child: Text('Женский')),
                  ],
                  onChanged: enabled
                      ? (v) {
                          setState(() => sex = v == 'unknown' ? null : v);
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Пол для проверки пенсионного возраста',
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: declaration,
                  onChanged: enabled
                      ? (v) {
                          setState(() => declaration = v!);
                          modified();
                        }
                      : null,
                  title: const Text('Есть заявление на базовый вычет'),
                  subtitle: const Text(
                    '30 МРП за месяц, в пределах 360 МРП за год. Остаток переносится только внутри этого работодателя.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: singleEmployer,
                  onChanged: enabled
                      ? (v) {
                          setState(() => singleEmployer = v!);
                          modified();
                        }
                      : null,
                  title: const Text(
                    'Проверены обычная зарплата и один работодатель',
                  ),
                  subtitle: const Text(
                    'Нет специальных освобождений, иных облагаемых выплат, единого платежа и параллельных работодателей. Условия проверены по документам сотрудника.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: policy,
                  onChanged: enabled
                      ? (v) {
                          setState(() => policy = v!);
                          modified();
                        }
                      : null,
                  title: const Text('Зафиксировать политику точности расчёта'),
                  subtitle: const Text(
                    'Социальные отчисления округляются вверх до тенге; ОСМС — до тенге по правилу 50 тиын. Для остальных величин используется учётная точность 0,01 тенге с HALF_UP. Политика сохраняется в начислении.',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: projectId ?? 'unassigned',
                  items: [
                    const DropdownMenuItem(
                      value: 'unassigned',
                      child: Text('Общие расходы фирмы'),
                    ),
                    ...projectChoices(widget.projects, projectId).map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: enabled
                      ? (v) {
                          setState(
                            () => projectId = v == 'unassigned' ? null : v,
                          );
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Проект расходов',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
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
                    DropdownMenuItem(
                      value: 'BOTH',
                      child: Text('Оба вида учёта'),
                    ),
                  ],
                  onChanged: enabled
                      ? (v) {
                          setState(() => scope = v!);
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(labelText: 'Вид учёта'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: date,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(
                    labelText: 'Дата начисления YYYY-MM-DD',
                    helperText: 'Если не указана — последний день месяца',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(
                    labelText: 'Примечание к начислению',
                  ),
                ),
                if (widget.record != null) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: refreshEmployee,
                    onChanged: enabled
                        ? (v) {
                            setState(() {
                              refreshEmployee = v!;
                              final e = refreshEmployee
                                  ? jsonObject(
                                      employees.firstWhere(
                                        (e) => e['id'] == employeeId,
                                      )['data'],
                                    )
                                  : jsonObject(
                                      jsonObject(
                                        jsonObject(
                                          widget.record!['data'],
                                        )['input'],
                                      )['employee'],
                                    );
                              sex = e['sex'] as String?;
                              declaration =
                                  e['standardDeductionDeclaration'] == true;
                            });
                            modified();
                          }
                        : null,
                    title: const Text(
                      'Обновить данные сотрудника из кадровой карточки',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: refreshCompany,
                    onChanged: enabled
                        ? (v) {
                            setState(() => refreshCompany = v!);
                            modified();
                          }
                        : null,
                    title: const Text(
                      'Обновить форму и налоговый режим из параметров фирмы',
                    ),
                  ),
                ],
                if (widget.record != null) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    enabled: enabled,
                    onChanged: (_) => modified(),
                    decoration: const InputDecoration(
                      labelText: 'Причина изменения зарплаты',
                    ),
                  ),
                ],
                TextButton(
                  onPressed:
                      enabled && employeeId != null && month.text != '2026-01'
                      ? opening
                      : null,
                  child: const Text('Начальные данные дохода и удержаний'),
                ),
                if (calculation != null) ...[
                  const Divider(),
                  Text(
                    'К выплате: ${moneyText(calculation['net'] as num, widget.currency)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Расход фирмы: ${moneyText(calculation['totalCost'] as num, widget.currency)}',
                  ),
                  Text('Дата начисления: ${preview!['businessDate']}'),
                  const SizedBox(height: 14),
                  ...(calculation['breakdown'] as List)
                      .map(jsonObject)
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${payrollChargeLabels[c['code']]} · база ${moneyText(c['base'] as num, widget.currency)} · сумма ${moneyText(c['amount'] as num, widget.currency)}',
                          ),
                        ),
                      ),
                  if ((preview!['affected'] as List).isNotEmpty)
                    Text(
                      'После изменения будут пересчитаны следующие месяцы: ${(preview!['affected'] as List).map(jsonObject).map((r) => r['month']).join(', ')}. Фактические выплаты не изменятся автоматически.',
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: enabled ? () => Navigator.pop(context) : null,
            child: const Text('Отмена'),
          ),
          OutlinedButton(
            onPressed: enabled && employeeId != null ? check : null,
            child: const Text('Рассчитать и проверить'),
          ),
          FilledButton(
            onPressed: busy || (preview == null && pending == null)
                ? null
                : save,
            child: Text(
              pending != null
                  ? 'Повторить сохранение'
                  : widget.record == null
                  ? 'Сохранить черновик зарплаты'
                  : 'Сохранить изменение зарплаты',
            ),
          ),
        ],
      ),
    );
  }
}

class PayrollOpeningDialog extends StatefulWidget {
  const PayrollOpeningDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.employeeId,
    required this.month,
  });
  final BackendClient api;
  final String companyId, employeeId, month;
  @override
  State<PayrollOpeningDialog> createState() => _PayrollOpeningDialogState();
}

class _PayrollOpeningDialogState extends State<PayrollOpeningDialog> {
  final through = TextEditingController(), source = TextEditingController();
  final fields = {
    for (final key in [
      'taxableBase',
      'ipn',
      'basicUsed',
      'basicCarry',
      'opvBase',
    ])
      key: TextEditingController(text: '0.00'),
  };
  final labels = {
    'taxableBase': 'Облагаемый доход ИПН с начала года',
    'ipn': 'Исчисленный ИПН с начала года',
    'basicUsed': 'Применённый базовый вычет с начала года',
    'basicCarry': 'Неиспользованный базовый вычет',
    'opvBase': 'Доход для исчисления ОПВ с начала года',
  };
  int version = 0;
  bool busy = false, confirmed = false;
  String? error;
  RetriableCommand? pending;
  late final repo = PayrollRepository(widget.api, widget.companyId);
  @override
  void initState() {
    super.initState();
    final m = DateTime.tryParse('${widget.month}-01');
    through.text = m == null
        ? '2026-09'
        : DateTime(m.year, m.month, 0).toIso8601String().substring(0, 7);
    load();
  }

  @override
  void dispose() {
    through.dispose();
    source.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          repo.path('openings', widget.employeeId),
        ),
      );
      if (mounted) {
        setState(() {
          version = data['version'] as int;
          if (data['data'] != null) {
            final d = jsonObject(data['data']),
                context = jsonObject(d['context']);
            through.text = data['through_month'] as String;
            source.text = d['sourceNote'] as String;
            confirmed = d['confirmed'] == true;
            for (final entry in fields.entries) {
              entry.value.text = payrollMoneyInput(context[entry.key] as num);
            }
          }
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
      pending ??=
          RetriableCommand('PUT', repo.path('openings', widget.employeeId), {
            'version': version,
            'throughMonth': through.text,
            'sourceNote': source.text,
            'confirmed': confirmed,
            ...fields.map((k, v) => MapEntry(k, parseMoney(v.text))),
          });
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
        title: const Text('Начальные данные зарплаты'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                const Text(
                  'Введите подтверждённые накопительные данные за предыдущие месяцы 2026 года у этого же работодателя. Эти суммы задают контекст расчёта ИПН и вычетов; деньги и бухгалтерские остатки они автоматически не создают. Вычеты другого работодателя переносить нельзя.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: through,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Последний включённый месяц YYYY-MM',
                  ),
                ),
                const SizedBox(height: 14),
                ...fields.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: e.value,
                      enabled: enabled,
                      decoration: InputDecoration(
                        labelText: '${labels[e.key]}, KZT',
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: source,
                  enabled: enabled,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Источник начальных данных',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: enabled
                      ? (v) => setState(() => confirmed = v!)
                      : null,
                  title: const Text(
                    'Подтверждены период, суммы и этот работодатель',
                  ),
                ),
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
            onPressed: busy ? null : save,
            child: Text(
              pending == null
                  ? 'Сохранить начальные данные'
                  : 'Повторить сохранение',
            ),
          ),
        ],
      ),
    );
  }
}
