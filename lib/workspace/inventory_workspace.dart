import 'company_access.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import '../backend/rest/repositories.dart';
import 'commercial_repository.dart';

class InventoryWorkspace extends StatefulWidget {
  const InventoryWorkspace({
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
  State<InventoryWorkspace> createState() => _InventoryWorkspaceState();
}

class _InventoryWorkspaceState extends State<InventoryWorkspace> {
  List<ResourceDto> products = [], warehouses = [];
  List<Map<String, dynamic>> batches = [];
  String? error, cursor;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<List<ResourceDto>> catalog(String kind) async {
    final result = <ResourceDto>[];
    String? after;
    while (true) {
      final page = await CatalogRepository(
        widget.api,
        widget.companyId,
      ).list(kind, after: after);
      result.addAll(page);
      if (page.length < 50) {
        break;
      }
      after = page.last.id;
    }
    return result;
  }

  Future<void> load({bool more = false}) async {
    setState(() => busy = true);
    try {
      if (!more) {
        products = await catalog('nomenklatura');
        warehouses = await catalog('warehouses');
      }
      final data = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'inventory'],
          query: {'limit': '100', if (more && cursor != null) 'after': cursor!},
        ),
      );
      if (mounted) {
        setState(() {
          final next = (data['items'] as List).map(jsonObject).toList();
          batches = more ? [...batches, ...next] : next;
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

  String name(List<ResourceDto> values, Object? id) =>
      values.where((r) => r.id == id).firstOrNull?.data['name'] as String? ??
      '$id';
  Future<void> action(String type) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => InventoryCommandDialog(
        api: widget.api,
        companyId: widget.companyId,
        type: type,
        products: products,
        warehouses: warehouses,
        projects: widget.projects,
      ),
    );
    if (result == true && mounted) {
      try {
        await widget.onChanged();
        await load();
      } on BackendException catch (e) {
        if (mounted) {
          setState(() => error = e.message);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const Text(
        'Складские остатки',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      const Text(
        'Партии и доступные остатки общие для фирмы. При отгрузке или списании себестоимость определяется сервером по FIFO. Количество задаётся целыми базовыми единицами товара.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed:
                busy ||
                    !hasCompanyPermission(context, 'inventory.receive') ||
                    products.isEmpty ||
                    warehouses.isEmpty
                ? null
                : () => action('receipt'),
            icon: const Icon(Icons.add),
            label: const Text('Поступление'),
          ),
          OutlinedButton(
            onPressed:
                busy ||
                    !hasCompanyPermission(context, 'inventory.move') ||
                    warehouses.length < 2 ||
                    products.isEmpty
                ? null
                : () => action('transfer'),
            child: const Text('Перемещение'),
          ),
          OutlinedButton(
            onPressed:
                busy ||
                    !hasCompanyPermission(context, 'inventory.writeoff') ||
                    products.isEmpty ||
                    warehouses.isEmpty
                ? null
                : () => action('writeoff'),
            child: const Text('Списание'),
          ),
        ],
      ),
      if (products.isEmpty || warehouses.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Сначала добавьте товар и склад в разделе «Товары и услуги».',
          ),
        ),
      const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      ...batches.map(
        (b) => Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name(products, b['product_id']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('${name(warehouses, b['warehouse_id'])} · ${b['scope']}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text('Всего: ${b['quantity']}'),
                    Text('Резерв: ${b['reserved']}'),
                    Text(
                      'Доступно: ${(b['quantity'] as num) - (b['reserved'] as num)}',
                    ),
                    Text(
                      'Стоимость единицы: ${moneyText(b['unit_cost'] as num, widget.currency)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      if (batches.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Товарных партий пока нет.'),
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

class InventoryCommandDialog extends StatefulWidget {
  const InventoryCommandDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.type,
    required this.products,
    required this.warehouses,
    required this.projects,
  });
  final BackendClient api;
  final String companyId, type;
  final List<ResourceDto> products, warehouses;
  final List<Map<String, dynamic>> projects;
  @override
  State<InventoryCommandDialog> createState() => _InventoryCommandDialogState();
}

class _InventoryCommandDialogState extends State<InventoryCommandDialog> {
  String? productId, warehouseId, targetId, projectId, error;
  String scope = 'ACCOUNTING';
  bool busy = false;
  RetriableCommand? pending;
  final quantity = TextEditingController(text: '1'),
      cost = TextEditingController(text: '0.00'),
      reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    productId = widget.products.first.id;
    warehouseId = widget.warehouses.first.id;
    targetId = widget.warehouses.length > 1 ? widget.warehouses[1].id : null;
  }

  @override
  void dispose() {
    quantity.dispose();
    cost.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (pending == null) {
        final units = int.tryParse(quantity.text.trim());
        if (units == null || units <= 0 || units > 1000000000000) {
          throw const FormatException(
            'Введите положительное целое количество базовых единиц.',
          );
        }
        pending = RetriableCommand(
          'POST',
          [
            'v1',
            'companies',
            widget.companyId,
            'inventory',
            switch (widget.type) {
              'receipt' => 'receipts',
              'transfer' => 'movements',
              _ => 'writeoffs',
            },
          ],
          {
            'productId': productId,
            'quantity': units,
            'scope': scope,
            'projectId': projectId,
            if (widget.type == 'transfer') ...{
              'sourceWarehouseId': warehouseId,
              'targetWarehouseId': targetId,
            } else
              'warehouseId': warehouseId,
            if (widget.type == 'receipt') 'unitCost': parseMoney(cost.text),
            if (widget.type == 'writeoff') 'reason': reason.text,
          },
        );
      }
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

  Widget select(
    String label,
    String? value,
    List<ResourceDto> items,
    void Function(String?) change,
  ) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (p) => DropdownMenuItem(
            value: p.id,
            child: Text(p.data['name'] as String),
          ),
        )
        .toList(),
    onChanged: busy || pending != null ? null : change,
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null,
    child: AlertDialog(
      title: Text(switch (widget.type) {
        'receipt' => 'Поступление товара',
        'transfer' => 'Перемещение товара',
        _ => 'Списание товара',
      }),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              select(
                'Товар',
                productId,
                widget.products,
                (v) => setState(() => productId = v),
              ),
              const SizedBox(height: 14),
              select(
                widget.type == 'transfer' ? 'Со склада' : 'Склад',
                warehouseId,
                widget.warehouses,
                (v) => setState(() => warehouseId = v),
              ),
              const SizedBox(height: 14),
              if (widget.type == 'transfer') ...[
                select(
                  'На склад',
                  targetId,
                  widget.warehouses,
                  (v) => setState(() => targetId = v),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: quantity,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Количество базовых единиц',
                ),
              ),
              const SizedBox(height: 14),
              if (widget.type == 'receipt')
                TextField(
                  controller: cost,
                  enabled: !busy && pending == null,
                  decoration: const InputDecoration(
                    labelText: 'Стоимость единицы, KZT',
                  ),
                ),
              if (widget.type == 'writeoff')
                TextField(
                  controller: reason,
                  enabled: !busy && pending == null,
                  decoration: const InputDecoration(
                    labelText: 'Причина списания',
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
              if (widget.type != 'transfer') ...[
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
                    ...projectChoices(widget.projects, projectId).map(
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
                const Text(
                  'При неизвестном результате повторите запрос: повторного движения не будет.',
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
          child: Text(pending == null ? 'Провести' : 'Повторить проведение'),
        ),
      ],
    ),
  );
}
