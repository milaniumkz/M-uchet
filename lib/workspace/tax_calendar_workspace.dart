import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';

const taxTaskStatuses = {
  'OPEN': 'Открыта',
  'DONE': 'Выполнена',
  'CANCELLED': 'Отменена',
};
const taxTaskCategories = {
  'TAX': 'Платёж налога',
  'REPORT': 'Отчётность',
  'PREPARATION': 'Подготовка',
  'OTHER': 'Другое',
};

class TaxCalendarWorkspace extends StatefulWidget {
  const TaxCalendarWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.onProfile,
  });
  final BackendClient api;
  final String companyId;
  final VoidCallback onProfile;
  @override
  State<TaxCalendarWorkspace> createState() => _TaxCalendarWorkspaceState();
}

class _TaxCalendarWorkspaceState extends State<TaxCalendarWorkspace> {
  final month = TextEditingController();
  bool started = false, busy = false;
  String? error, cursor, selectedDay;
  int tab = 0;
  Map<String, dynamic> preparation = {}, counts = {};
  List<Map<String, dynamic>> tasks = [];
  bool profile = false, documents = false, controls = false;
  RetriableCommand? pending;
  List<String> path([List<String> rest = const []]) => [
    'v1',
    'companies',
    widget.companyId,
    'tax-calendar',
    ...rest,
  ];
  bool get canWrite => hasCompanyPermission(context, 'tax-calendar.write');
  bool get canProfile => hasCompanyPermission(context, 'organization.read');
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  @override
  void dispose() {
    month.dispose();
    super.dispose();
  }

  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  DateTime get firstDay => DateTime.parse('${month.text}-01');
  Future<void> load({bool more = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (month.text.isEmpty) {
        final info = jsonObject(
          await widget.api.request('GET', path(), query: {'limit': '1'}),
        );
        month.text = (info['businessDate'] as String).substring(0, 7);
      }
      if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month.text) ||
          month.text.startsWith('0000')) {
        throw const FormatException('Укажите месяц YYYY-MM');
      }
      final first = firstDay;
      final data = jsonObject(
        await widget.api.request(
          'GET',
          path(),
          query: {
            'from': date(first),
            'to': date(DateTime(first.year, first.month + 1, 0)),
            'limit': '200',
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      Map<String, dynamic> prep = preparation;
      if (canProfile && !more) {
        prep = jsonObject(
          await widget.api.request('GET', path(['preparation', month.text])),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        tasks = [
          ...(more ? tasks : <Map<String, dynamic>>[]),
          ...(data['items'] as List).map(jsonObject),
        ];
        tasks.sort(
          (a, b) => ('${a['due_date']}:${a['title']}').compareTo(
            '${b['due_date']}:${b['title']}',
          ),
        );
        cursor = data['nextCursor'] as String?;
        counts = jsonObject(data['counts']);
        preparation = prep;
        final checks = jsonObject(prep['data'] ?? {});
        profile =
            checks['profileChecked'] == true && prep['profileCurrent'] == true;
        documents = checks['documentsChecked'] == true;
        controls = checks['controlsChecked'] == true;
        selectedDay = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> savePreparation() async {
    pending ??= RetriableCommand('PUT', path(['preparation', month.text]), {
      'version': preparation['version'] ?? 0,
      'settingsVersion': (preparation['settings'] as Map?)?['version'],
      'profileChecked': profile,
      'documentsChecked': documents,
      'controlsChecked': controls,
    });
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

  Future<void> edit([Map<String, dynamic>? task]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaxTaskEditor(
        api: widget.api,
        path: path(),
        task: task,
        initialDate: '${month.text}-01',
      ),
    );
    if (changed == true && mounted) {
      await load();
    }
  }

  Future<void> history(Map<String, dynamic> task) async {
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          path([task['id'] as String, 'history']),
        ),
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('История: ${task['title']}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((data['items'] as List).isEmpty)
                    const Text('Исправлений пока нет.'),
                  for (final item in (data['items'] as List).map(jsonObject))
                    ListTile(
                      title: Text('${jsonObject(item['snapshot'])['title']}'),
                      subtitle: Text(
                        '${jsonObject(item['snapshot'])['due_date']} · ${taxTaskStatuses[jsonObject(item['snapshot'])['status']]}\n${item['actor_name']} · ${item['changed_at']}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    }
  }

  Widget card(Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
  Widget heading(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
  Widget get preparationCard => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Подготовка к отчётности'),
        const SizedBox(height: 16),
        const SizedBox(height: 12),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Проверить профиль компании',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            preparation['profileCurrent'] == true
                ? 'Реквизиты текущей версии'
                : 'Подтвердите актуальные реквизиты и применимость режима',
          ),
          value: profile,
          onChanged: !canWrite || busy || pending != null
              ? null
              : (v) => setState(() => profile = v!),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Собрать документы за период',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: const Text('Документы, оплаты и начисления'),
          value: documents,
          onChanged: !canWrite || busy || pending != null
              ? null
              : (v) => setState(() => documents = v!),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Проверить контрольные соотношения',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: const Text(
            'Подтверждение вашей проверки перед подготовкой отчёта',
          ),
          value: controls,
          onChanged: !canWrite || busy || pending != null
              ? null
              : (v) => setState(() => controls = v!),
        ),
        if (preparation['ready'] == true)
          const Text(
            'Проверки сохранены. Официальный отчёт ещё не сформирован.',
          ),
        const SizedBox(height: 16),
        if (canWrite)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : savePreparation,
              child: Text(
                pending == null
                    ? 'Сохранить подготовку'
                    : 'Повторить сохранение',
              ),
            ),
          ),
      ],
    ),
  );
  Widget get deadlineOverview => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Ничего не пропустим'),
        const SizedBox(height: 32),
        const Text(
          'Официальные сроки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        const Text('Автоматически ещё не загружены'),
        const SizedBox(height: 32),
        const Text(
          'Добавляйте задачи с проверенной датой и основанием. Они сохраняются в общем календаре фирмы.',
        ),
        const SizedBox(height: 32),
        Text('Открыто задач: ${counts['open'] ?? 0}'),
        const SizedBox(height: 8),
        Text('Просрочено: ${counts['overdue'] ?? 0}'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Даты подтверждаются вручную',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  );
  Widget get preparationOverview => LayoutBuilder(
    builder: (context, size) => size.maxWidth >= 900
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: preparationCard),
              const SizedBox(width: 24),
              Expanded(child: deadlineOverview),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              preparationCard,
              const SizedBox(height: 24),
              deadlineOverview,
            ],
          ),
  );
  Widget tabButton(String label, int value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () => setState(() => tab = value),
        style: TextButton.styleFrom(
          foregroundColor: tab == value
              ? const Color(0xFF5B4FF5)
              : const Color(0xFF65728D),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: tab == value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      Container(
        width: 86,
        height: 3,
        color: tab == value ? const Color(0xFF5B4FF5) : Colors.transparent,
      ),
    ],
  );

