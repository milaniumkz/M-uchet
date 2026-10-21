import 'dart:convert';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';
import 'commercial_repository.dart';

Future<void> showStockCount(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String countId,
  required String currency,
  required List<Map<String, dynamic>> projects,
  required Future<void> Function() onChanged,
}) async {
  final catalogAllowed = hasCompanyPermission(context, 'catalog.read');
  final doc = jsonObject(
    await api.request('GET', [
      'v1',
      'companies',
      companyId,
      'inventory',
      'counts',
      countId,
    ]),
  );
  List<ResourceDto> products, warehouses;
  if (catalogAllowed) {
    final catalog = CatalogRepository(api, companyId);
    final values = await Future.wait([
      catalog.listAll('nomenklatura'),
      catalog.listAll('warehouses'),
    ]);
    products = values[0];
    warehouses = values[1];
  } else {
    products = (jsonObject(doc['data'])['lines'] as List)
        .map(jsonObject)
        .map(
          (l) => ResourceDto(l['productId'] as String, {
            'name': l['productName'],
          }, 1),
        )
        .toList();
    warehouses = [
      ResourceDto(doc['warehouse_id'] as String, {
        'name': 'Склад сохранённого пересчёта',
      }, 1),
    ];
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StockCountEditor(
      api: api,
      companyId: companyId,
      currency: currency,
      products: products,
      warehouses: warehouses,
      projects: projects,
      scope: doc['scope'] as String,
      warehouseId: doc['warehouse_id'] as String,
      today: doc['business_date'] as String,
      previous: doc,
    ),
  );
  await onChanged();
}

class StockCountsView extends StatefulWidget {
  const StockCountsView({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.products,
    required this.warehouses,
    required this.projects,
    required this.scope,
    required this.warehouseId,
    required this.today,
    required this.onChanged,
  });
  final BackendClient api;
  final String companyId, currency, scope;
  final String? warehouseId, today;
  final List<ResourceDto> products, warehouses;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<StockCountsView> createState() => _StockCountsViewState();
}

class _StockCountsViewState extends State<StockCountsView> {
  List<Map<String, dynamic>> rows = [];
  bool busy = true;
  String? error, cursor;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant StockCountsView old) {
    super.didUpdateWidget(old);
    if (old.companyId != widget.companyId ||
        old.scope != widget.scope ||
        old.warehouseId != widget.warehouseId) {
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (!mounted) return;
    final run = ++generation;
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'inventory', 'counts'],
          query: {
            'scope': widget.scope,
            if (widget.warehouseId != null) 'warehouseId': widget.warehouseId!,
            'limit': '50',
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      if (!mounted || run != generation) return;
      setState(() {
        final next = (result['items'] as List).map(jsonObject).toList();
        rows = more ? [...rows, ...next] : next;
        cursor = result['nextCursor'] as String?;
        error = null;
      });
    } on BackendException catch (e) {
      if (mounted && run == generation) setState(() => error = e.message);
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  Future<void> open([Map<String, dynamic>? previous]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockCountEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        products: widget.products,
        warehouses: widget.warehouses,
        projects: widget.projects,
        scope: widget.scope,
        warehouseId: widget.warehouseId,
        today: widget.today,
        previous: previous,
      ),
    );
    if (mounted) {
      await widget.onChanged();
      if (!mounted) return;
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed:
              busy ||
                  widget.products.isEmpty ||
                  widget.warehouses.isEmpty ||
                  !hasCompanyPermission(context, 'inventory.count')
              ? null
              : () => open(),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Начать инвентаризацию'),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Сначала сохраните фактический пересчёт. Проведение отдельно изменяет остатки и учёт. Движение денег не создаётся.',
        ),
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      for (final row in rows)
        Card(
          child: ListTile(
            title: Text(
              '${const {'DRAFT': 'Черновик', 'POSTED': 'Проведено', 'CANCELLED': 'Отменено'}[row['status']]} · ${row['business_date']}',
            ),
            subtitle: Text('${jsonObject(row['data'])['reason']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => open(row),
          ),
        ),
      if (!busy && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Пересчётов по выбранным условиям пока нет.'),
        ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Показать ещё инвентаризации'),
        ),
    ],
  );
}

class _CountLine {
  _CountLine(this.productId, String quantity, String price)
    : quantity = TextEditingController(text: quantity),
      price = TextEditingController(text: price);
  String productId;
  final TextEditingController quantity, price;
  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class StockCountEditor extends StatefulWidget {
  const StockCountEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.products,
    required this.warehouses,
    required this.projects,
    required this.scope,
    required this.warehouseId,
    required this.today,
    this.previous,
  });
  final BackendClient api;
  final String companyId, currency, scope;
  final String? warehouseId, today;
  final List<ResourceDto> products, warehouses;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? previous;
  @override
  State<StockCountEditor> createState() => _StockCountEditorState();
}

