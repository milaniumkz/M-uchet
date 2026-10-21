import 'package:printing/printing.dart';
import 'purchase_return_pdf.dart';
import 'company_access.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';

class PurchaseReturns extends StatefulWidget {
  const PurchaseReturns({
    super.key,
    required this.repository,
    required this.document,
    required this.currency,
    required this.enabled,
    required this.canWrite,
    required this.execute,
  });
  final CommercialRepository repository;
  final Map<String, dynamic> document;
  final String currency;
  final bool enabled, canWrite;
  final Future<void> Function(RetriableCommand) execute;
  @override
  State<PurchaseReturns> createState() => _PurchaseReturnsState();
}

class _PurchaseReturnsState extends State<PurchaseReturns> {
  Map<String, dynamic>? data;
  String? error;
  List<String> get path =>
      widget.repository.path(widget.document['id'] as String, 'returns');
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final value = jsonObject(
        await widget.repository.api.request('GET', path),
      );
      if (mounted) setState(() => data = value);
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ReturnEditor(data: data!, row: row, currency: widget.currency),
    );
    if (value == null || !mounted) return;
    await widget.execute(
      RetriableCommand(
        row == null ? 'POST' : 'PUT',
        [...path, if (row != null) row['id'] as String],
        {
          ...value,
          'documentVersion': widget.document['version'],
          if (row != null) 'version': row['version'],
        },
      ),
    );
  }

  Future<void> history(Map<String, dynamic> row) async {
    try {
      final result = jsonObject(
        await widget.repository.api.request('GET', [
          ...path,
          row['id'] as String,
          'history',
        ]),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('История ${row['number']}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final raw in result['items'] as List)
                    Builder(
                      builder: (_) {
                        final h = jsonObject(raw),
                            s = jsonObject(h['snapshot']);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SelectableText(
                            'Версия ${s['version']} · ${h['actor_name']}\n${s['business_date']} · ${documentStatuses[s['status']]}\n${s['reason']}\n${moneyText((jsonObject(s['data'])['total'] as num?) ?? 0, widget.currency)}',
                          ),
                        );
                      },
                    ),
                  if ((result['items'] as List).isEmpty)
                    const Text('Исправлений пока нет.'),
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
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> exportPdf(Map<String, dynamic> row) async {
    try {
      final payload = jsonObject(
        await widget.repository.api.request('GET', [
          ...path,
          row['id'] as String,
          'export-data',
        ]),
      );
      final bytes = await purchaseReturnPdf(payload, widget.currency);
      await Printing.sharePdf(bytes: bytes, filename: '${row['number']}.pdf');
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось подготовить PDF. Повторите действие.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.canWrite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Товарный возврат уменьшает склад и задолженность в дату возврата. Деньги от поставщика учитываются отдельно. Доступны свободные партии исходного поступления.',
        ),
        const SizedBox(height: 12),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (data == null && error == null) const LinearProgressIndicator(),
        if (error != null)
          TextButton(onPressed: load, child: const Text('Обновить возвраты')),
        if (data != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: enabled && widget.document['status'] == 'POSTED'
                  ? () => edit()
                  : null,
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Вернуть товар поставщику'),
            ),
          ),
          for (final raw in data!['items'] as List)
            Builder(
              builder: (_) {
                final row = jsonObject(raw), details = jsonObject(row['data']);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['number']} · ${row['business_date']} · ${documentStatuses[row['status']]}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(row['reason'] as String),
                        Text(
                          'Уменьшение стоимости поставки: ${moneyText((details['total'] as num?) ?? 0, widget.currency)}',
                        ),
                        for (final rawLine in details['lines'] as List)
                          Builder(
                            builder: (_) {
                              final l = jsonObject(rawLine);
                              return Text(
                                '${l['productName']} · ${l['warehouseName']} · ${l['quantity']} ед. · ${moneyText(l['cost'] as num, widget.currency)}',
                              );
                            },
                          ),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: enabled ? () => edit(row) : null,
                              child: const Text('Исправить возврат'),
                            ),
                            TextButton(
                              onPressed: enabled
                                  ? () => widget.execute(
                                      RetriableCommand(
                                        'POST',
                                        [
                                          ...path,
                                          row['id'] as String,
                                          row['status'] == 'POSTED'
                                              ? 'cancel'
                                              : 'restore',
                                        ],
                                        {
                                          'version': row['version'],
                                          'documentVersion':
                                              widget.document['version'],
                                        },
                                      ),
                                    )
                                  : null,
                              child: Text(
                                row['status'] == 'POSTED'
                                    ? 'Отменить возврат'
                                    : 'Восстановить возврат',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  widget.enabled &&
                                      hasCompanyPermission(
                                        context,
                                        'documents.export',
                                      )
                                  ? () => exportPdf(row)
                                  : null,
                              child: const Text('PDF возврата'),
                            ),
                            TextButton(
                              onPressed: widget.enabled
                                  ? () => history(row)
                                  : null,
                              child: const Text('История возврата'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if ((data!['items'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Товарных возвратов пока нет.'),
            ),
        ],
      ],
    );
  }
}

class _ReturnEditor extends StatefulWidget {
  const _ReturnEditor({required this.data, required this.currency, this.row});
  final Map<String, dynamic> data;
  final Map<String, dynamic>? row;
  final String currency;
  @override
  State<_ReturnEditor> createState() => _ReturnEditorState();
}

class _ReturnEditorState extends State<_ReturnEditor> {
  final form = GlobalKey<FormState>();
  late final date = TextEditingController(
    text:
        (widget.row?['business_date'] ?? widget.data['businessDate']) as String,
  );
  late final reason = TextEditingController(
    text: widget.row?['reason'] as String? ?? '',
  );
  late final batches = (widget.data['batches'] as List)
      .map(jsonObject)
      .toList();
  late final previous = {
    for (final raw
        in (widget.row == null
            ? <dynamic>[]
            : jsonObject(widget.row!['data'])['lines'] as List))
      for (final a in jsonObject(raw)['allocations'] as List)
        jsonObject(a)['batchId'] as String: jsonObject(a)['quantity'] as int,
  };
  late final fields = {
    for (final b in batches)
      b['batch_id'] as String: TextEditingController(
        text: previous[b['batch_id']]?.toString() ?? '',
      ),
  };
  bool get cancelled => widget.row?['status'] == 'CANCELLED';
  @override
  void dispose() {
    date.dispose();
    reason.dispose();
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.row == null
          ? 'Возврат товара поставщику'
          : 'Исправление товарного возврата',
    ),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: 'Дата возврата (ГГГГ-ММ-ДД)',
                ),
                validator: (v) =>
                    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v ?? '')
                    ? null
                    : 'Укажите дату',
              ),
              TextFormField(
                controller: reason,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Основание возврата',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Укажите основание' : null,
              ),
              if (cancelled)
                const Text(
                  'Возврат отменён. Изменения не затронут склад до восстановления возврата.',
                ),
              ...[
                const Text(
                  'Укажите количество по партиям. Оставьте пустым партии, которые не возвращаете.',
                ),
                for (final b in batches)
                  Builder(
                    builder: (_) {
                      final id = b['batch_id'] as String,
                          available = cancelled
                              ? ((b['source_quantity'] as num?) ??
                                        (b['original_quantity'] as num))
                                    .toInt()
                                    .clamp(previous[id] ?? 0, 1000000000)
                              : (b['quantity'] as num).toInt() -
                                    (b['reserved'] as num).toInt() +
                                    (previous[id] ?? 0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextFormField(
                          key: ValueKey('return-quantity-$id'),
                          controller: fields[id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                '${b['product_name']} · ${b['warehouse_name']} · партия ${id.substring(0, 8)}',
                            helperText:
                                '${cancelled ? 'Исходное количество' : 'Доступно'}: $available · Стоимость единицы: ${moneyText(b['unit_cost'] as num, widget.currency)}',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final q = int.tryParse(v);
                            return q == null || q < 0 || q > available
                                ? 'Введите целое количество от 0 до $available'
                                : null;
                          },
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final lines = [
            for (final b in batches)
              if ((int.tryParse(fields[b['batch_id']]!.text) ?? 0) > 0)
                {
                  'batchId': b['batch_id'],
                  'quantity': int.parse(fields[b['batch_id']]!.text),
                },
          ];
          if (lines.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Укажите количество хотя бы в одной партии.'),
              ),
            );
            return;
          }
          Navigator.pop(context, {
            'businessDate': date.text,
            'reason': reason.text,
            if (!cancelled ||
                fields.entries.any(
                  (entry) =>
                      (int.tryParse(entry.value.text) ?? 0) !=
                      (previous[entry.key] ?? 0),
                ))
              'lines': lines,
          });
        },
        child: const Text('Сохранить товарный возврат'),
      ),
    ],
  );
}