  Widget get taskList => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          selectedDay == null ? 'Задачи месяца' : 'Задачи на $selectedDay',
        ),
        const SizedBox(height: 12),
        if (tasks
            .where((t) => selectedDay == null || t['due_date'] == selectedDay)
            .isEmpty)
          const Text('Задач на выбранный период нет.'),
        for (final task in tasks.where(
          (t) => selectedDay == null || t['due_date'] == selectedDay,
        ))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                title: Text(task['title'] as String),
                subtitle: Text(
                  '${task['due_date']} · ${taxTaskStatuses[task['status']]}\n${taxTaskCategories[jsonObject(task['data'])['category']]} · Дата подтверждена вручную',
                ),
                onTap: canWrite && !busy ? () => edit(task) : null,
                trailing: IconButton(
                  tooltip: 'История задачи',
                  onPressed: busy ? null : () => history(task),
                  icon: const Icon(Icons.history),
                ),
              ),
              if (jsonObject(task['data'])['notes'] != '')
                SelectableText(
                  'Примечание: ${jsonObject(task["data"])["notes"]}',
                ),
              if (jsonObject(task['data'])['source'] != '')
                SelectableText(
                  'Основание: ${jsonObject(task["data"])["source"]}',
                ),
              const Divider(),
            ],
          ),
        if (cursor != null)
          TextButton(
            onPressed: busy ? null : () => load(more: true),
            child: const Text('Загрузить ещё задачи'),
          ),
      ],
    ),
  );
  Widget get calendar => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Календарь задач'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: MediaQuery.sizeOf(context).width < 600 ? 0.85 : 2.5,
          children: [
            for (final day in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
              Center(child: Text(day)),
            for (var i = 1; i < firstDay.weekday; i++) const SizedBox(),
            for (
              var day = 1;
              day <= DateTime(firstDay.year, firstDay.month + 1, 0).day;
              day++
            )
              Builder(
                builder: (context) {
                  final selected = date(
                    DateTime(firstDay.year, firstDay.month, day),
                  );
                  final n = tasks
                      .where((t) => t['due_date'] == selected)
                      .length;
                  return TextButton(
                    onPressed: () => setState(
                      () => selectedDay = selectedDay == selected
                          ? null
                          : selected,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      backgroundColor: selectedDay == selected
                          ? const Color(0xFFE8E5FF)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 14, height: 1.2),
                        ),
                        if (n > 0)
                          Text(
                            '• $n',
                            maxLines: 1,
                            style: const TextStyle(fontSize: 10, height: 1.2),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        if (cursor != null)
          const Text(
            'Загрузите остальные задачи, чтобы увидеть все отметки месяца.',
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Налоговый календарь',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Общий для всей фирмы. Выбор проекта не скрывает налоговые задачи.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: month,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(labelText: 'Месяц YYYY-MM'),
              ),
            ),
            OutlinedButton(
              onPressed: busy || pending != null ? null : () => load(),
              child: const Text('Показать месяц'),
            ),
            if (canWrite)
              FilledButton.icon(
                onPressed: busy || month.text.isEmpty ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Добавить задачу'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            tabButton('Задачи', 0),
            tabButton('Календарь', 1),
            if (canProfile)
              TextButton(
                onPressed: widget.onProfile,
                child: const Text('Профиль компании'),
              ),
          ],
        ),
        const Divider(),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          SelectableText(error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Официальные сроки автоматически ещё не загружены. Здесь сохраняются ваши задачи и вручную подтверждённые даты с основанием. Изменение задачи или её статуса не создаёт платёж и не отправляет отчёт.',
          ),
        ),
        const SizedBox(height: 24),
        if (tab == 0 && canProfile) preparationOverview,
        if (tab == 1 && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month.text))
          calendar,
        const SizedBox(height: 24),
        Text(
          'Всего: ${counts['total'] ?? 0} · Открыто: ${counts['open'] ?? 0} · Просрочено: ${counts['overdue'] ?? 0} · Выполнено: ${counts['done'] ?? 0}',
        ),
        const SizedBox(height: 16),
        taskList,
      ],
    ),
  );
}

