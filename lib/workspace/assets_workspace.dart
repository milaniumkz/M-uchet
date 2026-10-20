import 'dart:convert';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import '../backend/rest/repositories.dart';
import 'commercial_repository.dart';
import 'input_dialogs.dart';

const assetStatuses = {
  'DRAFT': 'Черновик',
  'ACTIVE': 'В эксплуатации',
  'WRITTEN_OFF': 'Списан',
};
Future<void> showAssetDetails(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String assetId,
  required String currency,
  required List<Map<String, dynamic>> projects,
  required Future<void> Function() onChanged,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AssetDetail(
      api: api,
      companyId: companyId,
      assetId: assetId,
      currency: currency,
      projects: projects,
    ),
  );
  await onChanged();
}

class AssetsWorkspace extends StatefulWidget {
  const AssetsWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<AssetsWorkspace> createState() => _AssetsWorkspaceState();
}

class _AssetsWorkspaceState extends State<AssetsWorkspace> {
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
          ['v1', 'companies', widget.companyId, 'assets'],
          query: {'limit': '50', if (more && cursor != null) 'after': cursor!},
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

  Future<void> create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AssetEditor(
        api: widget.api,
        companyId: widget.companyId,
        projects: widget.projects,
        currency: widget.currency,
      ),
    );
    if (result != null && mounted) {
      await load();
    }
  }

  Future<void> open(Map<String, dynamic> item) async {
    await showAssetDetails(
      context,
      api: widget.api,
      companyId: widget.companyId,
      assetId: item['id'] as String,
      currency: widget.currency,
      projects: widget.projects,
      onChanged: widget.onChanged,
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
            'Основные средства',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Добавить актив'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Имущество компании, учётная политика и история использования.',
      ),
      const SizedBox(height: 24),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (items.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Активов пока нет. Добавьте карточку и укажите собственную учётную политику.',
          ),
        ),
      ...items.map(
        (a) => Card(
          elevation: 0,
          child: ListTile(
            title: Text('${a['name']} · ${a['inventory_number']}'),
            subtitle: Text(
              '${assetStatuses[a['status']]}\nСтоимость: ${moneyText(jsonObject(a['data'])['cost'] as num, widget.currency)} · Балансовая стоимость: ${moneyText(a['carryingAmount'] as num, widget.currency)}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => open(a),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEEFE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Амортизация требует настроек: срок, остаточная стоимость и месяц начала определяются в карточке. Поддерживается линейный метод по полным месяцам с явным подтверждением политики. Налоговые вычеты не рассчитываются автоматически.',
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

class AssetDetail extends StatefulWidget {
  const AssetDetail({
    super.key,
    required this.api,
    required this.companyId,
    required this.assetId,
    required this.currency,
    required this.projects,
  });
  final BackendClient api;
  final String companyId, assetId, currency;
  final List<Map<String, dynamic>> projects;
  @override
  State<AssetDetail> createState() => _AssetDetailState();
}

class _AssetDetailState extends State<AssetDetail> {
  Map<String, dynamic>? asset;
  List<Map<String, dynamic>> history = [], movements = [];
  bool busy = false;
  String? error;
  RetriableCommand? pending;
  List<String> path([String? action]) => [
    'v1',
    'companies',
    widget.companyId,
    'assets',
    widget.assetId,
    if (action != null) action,
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(await widget.api.request('GET', path())),
          h = jsonObject(await widget.api.request('GET', path('history'))),
          m = jsonObject(await widget.api.request('GET', path('movements')));
      if (mounted) {
        setState(() {
          asset = data;
          history = (h['items'] as List).map(jsonObject).toList();
          movements = (m['items'] as List).map(jsonObject).toList();
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

  Future<void> execute(String action, Map<String, dynamic> body) async {
    pending ??= RetriableCommand('POST', path(action), body);
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
    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AssetEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        asset: asset,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> depreciate() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Начислить амортизацию',
        label: 'По месяц включительно YYYY-MM',
        confirm: 'Начислить',
        initialValue:
            asset!['depreciation_through'] as String? ??
            jsonObject(asset!['data'])['depreciationStart'] as String,
      ),
    );
    if (selected != null) {
      await execute('depreciation', {'throughMonth': selected});
    }
  }

  Future<void> writeoff() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AssetWriteoffDialog(),
    );
    if (result != null) {
      await execute('writeoff', result);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(asset == null ? 'Основное средство' : asset!['name'] as String),
    content: SizedBox(
      width: 900,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (asset != null) ...[
              Text(
                '${asset!['inventory_number']} · ${assetStatuses[asset!['status']]}',
              ),
              const SizedBox(height: 12),
              Text(
                'Первоначальная стоимость: ${moneyText(jsonObject(asset!['data'])['cost'] as num, widget.currency)}',
              ),
              Text(
                'Амортизация: ${moneyText(asset!['depreciation'] as num, widget.currency)}',
              ),
              Text(
                'Балансовая стоимость: ${moneyText(asset!['carryingAmount'] as num, widget.currency)}',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: busy || pending != null ? null : edit,
                    child: const Text('Изменить актив'),
                  ),
                  if (asset!['status'] != 'ACTIVE')
                    FilledButton(
                      onPressed: busy || pending != null
                          ? null
                          : () => execute('activate', {}),
                      child: Text(
                        asset!['status'] == 'DRAFT'
                            ? 'Ввести в эксплуатацию'
                            : 'Восстановить актив',
                      ),
                    ),
                  if (asset!['status'] == 'ACTIVE') ...[
                    FilledButton(
                      onPressed: busy || pending != null ? null : depreciate,
                      child: const Text('Начислить амортизацию'),
                    ),
                    OutlinedButton(
                      onPressed: busy || pending != null ? null : writeoff,
                      child: const Text('Списать актив'),
                    ),
                  ],
                ],
              ),
              if (pending != null)
                TextButton(
                  onPressed: busy ? null : () => execute('', {}),
                  child: const Text('Повторить запрос'),
                ),
              const SizedBox(height: 24),
              const Text(
                'Амортизация по месяцам',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              ...((asset!['schedule'] as List)
                  .map(jsonObject)
                  .map(
                    (m) => ListTile(
                      dense: true,
                      title: Text(m['month'] as String),
                      trailing: Text(
                        moneyText(m['amount'] as num, widget.currency),
                      ),
                    ),
                  )),
              const SizedBox(height: 20),
              Text(
                'История изменений: ${history.length}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...history.map(
                (h) => Text(
                  '${h['changed_at']} · версия ${jsonObject(h['snapshot'])['version']}',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Бухгалтерские движения',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              ...movements.map(
                (m) => ListTile(
                  dense: true,
                  title: Text(m['kind'] as String),
                  subtitle: Text(
                    '${m['business_date']} · ${m['active'] == true ? 'Действующее' : 'История'}',
                  ),
                  trailing: Text(
                    '${(jsonDecodeLines(m['lines'])).length} строки',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: busy ? null : load, child: const Text('Обновить')),
      TextButton(
        onPressed: busy || pending != null
            ? null
            : () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
  List<dynamic> jsonDecodeLines(Object? value) =>
      value is List ? value : jsonDecode(value as String) as List<dynamic>;
}

class AssetEditor extends StatefulWidget {
  const AssetEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    this.asset,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? asset;
  @override
  State<AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends State<AssetEditor> {
  final name = TextEditingController(),
      number = TextEditingController(),
      cost = TextEditingController(),
      residual = TextEditingController(text: '0.00'),
      life = TextEditingController(),
      date = TextEditingController(),
      start = TextEditingController(),
      location = TextEditingController();
  List<ResourceDto> suppliers = [];
  String? supplierId, projectId, error;
  String scope = 'ACCOUNTING';
  bool busy = false, ack = false;
  RetriableCommand? pending;
  String decimal(num value) =>
      '${value.toInt() ~/ 100}.${(value.toInt() % 100).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    date.text = DateTime.now().toIso8601String().substring(0, 10);
    if (widget.asset != null) {
      final a = widget.asset!, d = jsonObject(a['data']);
      name.text = a['name'] as String;
      number.text = a['inventory_number'] as String;
      cost.text = decimal(d['cost'] as num);
      residual.text = decimal(d['residual'] as num);
      life.text = '${d['lifeMonths']}';
      date.text = d['acquisitionDate'] as String;
      start.text = d['depreciationStart'] as String;
      location.text = d['location'] as String;
      scope = a['scope'] as String;
      projectId = a['project_id'] as String?;
      supplierId = a['supplier_id'] as String;
      ack = d['policyAcknowledged'] == true;
    }
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    setState(() => busy = true);
    try {
      final items = <ResourceDto>[];
      String? after;
      while (true) {
        final page = await CatalogRepository(
          widget.api,
          widget.companyId,
        ).list('suppliers', after: after);
        items.addAll(page);
        if (page.length < 50) {
          break;
        }
        after = page.last.id;
      }
      if (mounted) {
        setState(() {
          suppliers = items;
          supplierId ??= items.firstOrNull?.id;
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
  void dispose() {
    for (final c in [
      name,
      number,
      cost,
      residual,
      life,
      date,
      start,
      location,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final months = int.tryParse(life.text);
      if (months == null) {
        throw const FormatException(
          'Укажите срок полезного использования в месяцах.',
        );
      }
      pending ??= RetriableCommand(
        widget.asset == null ? 'POST' : 'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'assets',
          if (widget.asset != null) widget.asset!['id'] as String,
        ],
        {
          'name': name.text,
          'inventoryNumber': number.text,
          'supplierId': supplierId,
          'scope': scope,
          'projectId': projectId,
          'cost': parseMoney(cost.text),
          'residual': parseMoney(residual.text),
          'lifeMonths': months,
          'acquisitionDate': date.text,
          'depreciationStart': start.text,
          'location': location.text,
          'method': 'LINEAR_MONTHLY',
          'policyAcknowledged': ack,
          if (widget.asset != null) 'version': widget.asset!['version'],
        },
      );
      final result = await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, result);
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

  Widget field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      enabled: !busy && pending == null,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.asset == null ? 'Добавить актив' : 'Изменить актив'),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(name, 'Название актива'),
            field(number, 'Инвентарный номер'),
            field(cost, 'Первоначальная стоимость, ${widget.currency}'),
            field(residual, 'Остаточная стоимость, ${widget.currency}'),
            field(life, 'Срок полезного использования, месяцев'),
            field(date, 'Дата приобретения YYYY-MM-DD'),
            field(start, 'Месяц начала амортизации YYYY-MM'),
            field(location, 'Местонахождение'),
            if (suppliers.isEmpty && !busy)
              const Text('Добавьте поставщика в разделе «Контрагенты».'),
            if (suppliers.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: supplierId,
                decoration: const InputDecoration(labelText: 'Поставщик'),
                items: suppliers
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.data['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => supplierId = v),
              ),
            const SizedBox(height: 14),
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
                DropdownMenuItem(value: 'BOTH', child: Text('Оба контура')),
              ],
              onChanged: busy || pending != null
                  ? null
                  : (v) => setState(() => scope = v!),
            ),
            CheckboxListTile(
              value: ack,
              onChanged: busy || pending != null
                  ? null
                  : (v) => setState(() => ack = v!),
              title: const Text(
                'Подтверждаю линейную амортизацию по полным месяцам и введённые параметры собственной учётной политики.',
              ),
            ),
            const Text(
              'Ввод в эксплуатацию создаёт актив и задолженность поставщику. Не учитывайте ту же покупку вторым документом расходов. Это бухгалтерский учёт; налоговые вычеты отдельно не определяются.',
            ),
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
        onPressed: busy || suppliers.isEmpty ? null : save,
        child: Text(
          pending == null ? 'Сохранить актив' : 'Повторить сохранение',
        ),
      ),
    ],
  );
}

class AssetWriteoffDialog extends StatefulWidget {
  const AssetWriteoffDialog({super.key});
  @override
  State<AssetWriteoffDialog> createState() => _AssetWriteoffDialogState();
}

class _AssetWriteoffDialogState extends State<AssetWriteoffDialog> {
  final date = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10),
      ),
      reason = TextEditingController();
  @override
  void dispose() {
    date.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Списать актив'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: date,
          decoration: const InputDecoration(labelText: 'Дата YYYY-MM-DD'),
        ),
        TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Причина списания'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'businessDate': date.text,
          'reason': reason.text,
        }),
        child: const Text('Списать'),
      ),
    ],
  );
}
