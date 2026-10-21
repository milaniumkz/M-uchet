import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import 'commercial_repository.dart';
import 'goods_repository.dart';

const _accent = Color(0xFF5654E8),
    _ink = Color(0xFF171B35),
    _muted = Color(0xFF626E84),
    _border = Color(0xFFE5E9F2);
const _months = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

class HomeWorkspace extends StatefulWidget {
  const HomeWorkspace({
    super.key,
    required this.api,
    required this.company,
    required this.companies,
    required this.projects,
    required this.onCompany,
    required this.onProject,
    required this.onSearch,
    required this.onAccount,
    required this.onCreate,
    required this.onOpenDocument,
    required this.onTask,
    required this.onScope,
    this.scope = 'ACCOUNTING',
    required this.onMore,
    required this.onOpenSection,
    required this.canOpenSection,
    this.projectId,
    this.canCreate = false,
  });
  final BackendClient api;
  final CompanyDto company;
  final List<CompanyDto> companies;
  final List<Map<String, dynamic>> projects;
  final String? projectId;
  final String scope;
  final void Function(String) onScope;
  final bool canCreate;
  final Future<void> Function() onMore;
  final void Function(String) onOpenSection;
  final bool Function(String) canOpenSection;
  final Future<void> Function(String) onCompany;
  final Future<void> Function(String?) onProject;
  final Future<void> Function() onSearch, onAccount;
  final Future<void> Function(String) onCreate;
  final Future<void> Function(String, String) onOpenDocument;
  final Future<void> Function(Map<String, dynamic>) onTask;
  @override
  State<HomeWorkspace> createState() => _HomeWorkspaceState();
}