class TaxTaskEditor extends StatefulWidget {
  const TaxTaskEditor({
    super.key,
    required this.api,
    required this.path,
    required this.initialDate,
    this.task,
  });
  final BackendClient api;
  final List<String> path;
  final String initialDate;
  final Map<String, dynamic>? task;
  @override
  State<TaxTaskEditor> createState() => _TaxTaskEditorState();
}

class _TaxTaskEditorState extends State<TaxTaskEditor> {
  late final title = TextEditingController(
    text: widget.task?['title'] as String? ?? '',
  );
  late final due = TextEditingController(
    text: widget.task?['due_date'] as String? ?? widget.initialDate,
  );
  late final notes = TextEditingController(
    text: (widget.task?['data'] as Map?)?['notes'] as String? ?? '',
  );
  late final source = TextEditingController(
    text: (widget.task?['data'] as Map?)?['source'] as String? ?? '',
  );
  late String status = widget.task?['status'] as String? ?? 'OPEN',
      category =
          (widget.task?['data'] as Map?)?['category'] as String? ?? 'TAX';
  bool confirmed = false, busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void dispose() {
    title.dispose();
    due.dispose();
    notes.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (pending == null) {
      if (title.text.trim().isEmpty ||
          !confirmed ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(due.text)) {
        setState(
          () => error =
              'Укажите название, дату YYYY-MM-DD и подтвердите проверку срока.',
        );
        return;
      }
      pending = RetriableCommand(
        widget.task == null ? 'POST' : 'PUT',
        [...widget.path, if (widget.task != null) widget.task!['id'] as String],
        {
          'title': title.text.trim(),
          'dueDate': due.text,
          'status': status,
          'category': category,
          'notes': notes.text.trim(),
          'source': source.text.trim(),
          'dueDateConfirmed': true,
          if (widget.task != null) 'version': widget.task!['version'],
        },
      );
    }
    setState(() => busy = true);
    try {
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
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null && !busy,
    child: AlertDialog(
      title: Text(widget.task == null ? 'Новая задача' : 'Изменить задачу'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(labelText: 'Название задачи'),
              ),
              TextField(
                controller: due,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(labelText: 'Срок YYYY-MM-DD'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Вид задачи'),
                items: taxTaskCategories.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => category = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Статус задачи'),
                items: taxTaskStatuses.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => status = v!),
              ),
              TextField(
                controller: source,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Основание / ссылка на источник',
                ),
                maxLines: 2,
              ),
              TextField(
                controller: notes,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(labelText: 'Примечание'),
                maxLines: 3,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Дата и применимость срока проверены мной'),
                value: confirmed,
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => confirmed = v!),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
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
            pending == null ? 'Сохранить задачу' : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}
