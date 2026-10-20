import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'company_access.dart';
import 'goods_repository.dart';
import 'goods_editor.dart';
import 'goods_pdf.dart';

Future<void> showGoodsOrder(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String orderId,
  required String currency,
  required List<Map<String, dynamic>> projects,
  required Future<void> Function() onChanged,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => GoodsDetail(
      api: api,
      companyId: companyId,
      orderId: orderId,
      currency: currency,
      projects: projects,
    ),
  );
  await onChanged();
}

class GoodsWorkspace extends StatefulWidget {
  const GoodsWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
    this.projectId,
    this.from,
    this.to,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  final String? projectId, from, to;
  @override
  State<GoodsWorkspace> createState() => _GoodsWorkspaceState();
}

class _GoodsWorkspaceState extends State<GoodsWorkspace> {
  late final repo = GoodsRepository(widget.api, widget.companyId);
  List<Map<String, dynamic>> items = [];
  bool busy = false;
  String? error, cursor;
  String today = '';
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
          repo.path(),
          query: {
            'limit': '50',
            if (widget.projectId != null) 'projectId': widget.projectId!,
            if (widget.from != null) 'from': widget.from!,
            if (widget.to != null) 'to': widget.to!,
            if (more && cursor != null) 'after': cursor!,
          },
        ),
      );
      if (mounted) {
        setState(() {
          final next = (data['items'] as List).map(jsonObject).toList();
          items = more ? [...items, ...next] : next;
          cursor = data['nextCursor'] as String?;
          today = data['businessDate'] as String;
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

  Future<void> open(String id) async {
    await showGoodsOrder(
      context,
      api: widget.api,
      companyId: widget.companyId,
      orderId: id,
      currency: widget.currency,
      projects: widget.projects,
      onChanged: widget.onChanged,
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> create() async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoodsEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        today: today,
        projectId: widget.projectId,
      ),
    );
    if (id != null && mounted) {
      await open(id);
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
            'Товарные продажи',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed: busy || !hasCompanyPermission(context, 'orders.write')
                ? null
                : create,
            icon: const Icon(Icons.add),
            label: const Text('Новая товарная продажа'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Черновик → резерв → отгрузка → оплата. Печатная накладная предназначена для внутреннего учёта.',
      ),
      const SizedBox(height: 18),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (items.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Товарных продаж пока нет.'),
        ),
      ...items.map((o) {
        final d = jsonObject(o['data']),
            party = d['counterparty'] == null
                ? <String, dynamic>{}
                : jsonObject(d['counterparty']);
        return Card(
          child: ListTile(
            onTap: busy ? null : () => open(o['id'] as String),
            title: Text(
              '${d['number'] ?? 'Товарная продажа'} · ${party['name'] ?? 'Клиент не указан'}',
            ),
            subtitle: Text(
              '${d['businessDate'] ?? o['created_at'].toString().substring(0, 10)} · ${goodsStatuses[o['status']]}\nИтого ${moneyText(d['total'] as num, widget.currency)} · К оплате ${moneyText(o['outstanding'] as num, widget.currency)}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      }),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('Ещё продажи'),
        ),
      TextButton.icon(
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ],
  );
}

class GoodsDetail extends StatefulWidget {
  const GoodsDetail({
    super.key,
    required this.api,
    required this.companyId,
    required this.orderId,
    required this.currency,
    required this.projects,
  });
  final BackendClient api;
  final String companyId, orderId, currency;
  final List<Map<String, dynamic>> projects;
  @override
  State<GoodsDetail> createState() => _GoodsDetailState();
}

class _GoodsDetailState extends State<GoodsDetail> {
  late final repo = GoodsRepository(widget.api, widget.companyId);
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> payments = [], history = [], events = [];
  bool busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await Future.wait([
        repo.get(widget.orderId),
        widget.api
            .request('GET', repo.path(widget.orderId, 'payments'))
            .then(jsonObject),
        widget.api
            .request('GET', repo.path(widget.orderId, 'history'))
            .then(jsonObject),
      ]);
      if (mounted) {
        setState(() {
          order = data[0];
          payments = (data[1]['items'] as List).map(jsonObject).toList();
          history = (data[2]['items'] as List).map(jsonObject).toList();
          events = (data[2]['events'] as List? ?? []).map(jsonObject).toList();
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

  Future<void> run([String? action, Map<String, dynamic>? payment]) async {
    pending ??= RetriableCommand(
      'POST',
      payment == null
          ? repo.path(widget.orderId, action)
          : [
              ...repo.path(widget.orderId, 'payments'),
              payment['id'] as String,
              action!,
            ],
      payment == null ? {} : {'version': payment['version']},
    );
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
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoodsEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        today: jsonObject(order!['data'])['businessDate'] as String? ?? '',
        order: order,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> pay([Map<String, dynamic>? payment]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoodsPaymentDialog(
        api: widget.api,
        companyId: widget.companyId,
        order: order!,
        payment: payment,
        currency: widget.currency,
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> paymentHistory(Map<String, dynamic> payment) async {
    try {
      final data = jsonObject(
        await widget.api.request('GET', [
          ...repo.path(widget.orderId, 'payments'),
          payment['id'] as String,
          'history',
        ]),
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('История оплаты товара'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((data['items'] as List).isEmpty)
                    const Text('Исправлений оплаты пока нет.'),
                  ...(data['items'] as List).map(jsonObject).map((h) {
                    final old = jsonObject(h['snapshot']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${h['changed_at']} · ${h['actor_name']}\nБыло: ${moneyText(old['amount'] as num, widget.currency)} · ${old['business_date']}\n${old['reason'] ?? ''}',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть историю оплаты'),
            ),
          ],
        ),
      );
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  Future<void> print() async {
    try {
      final doc = await repo.get(widget.orderId);
      await Printing.layoutPdf(onLayout: (_) => goodsPdf(doc, widget.currency));
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Не удалось сформировать печатную форму. Повторите действие.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = order == null ? <String, dynamic>{} : jsonObject(order!['data']);
    final enabled = !busy && pending == null, status = order?['status'];
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text('Товарная продажа ${d['number'] ?? ''}'),
        content: SizedBox(
          width: 1000,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (order != null) ...[
                  Text('${goodsStatuses[status]} · ${d['businessDate'] ?? ''}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed:
                            enabled &&
                                hasCompanyPermission(context, 'orders.edit')
                            ? edit
                            : null,
                        child: const Text('Изменить продажу'),
                      ),
                      OutlinedButton(
                        onPressed: enabled ? print : null,
                        child: const Text('Печатная накладная'),
                      ),
                      if (status == 'CANCELLED')
                        FilledButton(
                          onPressed:
                              enabled &&
                                  hasCompanyPermission(context, 'orders.write')
                              ? () => run('restore')
                              : null,
                          child: const Text('Восстановить черновик'),
                        ),
                      if (status == 'NEW')
                        FilledButton(
                          onPressed:
                              enabled &&
                                  hasCompanyPermission(
                                    context,
                                    'orders.fulfill',
                                  )
                              ? () => run('reserve')
                              : null,
                          child: const Text('Зарезервировать'),
                        ),
                      if (status == 'RESERVED')
                        FilledButton(
                          onPressed:
                              enabled &&
                                  hasCompanyPermission(
                                    context,
                                    'orders.fulfill',
                                  )
                              ? () => run('ship')
                              : null,
                          child: const Text('Отгрузить товары'),
                        ),
                      if (['NEW', 'RESERVED'].contains(status))
                        OutlinedButton(
                          onPressed:
                              enabled &&
                                  hasCompanyPermission(context, 'orders.write')
                              ? () => run('cancel')
                              : null,
                          child: const Text('Отменить резерв и продажу'),
                        ),
                      if (status == 'SHIPPED')
                        FilledButton(
                          onPressed:
                              enabled &&
                                  hasCompanyPermission(
                                    context,
                                    'payments.write',
                                  ) &&
                                  hasCompanyPermission(
                                    context,
                                    'wallets.read',
                                  ) &&
                                  hasCompanyPermission(
                                    context,
                                    'wallets.transact',
                                  )
                              ? pay
                              : null,
                          child: const Text('Добавить оплату товара'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Итого ${moneyText(d['total'] as num, widget.currency)} · Оплачено ${moneyText(order!['paid'] as num, widget.currency)} · Остаток ${moneyText(order!['outstanding'] as num, widget.currency)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((order!['customerCredit'] as num) > 0)
                    Text(
                      'Аванс покупателя: ${moneyText(order!['customerCredit'] as num, widget.currency)}',
                    ),
                  const SizedBox(height: 18),
                  ...(d['items'] as List)
                      .map(jsonObject)
                      .map(
                        (l) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              '${l['productName'] ?? l['productId']} · ${l['warehouseName'] ?? l['warehouseId']}\n${l['quantity']} × ${moneyText(l['unitPrice'] as num, widget.currency)} без НДС',
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 18),
                  const Text(
                    'Оплаты',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (payments.isEmpty) const Text('Оплат пока нет.'),
                  ...payments.map(
                    (p) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['business_date'] ?? p['created_at']} · ${p['wallet_name'] ?? 'Общий денежный счёт прежней записи'} · ${moneyText(p['amount'] as num, widget.currency)}',
                            ),
                            if (p['voided'] == true)
                              const Text('Запись оплаты отменена'),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  onPressed: enabled
                                      ? () => paymentHistory(p)
                                      : null,
                                  child: const Text('История оплаты'),
                                ),
                                if (p['voided'] != true)
                                  TextButton(
                                    onPressed:
                                        enabled &&
                                            hasCompanyPermission(
                                              context,
                                              'payments.write',
                                            ) &&
                                            hasCompanyPermission(
                                              context,
                                              'wallets.read',
                                            ) &&
                                            hasCompanyPermission(
                                              context,
                                              'wallets.transact',
                                            )
                                        ? () => pay(p)
                                        : null,
                                    child: const Text(
                                      'Исправить оплату товара',
                                    ),
                                  ),
                                TextButton(
                                  onPressed:
                                      enabled &&
                                          hasCompanyPermission(
                                            context,
                                            'payments.write',
                                          ) &&
                                          hasCompanyPermission(
                                            context,
                                            'wallets.transact',
                                          )
                                      ? () => run(
                                          p['voided'] == true
                                              ? 'restore'
                                              : 'void',
                                          p,
                                        )
                                      : null,
                                  child: Text(
                                    p['voided'] == true
                                        ? 'Восстановить запись оплаты'
                                        : 'Отменить запись оплаты',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'История исправлений',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (history.isEmpty)
                    const Text('Исправлений полей пока нет.'),
                  ...events.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${e['created_at']} · ${e['actor_name']} · ${goodsEvents[e['action']] ?? 'Изменение товарной продажи'}',
                      ),
                    ),
                  ),
                  ...history.map(
                    (h) => Text('${h['changed_at']} · версия ${h['revision']}'),
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
                  FilledButton(
                    onPressed: busy ? null : run,
                    child: const Text('Повторить подтверждение операции'),
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
            child: const Text('Закрыть продажу'),
          ),
        ],
      ),
    );
  }
}

class GoodsPaymentDialog extends StatefulWidget {
  const GoodsPaymentDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.order,
    required this.currency,
    this.payment,
  });
  final BackendClient api;
  final String companyId, currency;
  final Map<String, dynamic> order;
  final Map<String, dynamic>? payment;
  @override
  State<GoodsPaymentDialog> createState() => _GoodsPaymentDialogState();
}

class _GoodsPaymentDialogState extends State<GoodsPaymentDialog> {
  final amount = TextEditingController(),
      date = TextEditingController(),
      reason = TextEditingController();
  List<Map<String, dynamic>> wallets = [];
  String? walletId, error;
  bool busy = false;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    amount.text = moneyInput(
      widget.payment?['amount'] as num? ?? widget.order['outstanding'] as num,
    );
    load();
  }

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'wallets'],
          query: {'limit': '200'},
        ),
      );
      if (mounted) {
        setState(() {
          wallets = (data['items'] as List)
              .map(jsonObject)
              .where(
                (w) => w['scope'] == jsonObject(widget.order['data'])['scope'],
              )
              .toList();
          walletId =
              widget.payment?['wallet_id'] as String? ??
              wallets.firstOrNull?['id'] as String?;
          date.text =
              widget.payment?['business_date'] as String? ??
              data['businessDate'] as String;
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

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.payment == null ? 'POST' : 'PUT',
        [
          ...GoodsRepository(
            widget.api,
            widget.companyId,
          ).path(widget.order['id'] as String, 'payments'),
          if (widget.payment != null) widget.payment!['id'] as String,
        ],
        {
          'walletId': walletId,
          if (widget.payment != null) 'version': widget.payment!['version'],
          'reason': reason.text,
          'amount': parseMoney(amount.text),
          'businessDate': date.text,
        },
      );
      await pending!.execute(widget.api);
      pending = null;
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
  Widget build(BuildContext context) {
    final enabled = !busy && pending == null;
    return PopScope(
      canPop: pending == null,
      child: AlertDialog(
        title: Text(
          widget.payment == null
              ? 'Оплата товарной продажи'
              : 'Исправление оплаты товара',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: walletId,
                  items: wallets
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text(w['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (v) => setState(() => walletId = v)
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Счёт зачисления',
                  ),
                ),
                if (wallets.isEmpty && !busy)
                  const Text(
                    'Создайте денежный счёт с таким же видом учёта в разделе «Касса».',
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Сумма оплаты, KZT',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: date,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Дата оплаты YYYY-MM-DD',
                  ),
                ),
                if (widget.payment != null) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Причина исправления оплаты',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Платёж до даты продажи учитывается как аванс и зачитывается на дату продажи.',
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: enabled ? () => Navigator.pop(context) : null,
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: busy || walletId == null ? null : save,
            child: Text(
              pending == null
                  ? (widget.payment == null
                        ? 'Зачислить оплату'
                        : 'Сохранить оплату товара')
                  : 'Повторить оплату',
            ),
          ),
        ],
      ),
    );
  }
}