class _StockCountEditorState extends State<StockCountEditor> {
  Map<String, dynamic>? doc;
  final reason = TextEditingController(), date = TextEditingController();
  final lines = <_CountLine>[];
  late String warehouseId, scope;
  String? projectId, error;
  String baseline = '';
  bool get dirty {
    try {
      return doc == null || jsonEncode(body()) != baseline;
    } catch (_) {
      return true;
    }
  }

  bool confirmed = false, busy = false;
  RetriableCommand? pending;
  bool get writable => hasCompanyPermission(context, 'inventory.count');
  bool get enabled => writable && !busy && pending == null;
  @override
  void initState() {
    super.initState();
    warehouseId = widget.warehouseId ?? widget.warehouses.firstOrNull?.id ?? '';
    scope = widget.scope;
    date.text = widget.today ?? '';
    if (widget.previous != null) {
      hydrate(widget.previous!);
    } else if (widget.products.isNotEmpty) {
      lines.add(_CountLine(widget.products.first.id, '0', '0,00'));
    }
  }

  void hydrate(Map<String, dynamic> value) {
    doc = value;
    final data = jsonObject(value['data']);
    reason.text = data['reason'] as String;
    date.text = value['business_date'] as String;
    warehouseId = value['warehouse_id'] as String;
    scope = value['scope'] as String;
    projectId = value['project_id'] as String?;
    confirmed = data['valuationConfirmed'] == true;
    for (final line in lines) {
      line.dispose();
    }
    lines.clear();
    for (final raw in data['lines'] as List) {
      final l = jsonObject(raw);
      final cost = l['surplusUnitCost'] as int;
      lines.add(
        _CountLine(
          l['productId'] as String,
          '${l['countedQuantity']}',
          '${cost ~/ 100},${(cost % 100).toString().padLeft(2, '0')}',
        ),
      );
    }
    baseline = jsonEncode(body());
  }

