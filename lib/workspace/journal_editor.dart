import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'company_access.dart';

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
  bool get editable => hasCompanyPermission(
    context,
    widget.entry == null ? 'accounting.post' : 'accounting.edit',
  );
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
    projectId = widget.entry == null
        ? widget.projectId
        : widget.entry!['project_id'] as String?;
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
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null,
    child: AlertDialog(
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
                enabled: !busy && pending == null && editable,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: date,
                enabled: !busy && pending == null && editable,
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
                onChanged: busy || pending != null || !editable
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
                  ...projectChoices(widget.projects, projectId).map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  ),
                ],
                onChanged: busy || pending != null || !editable
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
                          enabled: !busy && pending == null && editable,
                          decoration: const InputDecoration(labelText: 'Счёт'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: l.debit,
                          enabled: !busy && pending == null && editable,
                          decoration: const InputDecoration(labelText: 'Дебет'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: l.credit,
                          enabled: !busy && pending == null && editable,
                          decoration: const InputDecoration(
                            labelText: 'Кредит',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            busy ||
                                pending != null ||
                                !editable ||
                                lines.length <= 2
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
                onPressed:
                    busy || pending != null || !editable || lines.length >= 100
                    ? null
                    : () => setState(() => addLine()),
                icon: const Icon(Icons.add),
                label: const Text('Добавить строку'),
              ),
              if (widget.entry != null) ...[
                TextField(
                  controller: reason,
                  enabled: !busy && pending == null && editable,
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
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
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
          onPressed: busy || !editable ? null : save,
          child: Text(
            pending == null ? 'Сохранить запись' : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}
