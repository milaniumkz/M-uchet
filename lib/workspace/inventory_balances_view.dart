import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';

class InventoryBalancesView extends StatefulWidget {
  const InventoryBalancesView({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.scope,
    required this.warehouseId,
    required this.revision,
    this.operations = false,
    this.onOpenPurchase,
  });
  final BackendClient api;
  final String companyId, currency, scope;
  final String? warehouseId;
  final int revision;
  final bool operations;
  final Future<void> Function(String)? onOpenPurchase;
  @override
  State<InventoryBalancesView> createState() => _InventoryBalancesViewState();
}

class _InventoryBalancesViewState extends State<InventoryBalancesView> {
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? summary;
  String query = '', availability = 'ALL', type = '', note = '';
  String? cursor, error;
  bool busy = true, exporting = false;
  int generation = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant InventoryBalancesView old) {
    super.didUpdateWidget(old);
    if (old.companyId != widget.companyId ||
        old.scope != widget.scope ||
        old.warehouseId != widget.warehouseId ||
        old.revision != widget.revision ||
        old.operations != widget.operations) {
      if (old.operations != widget.operations) {
        rows = [];
        summary = null;
        cursor = null;
        note = '';
      }
      load();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Map<String, String> filters({bool more = false}) => {
    'scope': widget.scope,
    'limit': '100',
    if (widget.warehouseId != null) 'warehouseId': widget.warehouseId!,
    if (!widget.operations) ...{'q': query, 'availability': availability},
    if (widget.operations && type.isNotEmpty) 'type': type,
    if (more && cursor != null) 'after': cursor!,
  };
  List<String> get path => [
    'v1',
    'companies',
    widget.companyId,
    'inventory',
    widget.operations ? 'operations' : 'balances',
  ];
  Future<void> load({bool more = false}) async {
    final run = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = jsonObject(
        await widget.api.request('GET', path, query: filters(more: more)),
      );
      if (!mounted || run != generation) return;
      setState(() {
        final next = (result['items'] as List).map(jsonObject).toList();
        rows = more ? [...rows, ...next] : next;
        cursor = result['nextCursor'] as String?;
        summary = result['summary'] == null
            ? null
            : jsonObject(result['summary']);
        note = result['note'] as String? ?? '';
      });
    } on BackendException catch (e) {
      if (mounted && run == generation) setState(() => error = e.message);
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    setState(() => exporting = true);
    try {
      final result = jsonObject(
        await widget.api.request(
          'GET',
          path,
          query: {...filters(), 'export': 'csv'},
        ),
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить складские остатки',
        fileName: 'm-uchet-stock.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(result['csv'] as String)),
      );
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось сохранить CSV.');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget metric(String label, String value, double width) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF626E84)),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  );
  Widget status(Map<String, dynamic> row) {
    final empty = row['quantity'] == 0,
        unavailable = row['available'] == 0,
        low =
            row['minimum_stock'] != null &&
            (row['available'] as num) < (row['minimum_stock'] as num);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: empty
            ? const Color(0xFFF5F7FB)
            : unavailable || low
            ? const Color(0xFFFFF5DF)
            : const Color(0xFFE9F8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        empty
            ? 'Нет остатка'
            : unavailable
            ? 'В резерве'
            : low
            ? 'Мало'
            : 'Доступно',
        style: TextStyle(
          fontSize: 11,
          color: empty || unavailable || low
              ? const Color(0xFF626E84)
              : const Color(0xFF087A56),
        ),
      ),
    );
  }

  String positions(int count) {
    final rest = count % 100;
    final last = count % 10;
    return '$count ${rest >= 11 && rest <= 14
        ? 'позиций'
        : last == 1
        ? 'позиция'
        : last >= 2 && last <= 4
        ? 'позиции'
        : 'позиций'}';
  }

  String units(Map<String, dynamic> r, String field) =>
      '${r[field]} ${r['unit']}';
  Widget operation(Map<String, dynamic> row) {
    final d = jsonObject(row['data']);
    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(
          '${const {'RECEIPT': 'Поступление', 'TRANSFER': 'Перемещение', 'WRITEOFF': 'Списание', 'PURCHASE_RETURN': 'Возврат поставщику'}[row['kind']]} · ${row['product_name'] ?? d['productId']}',
        ),
        subtitle: Text(
          '${d['businessDate'] ?? (row['created_at'] as String).substring(0, 10)} · ${d['quantity']} ед.\n${d['reason'] ?? 'Стоимость: ${moneyText(d['cost'] as num, widget.currency)}'}',
        ),
        trailing: IconButton(
          tooltip: 'Подробности движения',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Складская операция'),
              content: SelectableText(
                'Номер: ${row['id']}\nДата: ${d['businessDate'] ?? row['created_at']}\nКоличество: ${d['quantity']}\nСтоимость: ${moneyText(d['cost'] as num, widget.currency)}\n${d['reason'] ?? ''}\n${d['documentId'] != null
                    ? 'Основание: ${d['documentNumber']} · ${d['status']}'
                    : d['journalId'] == null
                    ? 'Без денежного движения'
                    : 'Проводка: ${d['journalId']}'}',
              ),
              actions: [
                if (d['documentId'] != null && widget.onOpenPurchase != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onOpenPurchase!(d['documentId'] as String);
                    },
                    child: const Text('Открыть поступление'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (summary != null)
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 700
                ? box.maxWidth
                : (box.maxWidth - 52) / 3;
            return Wrap(
              spacing: 26,
              runSpacing: 16,
              children: [
                metric('Позиций на складе', '${summary!['positions']}', width),
                metric(
                  'Ниже минимума',
                  summary!['configured_minimums'] == 0
                      ? 'Минимум не задан'
                      : positions(summary!['low'] as int),
                  width,
                ),
                metric(
                  'Стоимость остатков',
                  moneyText(summary!['value'] as num, widget.currency),
                  width,
                ),
              ],
            );
          },
        ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!widget.operations)
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 416
                  ? MediaQuery.sizeOf(context).width - 56
                  : 360,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Поиск товара или склада',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  query = v;
                  timer?.cancel();
                  timer = Timer(
                    const Duration(milliseconds: 350),
                    () => load(),
                  );
                },
              ),
            ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              key: ValueKey(widget.operations),
              initialValue: widget.operations ? type : availability,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: widget.operations ? 'Вид движения' : 'Наличие',
              ),
              items:
                  (widget.operations
                          ? const {
                              '': 'Все движения',
                              'RECEIPT': 'Поступления',
                              'TRANSFER': 'Перемещения',
                              'WRITEOFF': 'Списания',
                              'PURCHASE_RETURN': 'Возвраты поставщикам',
                            }
                          : const {
                              'ALL': 'Все остатки',
                              'AVAILABLE': 'Есть доступный остаток',
                              'RESERVED': 'Есть резерв',
                              'EMPTY': 'Нет остатка',
                              'LOW': 'Ниже минимума',
                            })
                      .entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() {
                        if (widget.operations) {
                          type = v!;
                        } else {
                          availability = v!;
                        }
                      });
                      load();
                    },
            ),
          ),
          if (!widget.operations)
            OutlinedButton.icon(
              onPressed: busy || exporting ? null : export,
              icon: const Icon(Icons.download),
              label: Text(exporting ? 'Сохранение…' : 'Экспорт CSV'),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      if (rows.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('По выбранным условиям записей нет.'),
        ),
      if (widget.operations) ...rows.map(operation),
      if (!widget.operations && rows.isNotEmpty)
        LayoutBuilder(
          builder: (context, box) => box.maxWidth < 700
              ? Column(
                  children: rows
                      .map(
                        (r) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  r['product_name'] as String,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(r['warehouse_name'] as String),
                                const SizedBox(height: 12),
                                Text(
                                  'В наличии: ${units(r, 'quantity')} · Резерв: ${units(r, 'reserved')}',
                                ),
                                Text('Доступно: ${units(r, 'available')}'),
                                Text(
                                  'Стоимость: ${moneyText(r['value'] as num, widget.currency)}',
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: status(r),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              : Card(
                  margin: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: box.maxWidth),
                      child: DataTable(
                        headingTextStyle: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF626E84),
                        ),
                        dataTextStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF171B35),
                        ),
                        headingRowHeight: 42,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 70,
                        columnSpacing: 28,
                        columns: const [
                          DataColumn(label: Text('Товар / склад')),
                          DataColumn(label: Text('В наличии'), numeric: true),
                          DataColumn(label: Text('Резерв'), numeric: true),
                          DataColumn(label: Text('Доступно'), numeric: true),
                          DataColumn(label: Text('Стоимость'), numeric: true),
                          DataColumn(label: Text('Состояние')),
                        ],
                        rows: rows
                            .map(
                              (r) => DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 230,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['product_name'] as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            r['warehouse_name'] as String,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF626E84),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(units(r, 'quantity'))),
                                  DataCell(Text(units(r, 'reserved'))),
                                  DataCell(Text(units(r, 'available'))),
                                  DataCell(
                                    Text(
                                      moneyText(
                                        r['value'] as num,
                                        widget.currency,
                                      ),
                                    ),
                                  ),
                                  DataCell(status(r)),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
        ),
      if (note.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            note,
            style: const TextStyle(fontSize: 12, color: Color(0xFF626E84)),
          ),
        ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Показать ещё остатки'),
        ),
    ],
  );
}
