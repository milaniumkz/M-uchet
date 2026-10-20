import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';

class MoneyEntriesDialog extends StatefulWidget {
  const MoneyEntriesDialog(
      {super.key,
      required this.api,
      required this.companyId,
      required this.currency,
      this.projectId,
      required this.onEdit});
  final BackendClient api;
  final String companyId, currency;
  final String? projectId;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  @override
  State<MoneyEntriesDialog> createState() => _MoneyEntriesDialogState();
}

class _MoneyEntriesDialogState extends State<MoneyEntriesDialog> {
  List<Map<String, dynamic>> wallets = [], entries = [];
  String? walletId, error, cursor;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() => loading = true);
    try {
      if (walletId == null) {
        final result = jsonObject(await widget.api
            .request('GET', ['v1', 'companies', widget.companyId, 'wallets']));
        wallets = (result['items'] as List).map(jsonObject).toList();
        walletId = wallets.isEmpty ? null : wallets.first['id'] as String;
      }
      if (walletId != null) {
        final result = jsonObject(await widget.api.request('GET', [
          'v1',
          'companies',
          widget.companyId,
          'wallets',
          walletId!,
          'entries'
        ], query: {
          'limit': '50',
          if (more && cursor != null) 'after': cursor!,
          if (widget.projectId != null) 'projectId': widget.projectId!
        }));
        final next = (result['items'] as List).map(jsonObject).toList();
        if (!mounted) return;
        setState(() {
          entries = more ? [...entries, ...next] : next;
          cursor = result['nextCursor'] as String?;
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Денежные операции',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold))),
                      IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: 16),
                    if (wallets.isNotEmpty)
                      DropdownButton<String>(
                          value: walletId,
                          isExpanded: true,
                          items: wallets
                              .map((w) => DropdownMenuItem(
                                  value: w['id'] as String,
                                  child: Text(w['name'] as String)))
                              .toList(),
                          onChanged: loading
                              ? null
                              : (v) {
                                  setState(() => walletId = v);
                                  load();
                                }),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    if (!loading && entries.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'Операций по выбранному счёту и проекту пока нет.')),
                    Flexible(
                        child: ListView(shrinkWrap: true, children: [
                      ...entries.map((e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e['description'] as String? ??
                              switch (e['kind']) {
                                'TRANSFER_IN' => 'Перевод на счёт',
                                'TRANSFER_OUT' => 'Перевод со счёта',
                                'DEBT_PAYMENT' => 'Погашение задолженности',
                                _ => 'Корректировка остатка'
                              }),
                          subtitle: Text((e['business_date'] ?? e['created_at'])
                              .toString()
                              .substring(0, 10)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                '${((e['amount'] as num) / 100).toStringAsFixed(2)} ${widget.currency}'),
                            if (e['journal_id'] != null &&
                                ['INCOME', 'EXPENSE', 'CAPITAL']
                                    .contains(e['kind']))
                              IconButton(
                                  tooltip: 'Редактировать операцию',
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          await widget.onEdit(e);
                                          if (mounted) await load();
                                        },
                                  icon: const Icon(Icons.edit_outlined))
                          ]))),
                      if (cursor != null)
                        TextButton(
                            onPressed: loading ? null : () => load(more: true),
                            child: const Text('Показать ещё'))
                    ])),
                    TextButton.icon(
                        onPressed: loading ? null : () => load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Обновить'))
                  ]))));
}