  @override
  void dispose() {
    reason.dispose();
    date.dispose();
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> body() => {
    if (doc != null) 'version': doc!['version'],
    'warehouseId': warehouseId,
    'scope': scope,
    'projectId': projectId,
    if (date.text.trim().isNotEmpty) 'businessDate': date.text.trim(),
    'reason': reason.text,
    'valuationConfirmed': confirmed,
    'lines': lines.map((l) {
      final qty = int.tryParse(l.quantity.text.trim());
      if (qty == null || qty < 0) {
        throw const FormatException(
          'Фактический остаток — целое неотрицательное количество.',
        );
      }
      return {
        'productId': l.productId,
        'countedQuantity': qty,
        'surplusUnitCost': parseMoney(l.price.text),
      };
    }).toList(),
  };
  List<String> path([String? action]) => [
    'v1',
    'companies',
    widget.companyId,
    'inventory',
    'counts',
    if (doc != null) doc!['id'] as String,
    if (action != null) action,
  ];
  Future<void> execute(String action) async {
    setState(() => busy = true);
    try {
      if (pending == null) {
        if ((action == 'post' || action == 'cancel') && dirty) {
          throw const FormatException('Сначала сохраните изменения пересчёта.');
        }
        if (action == 'save' || action == 'rebase') {
          pending = RetriableCommand(doc == null ? 'POST' : 'PUT', path(), {
            ...body(),
            if (action == 'rebase') 'rebase': true,
          });
        } else {
          pending = RetriableCommand('POST', path(action), {
            'version': doc!['version'],
          });
        }
      }
      final result = jsonObject(await pending!.execute(widget.api));
      pending = null;
      if (mounted) {
        setState(() {
          hydrate(result);
          error = null;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on BackendException catch (e) {
      if (!RetriableCommand.uncertain(e)) pending = null;
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> history() async {
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request('GET', path('history')),
      );
      if (!mounted) return;
      setState(() => busy = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('История пересчёта'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final raw in result['items'] as List)
                    ListTile(
                      title: Text(
                        '${jsonObject(raw)['actor_name']} · версия ${jsonObject(jsonObject(raw)['snapshot'])['version']}',
                      ),
                      subtitle: Text(
                        '${jsonObject(raw)['changed_at'] ?? jsonObject(raw)['created_at'] ?? ''}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть историю'),
            ),
          ],
        ),
      );
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget select(
    String label,
    String value,
    List<DropdownMenuItem<String>> values,
    void Function(String) change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label/$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values,
    onChanged: enabled ? (v) => setState(() => change(v!)) : null,
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && pending == null,
    child: AlertDialog(
      title: Text(
        doc == null
            ? 'Новая инвентаризация'
            : 'Инвентаризация · версия ${doc!['version']}',
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (doc != null)
                Text(
                  'Статус: ${const {'DRAFT': 'Черновик', 'POSTED': 'Проведено', 'CANCELLED': 'Отменено'}[doc!['status']]}',
                ),
              select(
                'Склад пересчёта',
                warehouseId,
                widget.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(w.data['name'] as String),
                      ),
                    )
                    .toList(),
                (v) => warehouseId = v,
              ),
              const SizedBox(height: 12),
              select('Вид учёта пересчёта', scope, const [
                DropdownMenuItem(
                  value: 'ACCOUNTING',
                  child: Text('Бухгалтерский учёт'),
                ),
                DropdownMenuItem(
                  value: 'MANAGEMENT',
                  child: Text('Управленческий учёт'),
                ),
                DropdownMenuItem(value: 'BOTH', child: Text('Оба вида учёта')),
              ], (v) => scope = v),
              const SizedBox(height: 12),
              select(
                'Проект пересчёта',
                projectId ?? '',
                [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Общие операции фирмы'),
                  ),
                  ...projectChoices(widget.projects, projectId).map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  ),
                ],
                (v) => projectId = v.isEmpty ? null : v,
              ),
              TextField(
                controller: date,
                enabled: enabled,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Дата пересчёта',
                  hintText: 'ГГГГ-ММ-ДД',
                ),
              ),
              TextField(
                controller: reason,
                enabled: enabled,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Основание пересчёта',
                ),
              ),
              const SizedBox(height: 16),
              for (final (i, l) in lines.indexed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        select(
                          'Товар пересчёта ${i + 1}',
                          l.productId,
                          widget.products
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.data['name'] as String),
                                ),
                              )
                              .toList(),
                          (v) => l.productId = v,
                        ),
                        TextField(
                          controller: l.quantity,
                          enabled: enabled,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Фактический остаток',
                          ),
                        ),
                        TextField(
                          controller: l.price,
                          enabled: enabled,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText:
                                'Стоимость единицы излишка, ${widget.currency}',
                          ),
                        ),
                        if (doc != null &&
                            i <
                                (jsonObject(doc!['data'])['lines'] as List)
                                    .length)
                          Builder(
                            builder: (_) {
                              final original = jsonObject(
                                (jsonObject(doc!['data'])['lines'] as List)[i],
                              );
                              return Text(
                                'Учтено при сохранении: ${original['expectedQuantity']} · резерв ${original['reserved']}\nСохранённое расхождение: ${(original['countedQuantity'] as num) - (original['expectedQuantity'] as num)}',
                              );
                            },
                          ),
                        if (lines.length > 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: enabled
                                  ? () => setState(() {
                                      lines.removeAt(i).dispose();
                                    })
                                  : null,
                              child: const Text('Убрать строку'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed:
                    enabled && lines.length < 100 && widget.products.isNotEmpty
                    ? () => setState(
                        () => lines.add(
                          _CountLine(widget.products.first.id, '0', '0,00'),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Добавить товар пересчёта'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                onChanged: enabled
                    ? (v) => setState(() => confirmed = v!)
                    : null,
                title: const Text('Подтверждаю оценку излишка'),
                subtitle: const Text(
                  'Стоимость задаётся вами. Налог автоматически не рассчитывается. Недостача списывается по FIFO.',
                ),
              ),
              if (doc == null)
                const Text(
                  'Сохраните пересчёт, чтобы увидеть учётный остаток и расхождения до проведения.',
                ),
              if (doc != null && dirty)
                const Text(
                  'Сохраните изменения перед проведением или отменой.',
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (pending != null)
                const Text(
                  'Результат действия неизвестен. Повторите его с тем же запросом.',
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
          child: const Text('Закрыть пересчёт'),
        ),
        if (doc != null)
          TextButton(
            onPressed: busy || pending != null ? null : history,
            child: const Text('История пересчёта'),
          ),
        if (doc != null && doc!['status'] != 'POSTED')
          TextButton(
            onPressed: enabled ? () => execute('rebase') : null,
            child: const Text('Обновить учётный остаток'),
          ),
        if (doc != null && doc!['status'] == 'POSTED')
          TextButton(
            onPressed: enabled && !dirty ? () => execute('cancel') : null,
            child: const Text('Отменить проведение'),
          ),
        if (doc != null && doc!['status'] != 'POSTED')
          OutlinedButton(
            onPressed: enabled && !dirty ? () => execute('post') : null,
            child: const Text('Провести пересчёт'),
          ),
        if (writable)
          FilledButton(
            onPressed: busy ? null : () => execute('save'),
            child: Text(
              pending != null
                  ? 'Повторить действие'
                  : doc == null
                  ? 'Сохранить пересчёт'
                  : 'Сохранить изменения пересчёта',
            ),
          ),
      ],
    ),
  );
}
