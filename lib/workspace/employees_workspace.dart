import 'company_access.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';

class EmployeesWorkspace extends StatefulWidget {
  const EmployeesWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final String? projectId;
  @override
  State<EmployeesWorkspace> createState() => _EmployeesWorkspaceState();
}

class _EmployeesWorkspaceState extends State<EmployeesWorkspace> {
  List<Map<String, dynamic>> items = [];
  String? cursor, error;
  String search = '';
  bool busy = false;
  Timer? debounce;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final current = ++generation;
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'employees'],
          query: {
            'limit': '50',
            'q': search,
            if (widget.projectId != null) 'projectId': widget.projectId!,
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      if (mounted && current == generation) {
        setState(() {
          final next = (data['items'] as List).map(jsonObject).toList();
          items = more ? [...items, ...next] : next;
          cursor = data['nextCursor'] as String?;
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted && current == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> edit([Map<String, dynamic>? employee]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => EmployeeEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        employee: employee,
        projectId: widget.projectId == 'unassigned' ? null : widget.projectId,
      ),
    );
    if (changed == true && mounted) {
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
            'Сотрудники',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed: busy||!hasCompanyPermission(context,'employees.write') ? null : () => edit(),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Добавить сотрудника'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Кадровый реестр, условия работы и история изменений. Оклад — исходное условие, а не начисленная или выплаченная зарплата.',
      ),
      const SizedBox(height: 24),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Поиск по ФИО, ИИН или должности',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) {
          search = v;
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 350), () => load());
        },
      ),
      const SizedBox(height: 16),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (items.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Сотрудников по выбранным условиям нет.'),
        ),
      ...items.map(
        (e) => Card(
          elevation: 0,
          child: ListTile(
            title: Text(e['name'] as String),
            subtitle: Text(
              '${e['job_title']} · ${e['status'] == 'ACTIVE' ? 'Работает' : 'Неактивен'}\nОклад: ${moneyText(e['gross_base'] as num, widget.currency)}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => edit(e),
          ),
        ),
      ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Загрузить ещё'),
        ),
      TextButton.icon(
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ],
  );
}

class EmployeeEditor extends StatefulWidget {
  const EmployeeEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    this.employee,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? employee;
  final String? projectId;
  @override
  State<EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<EmployeeEditor> {
  final name = TextEditingController(),
      identifier = TextEditingController(),
      job = TextEditingController(),
      hire = TextEditingController(),
      birth = TextEditingController(),
      termination = TextEditingController(),
      gross = TextEditingController(text: '0.00'),
      citizenship = TextEditingController(text: 'KZ'),
      notes = TextEditingController();
  String status = 'ACTIVE';
  String? projectId, error;
  bool resident = true, declaration = false, busy = false;
  RetriableCommand? pending;
  List<Map<String, dynamic>> history = [];
  @override
  void initState() {
    super.initState();
    projectId = widget.projectId;
    hire.text = DateTime.now().toIso8601String().substring(0, 10);
    if (widget.employee != null) {
      final e = widget.employee!, d = jsonObject(e['data']);
      name.text = e['name'] as String;
      identifier.text = e['identifier'] as String? ?? '';
      job.text = e['job_title'] as String;
      hire.text = e['hire_date'] as String;
      birth.text = e['birth_date'] as String? ?? '';
      termination.text = e['termination_date'] as String? ?? '';
      final amount = (e['gross_base'] as num).toInt();
      gross.text =
          '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
      citizenship.text = d['citizenship'] as String;
      resident = d['resident'] == true;
      declaration = d['standardDeductionDeclaration'] == true;
      notes.text = d['notes'] as String;
      status = e['status'] as String;
      projectId = e['project_id'] as String?;
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
          'employees',
          widget.employee!['id'] as String,
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
    for (final c in [
      name,
      identifier,
      job,
      hire,
      birth,
      termination,
      gross,
      citizenship,
      notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.employee == null ? 'POST' : 'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'employees',
          if (widget.employee != null) widget.employee!['id'] as String,
        ],
        {
          'name': name.text,
          'identifier': identifier.text,
          'jobTitle': job.text,
          'hireDate': hire.text,
          'birthDate': birth.text.isEmpty ? null : birth.text,
          'terminationDate': termination.text.isEmpty ? null : termination.text,
          'grossBase': parseMoney(gross.text),
          'status': status,
          'projectId': projectId,
          'resident': resident,
          'citizenship': citizenship.text,
          'standardDeductionDeclaration': declaration,
          'notes': notes.text,
          if (widget.employee != null) 'version': widget.employee!['version'],
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

  Widget field(TextEditingController c, String label, {bool private = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          enabled: !busy && pending == null && hasCompanyPermission(context,'employees.write'),
          autocorrect: !private,
          enableSuggestions: !private,
          decoration: InputDecoration(labelText: label),
        ),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.employee == null ? 'Добавить сотрудника' : 'Карточка сотрудника',
    ),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(name, 'ФИО'),
            field(identifier, 'ИИН, 12 цифр', private: true),
            field(job, 'Должность'),
            field(hire, 'Дата приёма YYYY-MM-DD'),
            field(birth, 'Дата рождения YYYY-MM-DD'),
            field(termination, 'Дата увольнения YYYY-MM-DD, если есть'),
            field(gross, 'Оклад до удержаний, ${widget.currency}'),
            field(citizenship, 'Гражданство: код страны'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Статус'),
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('Работает')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('Неактивен')),
              ],
              onChanged: busy || pending != null || !hasCompanyPermission(context,'employees.write')
                  ? null
                  : (v) => setState(() => status = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: projectId ?? 'unassigned',
              decoration: const InputDecoration(
                labelText: 'Основной проект для затрат',
              ),
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
              onChanged: busy || pending != null || !hasCompanyPermission(context,'employees.write')
                  ? null
                  : (v) => setState(
                      () => projectId = v == 'unassigned' ? null : v,
                    ),
            ),
            CheckboxListTile(
              value: resident,
              onChanged: busy || pending != null || !hasCompanyPermission(context,'employees.write')
                  ? null
                  : (v) => setState(() => resident = v!),
              title: const Text('Налоговый резидент Казахстана'),
            ),
            CheckboxListTile(
              value: declaration,
              onChanged: busy || pending != null || !hasCompanyPermission(context,'employees.write')
                  ? null
                  : (v) => setState(() => declaration = v!),
              title: const Text(
                'Есть заявление на базовый налоговый вычет у этого работодателя',
              ),
            ),
            field(notes, 'Заметки'),
            if (widget.employee != null) ...[
              Text('История изменений: ${history.length}'),
              ...history.map(
                (h) => Text(
                  '${h['changed_at']} · версия ${jsonObject(h['snapshot'])['version']}',
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (pending != null)
              const Text(
                'Повтор сохранения использует исходные данные и тот же ключ операции.',
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
        onPressed: busy||!hasCompanyPermission(context,'employees.write') ? null : save,
        child: Text(
          pending == null ? 'Сохранить сотрудника' : 'Повторить сохранение',
        ),
      ),
    ],
  );
}
