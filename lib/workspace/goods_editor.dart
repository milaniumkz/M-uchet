import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';
import 'commercial_repository.dart';
import 'goods_repository.dart';

class GoodsLineDraft {
  GoodsLineDraft([Map<String, dynamic>? item])
    : productId = item?['productId'] as String?,
      warehouseId = item?['warehouseId'] as String?,
      quantity = TextEditingController(text: '${item?['quantity'] ?? 1}'),
      price = TextEditingController(
        text: moneyInput(item?['unitPrice'] as num? ?? 0),
      );
  String? productId, warehouseId;
  final TextEditingController quantity, price;
  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

String moneyInput(num amount) =>
    '${amount.toInt() ~/ 100}.${(amount.toInt() % 100).toString().padLeft(2, '0')}';

class GoodsEditor extends StatefulWidget {
  const GoodsEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.today,
    this.order,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency, today;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? order;
  final String? projectId;
  @override
  State<GoodsEditor> createState() => _GoodsEditorState();
}

class _GoodsEditorState extends State<GoodsEditor> {
  late final repo = GoodsRepository(widget.api, widget.companyId);
  final date = TextEditingController(),
      note = TextEditingController(),
      vatReason = TextEditingController(),
      reason = TextEditingController();
  final lines = <GoodsLineDraft>[];
  List<ResourceDto> products = [], warehouses = [], clients = [];
  String? projectId, counterpartyId, error;
  String scope = 'ACCOUNTING';
  int vat = 0;
  bool busy = false;
  Map<String, dynamic>? preview;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    final d = widget.order == null ? null : jsonObject(widget.order!['data']);
    date.text = d?['businessDate'] as String? ?? widget.today;
    note.text = d?['note'] as String? ?? '';
    vatReason.text = d?['vatReason'] as String? ?? '';
    vat = d?['vatBasisPoints'] as int? ?? 0;
    scope = d?['scope'] as String? ?? 'ACCOUNTING';
    counterpartyId = d?['counterpartyId'] as String?;
    projectId = d == null
        ? (widget.projectId == 'unassigned' ? null : widget.projectId)
        : d['projectId'] as String?;
    for (final row in d?['items'] as List? ?? []) {
      lines.add(GoodsLineDraft(jsonObject(row)));
    }
    if (lines.isEmpty) {
      lines.add(GoodsLineDraft());
    }
    load();
  }

