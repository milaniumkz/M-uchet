import 'company_access.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'commercial_editor.dart';
import 'document_pdf.dart';
import 'document_files.dart';

class CommercialDetail extends StatefulWidget {
  const CommercialDetail({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.document,
    required this.projects,
    required this.onChanged,
  });
  final BackendClient api;
  final String companyId, currency;
  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<CommercialDetail> createState() => _CommercialDetailState();
}

class _CommercialDetailState extends State<CommercialDetail> {
  late Map<String, dynamic> doc = widget.document;
  late final repository = CommercialRepository(widget.api, widget.companyId);
  bool get editable =>
      hasCompanyPermission(context, 'documents.write') &&
      ((doc['status'] != 'POSTED' && (doc['paid'] as num? ?? 0) == 0) ||
          hasCompanyPermission(context, 'documents.post'));
  bool get canSettle =>
      hasCompanyPermission(context, 'documents.settle') &&
      hasCompanyPermission(context, 'wallets.transact');
  bool busy = false, uncertain = false;
  String? error;
  RetriableCommand? pending;
  int tab = 0;
  List<Map<String, dynamic>> related = [];
  Future<void> run(String action) =>
      execute(repository.action(doc['id'] as String, action));

  Future<void> execute(RetriableCommand intent) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      pending ??= intent;
      final result = await pending!.execute(widget.api);
      pending = null;
      uncertain = false;
      if (!mounted) {
        return;
      }
      final updated = result['kind'] is String
          ? result
          : await repository.get(doc['id'] as String);
      if (!mounted) return;
      setState(() {
        if (updated['id'] != doc['id']) {
          tab = 0;
          related = [];
        }
        doc = updated;
      });
      if (tab > 0 && tab < 4) await showRelated(tab);
      await widget.onChanged();
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          uncertain = RetriableCommand.uncertain(e);
          if (!uncertain) {
            pending = null;
          }
          error = uncertain
              ? 'Результат действия неизвестен. Повторите это же действие.'
              : e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> edit() async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommercialEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        direction: doc['kind'] == 'PURCHASE_ACT' ? 'purchases' : 'sales',
        document: doc,
      ),
    );
    if (value != null && mounted) {
      setState(() => doc = value);
      await widget.onChanged();
    }
  }

  Future<void> showRelated(int index) async {
    setState(() {
      busy = true;
      error = null;
      tab = index;
      related = [];
    });
    try {
      final result = await repository.related(
        doc['id'] as String,
        index == 1
            ? 'movements'
            : index == 2
            ? 'history'
            : 'payments',
      );
      if (mounted) {
        setState(() => related = result);
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

  Future<void> pay([Map<String, dynamic>? payment]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentDialog(
        repository: repository,
        doc: doc,
        currency: widget.currency,
        payment: payment,
      ),
    );
    if (result != null && mounted) {
      final updated = await repository.get(doc['id'] as String);
      if (!mounted) return;
      setState(() => doc = updated);
      if (tab == 3) await showRelated(3);
      await widget.onChanged();
    }
  }

  Future<void> pdf() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final source = jsonObject(
        await widget.api.request(
          'GET',
          repository.path(doc['id'] as String, 'export-data'),
        ),
      );
      final bytes = await documentPdf(source, widget.currency);
      await Printing.sharePdf(bytes: bytes, filename: '${doc['number']}.pdf');
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось подготовить PDF. Повторите действие.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget paymentCard(Map<String, dynamic> payment) => Card(
    key: ValueKey('payment-${payment['id']}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${payment['business_date']} · ${moneyText(payment['amount'] as num, widget.currency)}${payment['voided'] == true ? ' · запись отменена' : ''}',
          ),
          if (payment['voided'] != true)
            IconButton(
              tooltip: 'Изменить оплату',
              onPressed: busy || uncertain || !canSettle
                  ? null
                  : () => pay(payment),
              icon: const Icon(Icons.edit_outlined),
            ),
          TextButton(
            onPressed: busy || uncertain || !canSettle
                ? null
                : () => execute(
                    RetriableCommand('POST', [
                      ...repository.path(
                        payment['document_id'] as String,
                        'payments',
                      ),
                      payment['id'] as String,
                      payment['voided'] == true ? 'restore' : 'void',
                    ], const {}),
                  ),
            child: Text(
              payment['voided'] == true
                  ? 'Восстановить запись'
                  : 'Отменить запись',
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = jsonObject(doc['data']),
        party = jsonObject(data['counterparty']),
        canAct = doc['kind'] == 'SALE_INVOICE' && doc['status'] == 'ISSUED';
    final enabled = !busy && !uncertain;
    return PopScope(
      canPop: pending == null,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1149, maxHeight: 880),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${documentLabels[doc['kind']]} № ${doc['number']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Chip(label: Text(documentStatuses[doc['status']]!)),
                    TextButton.icon(
                      onPressed: enabled && editable ? edit : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Изменить'),
                    ),
                    TextButton.icon(
                      onPressed:
                          enabled &&
                              hasCompanyPermission(context, 'documents.export')
                          ? pdf
                          : null,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Скачать PDF'),
                    ),
                    if (doc['status'] == 'DRAFT' ||
                        doc['status'] == 'CANCELLED')
                      FilledButton(
                        onPressed:
                            enabled &&
                                hasCompanyPermission(context, 'documents.post')
                            ? () => run('post')
                            : null,
                        child: Text(
                          doc['kind'] == 'SALE_INVOICE'
                              ? 'Выставить счёт'
                              : 'Провести',
                        ),
                      ),
                    if (canAct)
                      FilledButton(
                        onPressed:
                            enabled &&
                                hasCompanyPermission(context, 'documents.write')
                            ? () => run('act')
                            : null,
                        child: const Text('Создать акт'),
                      ),
                    if (['ISSUED', 'POSTED'].contains(doc['status']) &&
                        (doc['outstanding'] as num) > 0)
                      FilledButton(
                        onPressed: enabled && canSettle ? pay : null,
                        child: const Text('Связать оплату'),
                      ),
                    if (doc['status'] != 'CANCELLED')
                      TextButton(
                        onPressed:
                            enabled &&
                                hasCompanyPermission(context, 'documents.post')
                            ? () => run('cancel')
                            : null,
                        child: const Text('Отменить документ'),
                      ),
                    if (uncertain)
                      FilledButton(
                        onPressed: busy ? null : () => execute(pending!),
                        child: const Text('Повторить действие'),
                      ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => tab = 0),
                      child: const Text('Документ'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => showRelated(1),
                      child: const Text('Движения'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => showRelated(2),
                      child: const Text('История'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => showRelated(3),
                      child: const Text('Оплаты'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => setState(() => tab = 4),
                      child: const Text('Вложения'),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: tab == 4
                        ? DocumentFiles(
                            key: ValueKey(doc['id']),
                            repository: repository,
                            documentId: doc['id'] as String,
                          )
                        : tab == 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE5E9F2),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${jsonObject(data['issuer'])['legal_name']} → ${party['name']}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Дата: ${doc['business_date']}'),
                                    const SizedBox(height: 24),
                                    ...((data['items'] as List).map((raw) {
                                      final l = jsonObject(raw);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Wrap(
                                          spacing: 24,
                                          runSpacing: 8,
                                          children: [
                                            SizedBox(
                                              width: 330,
                                              child: Text(
                                                l['description'] as String,
                                              ),
                                            ),
                                            Text(
                                              '${l['quantity']} ${l['unit']}',
                                            ),
                                            Text(
                                              moneyText(
                                                l['total'] as num,
                                                widget.currency,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })),
                                    const Divider(),
                                    Text(
                                      'Итого: ${moneyText(data['total'] as num, widget.currency)}',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Без НДС: ${moneyText(data['net'] as num, widget.currency)} · НДС: ${moneyText(data['vat'] as num, widget.currency)}',
                                    ),
                                    if (data['note'] != '')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Text(data['note'] as String),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 26,
                                runSpacing: 16,
                                children: [
                                  Text(
                                    'Оплачено: ${moneyText(doc['paid'] as num, widget.currency)}',
                                  ),
                                  Text(
                                    'Осталось: ${moneyText(doc['outstanding'] as num, widget.currency)}',
                                  ),
                                  if ((doc['customerCredit'] as num) > 0)
                                    Text(
                                      'Аванс / переплата: ${moneyText(doc['customerCredit'] as num, widget.currency)}',
                                    ),
                                ],
                              ),
                              if (doc['status'] == 'DRAFT')
                                const Padding(
                                  padding: EdgeInsets.only(top: 18),
                                  child: Text(
                                    'Черновик не влияет на бухгалтерский учёт.',
                                  ),
                                ),
                              if (doc['kind'] == 'SALE_INVOICE')
                                const Padding(
                                  padding: EdgeInsets.only(top: 18),
                                  child: Text(
                                    'Счёт предлагает оплатить услуги. Выручка признаётся актом; авансы учитываются отдельно.',
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: related.isEmpty
                                ? [const Text('Записей пока нет.')]
                                : related
                                      .map(
                                        (item) => tab == 3
                                            ? paymentCard(item)
                                            : Card(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Text(
                                                    tab == 1
                                                        ? '${item['business_date']} · ${item['description']}\n${(item['lines'] as List).map((raw) {
                                                            final l = jsonObject(raw);
                                                            return '${l['account']}: Дт ${moneyText(l['debit'] as num, widget.currency)} · Кт ${moneyText(l['credit'] as num, widget.currency)}';
                                                          }).join('\n')}'
                                                        : '${item['changed_at']} · изменение ${item['revision']} · ${item['actor_name'] ?? item['actor_id']}',
                                                  ),
                                                ),
                                              ),
                                      )
                                      .toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.repository,
    required this.doc,
    required this.currency,
    this.payment,
  });
  final CommercialRepository repository;
  final Map<String, dynamic>? payment;
  final Map<String, dynamic> doc;
  final String currency;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  List<Map<String, dynamic>> wallets = [];
  String? walletId, error;
  String amount = '', date = DateTime.now().toIso8601String().substring(0, 10);
  bool loading = true, busy = false, uncertain = false;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      amount = ((widget.payment!['amount'] as num) / 100).toStringAsFixed(2);
      date = widget.payment!['business_date'] as String;
    }
    load();
  }

  Future<void> load() async {
    try {
      final result = jsonObject(
        await widget.repository.api.request('GET', [
          'v1',
          'companies',
          widget.repository.companyId,
          'wallets',
        ]),
      );
      if (mounted) {
        setState(() {
          wallets = (result['items'] as List).map(jsonObject).toList();
          walletId =
              widget.payment?['wallet_id'] as String? ??
              (wallets.isEmpty ? null : wallets.first['id'] as String);
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (walletId == null) {
        throw const FormatException('Выберите денежный счёт.');
      }
      final payload = {
        'walletId': walletId,
        'amount': parseMoney(amount),
        'businessDate': date,
      };
      pending ??= widget.payment == null
          ? widget.repository.action(
              widget.doc['id'] as String,
              'payments',
              payload,
            )
          : RetriableCommand('PUT', [
              ...widget.repository.path(
                widget.payment!['document_id'] as String,
                'payments',
              ),
              widget.payment!['id'] as String,
            ], payload);
      final result = await pending!.execute(widget.repository.api);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          uncertain = RetriableCommand.uncertain(e);
          if (!uncertain) {
            pending = null;
          }
          error = uncertain
              ? 'Результат оплаты неизвестен. Повторите эту же оплату: повторного движения денег не будет.'
              : e.message;
        });
      }
    } on FormatException catch (e) {
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
        widget.payment == null ? 'Связать оплату' : 'Изменить запись оплаты',
      ),
      content: SizedBox(
        width: 484,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading || busy) const LinearProgressIndicator(),
              Text(
                'Осталось оплатить: ${moneyText(widget.doc['outstanding'] as num, widget.currency)}',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: walletId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Денежный счёт'),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w['id'] as String,
                        child: Text(w['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: busy || uncertain ? null : (v) => walletId = v,
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: amount,
                enabled: !busy && !uncertain,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Сумма, ${widget.currency}',
                ),
                onChanged: (v) => amount = v,
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: date,
                enabled: !busy && !uncertain,
                decoration: const InputDecoration(
                  labelText: 'Дата оплаты: ГГГГ-ММ-ДД',
                ),
                onChanged: (v) => date = v,
              ),
              if (wallets.isEmpty && !loading)
                const Text('Сначала создайте денежный счёт в разделе денег.'),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
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
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: busy || loading ? null : save,
          child: Text(uncertain ? 'Повторить оплату' : 'Сохранить оплату'),
        ),
      ],
    ),
  );
}