class _HomeWorkspaceState extends State<HomeWorkspace> {
  Map<String, dynamic>? data;
  String? error;
  bool fetching = false, opening = false;
  bool get busy => fetching || opening;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => fetching = true);
    try {
      final result = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.company.id, 'dashboard'],
          query: {
            'scope': widget.scope,
            if (widget.projectId != null) 'projectId': widget.projectId!,
          },
        ),
      );
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => fetching = false);
    }
  }

  Future<bool> act(Future<void> Function() action) async {
    if (busy) return false;
    setState(() => opening = true);
    try {
      await action();
      return true;
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> open(Map<String, dynamic> document) async {
    if (await act(
          () => widget.onOpenDocument(
            document['sourceKind'] as String,
            document['id'] as String,
          ),
        ) &&
        mounted) {
      await load();
    }
  }

  Future<void> task(Map<String, dynamic> value) async {
    if (await act(() => widget.onTask(value)) && mounted) await load();
  }

  Future<void> create() async {
    if (await act(
          () => widget.onCreate(
            data?['companyBusinessDate'] as String? ??
                DateTime.now().toIso8601String().substring(0, 10),
          ),
        ) &&
        mounted) {
      await load();
    }
  }

  Widget companyPicker() => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: widget.company.id,
      isExpanded: true,
      items: widget.companies
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: busy ? null : (id) => widget.onCompany(id!),
    ),
  );
  Widget projectPicker() => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: widget.projectId ?? 'all',
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: 'all', child: Text('Вся фирма')),
        const DropdownMenuItem(
          value: 'unassigned',
          child: Text('Общие операции'),
        ),
        for (final p in widget.projects)
          DropdownMenuItem(
            value: p['id'] as String,
            child: Text(
              p['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: busy
          ? null
          : (id) => widget.onProject(id == 'all' ? null : id),
    ),
  );
  Widget topBar(bool narrow) {
    final user = (data?['userName'] as String? ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((x) => x.isNotEmpty)
        .take(2)
        .map((x) => x.characters.first.toUpperCase())
        .join();
    final search = Tooltip(
      message: 'Поиск по фирме',
      child: InkWell(
        onTap: busy ? null : () => act(widget.onSearch),
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, size: 19, color: _muted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Поиск по документам, людям и товарам',
                  style: TextStyle(fontSize: 13, color: _muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final profile = IconButton(
      tooltip: 'Мой аккаунт',
      onPressed: busy ? null : () => act(widget.onAccount),
      icon: CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFEFEEFE),
        child: user.isEmpty
            ? const Icon(Icons.person_outline, color: _accent, size: 18)
            : Text(
                user,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 30, vertical: 15),
      child: narrow
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: search),
                    IconButton(
                      tooltip: 'Разделы',
                      onPressed: busy ? null : () => act(widget.onMore),
                      icon: const Icon(Icons.menu, color: _muted),
                    ),
                    profile,
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: companyPicker()),
                    const SizedBox(width: 12),
                    Expanded(child: projectPicker()),
                  ],
                ),
              ],
            )
          : SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 20),
                  SizedBox(width: 180, child: companyPicker()),
                  const SizedBox(width: 20),
                  SizedBox(width: 180, child: projectPicker()),
                  const SizedBox(width: 20),
                  profile,
                  const SizedBox(width: 10),
                  const Text(
                    'RU',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
    );
  }

  String amount(num value) =>
      moneyText(value, widget.company.currency).replaceFirst(',00 ', ' ');
  Widget metric(String title, String key, String note, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.north_east, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount(jsonObject(data!['money'])[key] as num),
            style: const TextStyle(
              fontSize: 27,
              height: 1.1,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(fontSize: 11, height: 1.2, color: _muted),
          ),
        ],
      ),
    ),
  );
  String chartPeriod() {
    final rows = (data!['chart'] as List).map(jsonObject).toList();
    if (rows.isEmpty) return '6 месяцев';
    final first = rows.first['month'] as String,
        last = rows.last['month'] as String;
    final start =
        '${_months[int.parse(first.substring(5)) - 1]}${first.substring(0, 4) == last.substring(0, 4) ? '' : ' ${first.substring(0, 4)}'}';
    return '$start — ${_months[int.parse(last.substring(5)) - 1]} ${last.substring(0, 4)}';
  }

  Widget flowCard() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Движение денег',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEEFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: const Text(
                  '6 месяцев',
                  style: TextStyle(color: _accent, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.projectId == null
                ? 'Остатки по месяцам · ${chartPeriod()}'
                : 'Движение проекта · ${chartPeriod()}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _CashChart(
              rows: (data!['chart'] as List).map(jsonObject).toList(),
              currency: widget.company.currency,
            ),
          ),
        ],
      ),
    ),
  );
  Widget tasksCard() {
    final tasks = (data!['tasks'] as List).map(jsonObject).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Что сделать дальше',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 18),
            if (tasks.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Доступных задач на сегодня нет.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              ),
            for (final t in tasks.take(3))
              Expanded(
                child: InkWell(
                  onTap: busy ? null : () => task(t),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.15,
                                  fontWeight: FontWeight.bold,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                t['description'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String documentTitle(Map<String, dynamic> d) =>
      '${d['sourceKind'] == 'GOODS' ? 'Продажа товаров' : documentLabels[d['kind']]} № ${d['number']}';
  Widget status(Map<String, dynamic> d) {
    final good = ['POSTED', 'CLOSED', 'SHIPPED'].contains(d['status']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFE9F8F0) : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (d['sourceKind'] == 'GOODS'
                ? goodsStatuses[d['status']]
                : documentStatuses[d['status']]) ??
            d['status'] as String,
        style: TextStyle(
          fontSize: 11,
          color: good ? const Color(0xFF087A56) : _muted,
        ),
      ),
    );
  }

  Widget documentsCard(bool narrow) {
    final rows = (data!['recentDocuments'] as List).map(jsonObject).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Последние документы',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Text(
                  'Документов пока нет. Создайте первый документ.',
                  style: TextStyle(color: _muted),
                ),
              ),
            if (narrow)
              for (final d in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    documentTitle(d),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${d['counterparty']}\n${amount(d['total'] as num)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => open(d),
                ),
            if (!narrow && rows.isNotEmpty)
              LayoutBuilder(
                builder: (context, box) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 51,
                    horizontalMargin: 14,
                    columnSpacing: 28,
                    headingTextStyle: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                    ),
                    showCheckboxColumn: false,
                    columns: [
                      DataColumn(
                        columnWidth: FixedColumnWidth(box.maxWidth * .208),
                        label: const Text('Документ'),
                      ),
                      DataColumn(
                        columnWidth: FixedColumnWidth(box.maxWidth * .353),
                        label: const Text('Контрагент'),
                      ),
                      DataColumn(
                        columnWidth: FixedColumnWidth(box.maxWidth * .199),
                        label: const Text('Сумма'),
                      ),
                      DataColumn(
                        columnWidth: FixedColumnWidth(box.maxWidth * .240),
                        label: const Text('Статус'),
                      ),
                    ],
                    rows: rows
                        .map(
                          (d) => DataRow(
                            onSelectChanged: busy ? null : (_) => open(d),
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 210,
                                  child: Text(
                                    documentTitle(d),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: box.maxWidth * .353 - 28,
                                  child: Text(
                                    d['counterparty'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  amount(d['total'] as num),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(status(d)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> allTasks() async {
    final tasks = (data!['tasks'] as List).map(jsonObject).toList();
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Ближайшие задачи',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in tasks)
                      ListTile(
                        title: Text(item['title'] as String),
                        subtitle: Text(item['description'] as String),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) await task(selected);
  }

  Widget smallMetric(String title, String key) => Card(
    margin: EdgeInsets.zero,
    child: SizedBox(
      height: 103,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount(jsonObject(data!['money'])[key] as num),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget bottomItem(
    IconData icon,
    String label,
    VoidCallback? action, {
    bool active = false,
  }) => Expanded(
    child: InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: action == null
                  ? Colors.grey
                  : active
                  ? _accent
                  : _muted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: action == null
                    ? Colors.grey
                    : active
                    ? _accent
                    : _muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget mobile() {
    final tasks = (data?['tasks'] as List? ?? []).map(jsonObject).toList();
    final documents = widget.canOpenSection('sales')
        ? 'sales'
        : widget.canOpenSection('goods')
        ? 'goods'
        : null;
    final money = widget.canOpenSection('bank')
        ? 'bank'
        : widget.canOpenSection('cash')
        ? 'cash'
        : null;
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'М-учёт',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Поиск по фирме',
                    onPressed: busy ? null : () => act(widget.onSearch),
                    icon: const Icon(Icons.search, color: _muted),
                  ),
                  IconButton(
                    tooltip: 'Мой аккаунт',
                    onPressed: busy ? null : () => act(widget.onAccount),
                    icon: const Icon(Icons.person_outline, color: _muted),
                  ),
                ],
              ),
            ),
            if (fetching) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Обзор бизнеса',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Вид учёта главной',
                        enabled: !busy,
                        initialValue: widget.scope,
                        onSelected: widget.onScope,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'ACCOUNTING',
                            child: Text('Бухгалтерский учёт'),
                          ),
                          PopupMenuItem(
                            value: 'MANAGEMENT',
                            child: Text('Управленческий учёт'),
                          ),
                        ],
                        icon: const Icon(Icons.tune, color: _muted, size: 20),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: companyPicker()),
                      const SizedBox(width: 12),
                      Expanded(child: projectPicker()),
                    ],
                  ),
                  Text(
                    widget.scope == 'ACCOUNTING'
                        ? 'Бухгалтерский учёт'
                        : 'Управленческий учёт',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (data != null) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: SizedBox(
                        height: 142,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.projectId == null
                                    ? 'Деньги на счетах'
                                    : 'Чистое движение денег',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                              const Spacer(),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  amount(
                                    jsonObject(data!['money'])['cash'] as num,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'По данным учёта',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: smallMetric('Вам должны', 'receivables'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: smallMetric('К оплате', 'payables')),
                      ],
                    ),
                    if (widget.canCreate) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: busy ? null : create,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Создать документ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const Text(
                      'Что сделать дальше',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: busy || tasks.isEmpty
                            ? null
                            : () => task(tasks.first),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 98),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tasks.isEmpty
                                    ? 'Ближайших задач нет'
                                    : tasks.first['title'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tasks.isEmpty
                                    ? 'Новые задачи появятся здесь.'
                                    : tasks.first['description'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (tasks.length > 1)
                      TextButton(
                        onPressed: busy ? null : allTasks,
                        child: Text('Все задачи: ${tasks.length}'),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(height: 285, child: flowCard()),
                    const SizedBox(height: 24),
                    documentsCard(true),
                  ],
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    bottomItem(
                      Icons.home_outlined,
                      'Главная',
                      busy ? null : load,
                      active: true,
                    ),
                    bottomItem(
                      Icons.description_outlined,
                      'Документы',
                      busy || documents == null
                          ? null
                          : () => widget.onOpenSection(documents),
                    ),
                    bottomItem(
                      Icons.account_balance_wallet_outlined,
                      'Деньги',
                      busy || money == null
                          ? null
                          : () => widget.onOpenSection(money),
                    ),
                    bottomItem(
                      Icons.shopping_bag_outlined,
                      'Ещё',
                      busy ? null : () => act(widget.onMore),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 600) return mobile();
      final narrow = size.maxWidth < 950;
      return Column(
        children: [
          topBar(narrow),
          if (fetching) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                narrow ? 16 : 33,
                26,
                narrow ? 16 : 36,
                24,
              ),
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Вид учёта главной',
                  enabled: !busy,
                  initialValue: widget.scope,
                  onSelected: widget.onScope,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'ACCOUNTING',
                      child: Text('Бухгалтерский учёт'),
                    ),
                    PopupMenuItem(
                      value: 'MANAGEMENT',
                      child: Text('Управленческий учёт'),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ГЛАВНАЯ / ${widget.scope == 'ACCOUNTING' ? 'БУХГАЛТЕРСКИЙ УЧЁТ' : 'УПРАВЛЕНЧЕСКИЙ УЧЁТ'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _muted,
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 16, color: _muted),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 14,
                  children: [
                    const Text(
                      'Бизнес под контролем',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    if (widget.canCreate)
                      SizedBox(
                        width: 224,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: busy ? null : create,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(224, 44),
                            fixedSize: const Size(224, 44),
                            visualDensity: VisualDensity.standard,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Создать документ'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Главное за день. Начните с задач, которые требуют внимания.',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      tooltip: 'Обновить главную',
                      onPressed: busy ? null : load,
                      icon: const Icon(Icons.refresh, color: _muted, size: 20),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 22),
                if (data != null) ...[
                  LayoutBuilder(
                    builder: (context, box) {
                      final cardWidth = box.maxWidth < 700
                          ? box.maxWidth
                          : (box.maxWidth - 52) / 3;
                      return Wrap(
                        spacing: 26,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: metric(
                              widget.projectId == null
                                  ? 'Деньги на счетах'
                                  : 'Чистое движение денег',
                              'cash',
                              widget.projectId == null
                                  ? 'По учтённым операциям на сегодня'
                                  : 'По операциям выбранного проекта',
                              const Color(0xFF087A56),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: metric(
                              'Вам должны',
                              'receivables',
                              'Покупатели · по данным учёта',
                              _accent,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: metric(
                              'Нужно оплатить',
                              'payables',
                              'Поставщики · по данным учёта',
                              _accent,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (narrow) ...[
                    SizedBox(height: 285, child: flowCard()),
                    const SizedBox(height: 20),
                    SizedBox(height: 285, child: tasksCard()),
                  ] else
                    SizedBox(
                      height: 285,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 62, child: flowCard()),
                          const SizedBox(width: 24),
                          Expanded(flex: 38, child: tasksCard()),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  documentsCard(narrow),
                  const SizedBox(height: 26),
                  const Divider(color: _border),
                  const SizedBox(height: 8),
                  const Text(
                    'М-учёт · внутренний учёт вашей фирмы',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _CashChart extends StatelessWidget {
  const _CashChart({required this.rows, required this.currency});
  final List<Map<String, dynamic>> rows;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final values = rows.map((r) => (r['closing'] as num).toDouble()).toList();
    if (values.every((n) => n == 0)) {
      return const Center(
        child: Text(
          'Остатки на конец месяцев равны нулю',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      );
    }
    return Tooltip(
      message: rows
          .map(
            (r) => '${r['month']}: ${moneyText(r['closing'] as num, currency)}',
          )
          .join(String.fromCharCode(10)),
      child: CustomPaint(
        painter: _FlowPainter(rows, currency),
        size: Size.infinite,
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.rows, this.currency);
  final String currency;
  final List<Map<String, dynamic>> rows;
  void text(Canvas canvas, String value, Offset at, {bool centered = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontSize: 9,
          color: _muted,
          fontFamily: 'DejaVuSans',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(at.dx - (centered ? p.width / 2 : 0), at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty || size.width < 80 || size.height < 50) return;
    final values = rows.map((r) => (r['closing'] as num).toDouble()).toList();
    final peak = values.reduce((a, b) => math.max(a, b)),
        minimum = values.reduce((a, b) => math.min(a, b));
    final magnitude = math.max(peak.abs(), minimum.abs());
    if (magnitude == 0) return;
    final raw = magnitude / 3,
        power = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble(),
        ratio = raw / power;
    final step = math.max(
      1.0,
      ((ratio <= 1
                  ? 1
                  : ratio <= 2
                  ? 2
                  : ratio <= 5
                  ? 5
                  : 10) *
              power)
          .ceilToDouble(),
    );
    final floor = minimum < 0 ? (minimum * 1.05 / step).floor() * step : 0.0;
    final ceiling = peak > 0 ? (peak * 1.05 / step).ceil() * step : 0.0;
    final range = ceiling - floor;
    final ticks = (range / step).round();
    final left = 54.0,
        top = 12.0,
        width = size.width - left - 12,
        height = size.height - top - 24;
    final zeroY = top + height * (ceiling / range);
    final symbol = currency == 'KZT' ? '₸' : currency;
    final grid = Paint()
      ..color = _border
      ..strokeWidth = 1;
    final maxMajor = math.max(floor.abs(), ceiling.abs()) / 100;
    final unit = maxMajor >= 1e12
        ? 1e12
        : maxMajor >= 1e9
        ? 1e9
        : maxMajor >= 1e6
        ? 1e6
        : maxMajor >= 1e3
        ? 1e3
        : 1.0;
    final suffix = unit == 1e12
        ? 'трлн '
        : unit == 1e9
        ? 'млрд '
        : unit == 1e6
        ? 'млн '
        : unit == 1e3
        ? 'тыс '
        : '';
    for (var i = 0; i <= ticks; i++) {
      final y = top + height * (1 - i / ticks);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final value = (floor + i * step) / 100 / unit;
      final digits = value == value.truncateToDouble()
          ? 0
          : unit == 1
          ? 2
          : 1;
      text(
        canvas,
        '${value.toStringAsFixed(digits).replaceAll('.', ',')} $suffix$symbol',
        Offset(0, y - 5),
      );
    }
    final path = Path(), area = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        left + width * i / math.max(1, values.length - 1),
        top + height * (1 - (values[i] - floor) / range),
      );
      points.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        area.moveTo(point.dx, zeroY);
        area.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        area.lineTo(point.dx, point.dy);
      }
      final month = int.parse((rows[i]['month'] as String).substring(5));
      text(
        canvas,
        _months[month - 1],
        Offset(point.dx, top + height + 10),
        centered: true,
      );
    }
    area.lineTo(points.last.dx, zeroY);
    area.close();
    canvas.drawPath(area, Paint()..color = _accent.withValues(alpha: .10));
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = _accent);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.rows != rows;
}