  @override
  void dispose() {
    date.dispose();
    note.dispose();
    vatReason.dispose();
    reason.dispose();
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await Future.wait([
        repo.resources('nomenklatura'),
        repo.resources('warehouses'),
        repo.resources('clients'),
      ]);
      if (mounted) {
        setState(() {
          products = data[0];
          warehouses = data[1];
          clients = data[2];
          for (final l in lines) {
            l.productId ??= products.firstOrNull?.id;
            l.warehouseId ??= warehouses.firstOrNull?.id;
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
    if (widget.order != null) 'orderId': widget.order!['id'],
    if (widget.order != null) 'expectedRevision': widget.order!['revision'],
    'businessDate': date.text,
    'counterpartyId': counterpartyId,
    'projectId': projectId,
    'scope': scope,
    'vatBasisPoints': vat,
    'vatReason': vatReason.text,
    'note': note.text,
    'reason': reason.text,
    'items': lines.map((l) {
      if (!RegExp(r'^\d{1,12}$').hasMatch(l.quantity.text)) {
        throw const FormatException(
          'Количество — положительное целое число базовых единиц.',
        );
      }
      return {
        'productId': l.productId,
        'warehouseId': l.warehouseId,
        'quantity': int.parse(l.quantity.text),
        'unitPrice': parseMoney(l.price.text),
      };
    }).toList(),
  };
  Future<void> check() async {
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request('POST', repo.path('preview'), body: body()),
      );
      if (mounted) {
        setState(() {
          preview = result;
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

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.order == null ? 'POST' : 'PUT',
        repo.path(widget.order?['id'] as String?),
        body(),
      );
      final result = jsonObject(await pending!.execute(widget.api));
      pending = null;
      if (mounted) {
        Navigator.pop(context, result['id'] as String);
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

  List<DropdownMenuItem<String>> options(
    List<ResourceDto> items,
    String? current,
  ) => [
    ...items.map(
      (r) => DropdownMenuItem(
        value: r.id,
        child: Text(r.data['name'] as String? ?? 'Без названия'),
      ),
    ),
    if (current != null && !items.any((r) => r.id == current))
      DropdownMenuItem(value: current, child: const Text('Сохранённая запись')),
  ];
  @override
  Widget build(BuildContext context) {
    final enabled = !busy && pending == null;
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text(
          widget.order == null
              ? 'Новая товарная продажа'
              : 'Изменить товарную продажу',
        ),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                const Text(
                  'Количество — в базовых единицах товара. Цена за единицу указана без НДС. Отгрузка списывает FIFO-себестоимость; исправление пересчитывает остатки и расчёты.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: date,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(
                    labelText: 'Дата продажи YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: counterpartyId ?? 'none',
                  items: [
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('Без привязки к клиенту'),
                    ),
                    ...options(clients, counterpartyId),
                  ],
                  onChanged: enabled
                      ? (v) {
                          setState(
                            () => counterpartyId = v == 'none' ? null : v,
                          );
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(labelText: 'Клиент'),
                ),
                const SizedBox(height: 14),
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
                  onChanged: enabled
                      ? (v) {
                          setState(
                            () => projectId = v == 'unassigned' ? null : v,
                          );
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(labelText: 'Проект'),
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
                const SizedBox(height: 18),
                ...lines.indexed.map((row) {
                  final l = row.$2;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Товар ${row.$1 + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: l.productId,
                            items: options(products, l.productId),
                            onChanged: enabled
                                ? (v) {
                                    setState(() => l.productId = v);
                                    modified();
                                  }
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Товар',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: l.warehouseId,
                            items: options(warehouses, l.warehouseId),
                            onChanged: enabled
                                ? (v) {
                                    setState(() => l.warehouseId = v);
                                    modified();
                                  }
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Склад',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: l.quantity,
                            enabled: enabled,
                            onChanged: (_) => modified(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Количество базовых единиц',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: l.price,
                            enabled: enabled,
                            onChanged: (_) => modified(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Цена без НДС, KZT',
                            ),
                          ),
                          if (lines.length > 1)
                            TextButton(
                              onPressed: enabled
                                  ? () {
                                      setState(() => lines.remove(l));
                                      l.dispose();
                                      modified();
                                    }
                                  : null,
                              child: const Text('Убрать товар'),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: enabled
                      ? () {
                          setState(
                            () => lines.add(
                              GoodsLineDraft()
                                ..productId = products.firstOrNull?.id
                                ..warehouseId = warehouses.firstOrNull?.id,
                            ),
                          );
                          modified();
                        }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить товар'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: vat,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Без НДС')),
                    DropdownMenuItem(
                      value: 1600,
                      child: Text('НДС 16% · 2026'),
                    ),
                  ],
                  onChanged: enabled
                      ? (v) {
                          setState(() => vat = v!);
                          modified();
                        }
                      : null,
                  decoration: const InputDecoration(labelText: 'НДС'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: vatReason,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(
                    labelText: 'Основание без НДС',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  enabled: enabled,
                  onChanged: (_) => modified(),
                  decoration: const InputDecoration(labelText: 'Примечание'),
                ),
                if (widget.order != null) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    enabled: enabled,
                    onChanged: (_) => modified(),
                    decoration: const InputDecoration(
                      labelText: 'Причина исправления',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (preview != null)
                  Text(
                    'Без НДС: ${moneyText(preview!['net'] as num, widget.currency)} · НДС: ${moneyText(preview!['vat'] as num, widget.currency)} · Итого: ${moneyText(preview!['total'] as num, widget.currency)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            onPressed: enabled ? check : null,
            child: const Text('Проверить сумму'),
          ),
          FilledButton(
            onPressed: busy || (preview == null && pending == null)
                ? null
                : save,
            child: Text(
              pending == null ? 'Сохранить продажу' : 'Повторить сохранение',
            ),
          ),
        ],
      ),
    );
  }
}
