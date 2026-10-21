import 'debts_workspace.dart';
import '../backend/rest/repositories.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'company_access.dart';
import 'money_transaction_dialog.dart';
import 'journal_editor.dart';
import 'goods_workspace.dart';
import 'payroll_workspace.dart';

const cashKinds = {
  'INCOME': 'Поступление',
  'EXPENSE': 'Расход',
  'CAPITAL': 'Вклад собственника',
  'TRANSFER_IN': 'Перевод: поступление',
  'TRANSFER_OUT': 'Перевод: списание',
  'BALANCE_EDIT': 'Корректировка остатка',
  'DOCUMENT_REFUND': 'Возврат денег по документу',
  'DOCUMENT_PAYMENT': 'Оплата документа',
  'MANUAL': 'Бухгалтерская запись',
  'JOURNAL_REVERSAL': 'Сторно записи',
  'PAYMENT_VOID': 'Отмена записи оплаты',
  'PAYMENT_RESTORE': 'Восстановление записи оплаты',
  'DEBT_PAYMENT': 'Погашение задолженности',
  'PAYROLL_PAYMENT': 'Выплата зарплаты',
  'PAYROLL_PAYMENT_VOID': 'Отмена записи выплаты зарплаты',
  'PAYROLL_PAYMENT_RESTORE': 'Восстановление записи выплаты зарплаты',
  'ORDER_PAYMENT': 'Оплата товаров',
  'ORDER_PAYMENT_VOID': 'Отмена записи оплаты товаров',
  'ORDER_PAYMENT_RESTORE': 'Восстановление записи оплаты товаров',
};
Future<void> showWalletTransfer(
  BuildContext context, {
  required BackendClient api,
  required String companyId,
  required String currency,
  String? transferId,
  String? sourceWalletId,
}) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WalletTransferDialog(
      api: api,
      companyId: companyId,
      currency: currency,
      transferId: transferId,
      sourceWalletId: sourceWalletId,
    ),
  );
}

class CashWorkspace extends StatefulWidget {
  const CashWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.onChanged,
    required this.onTransaction,
  });
  final BackendClient api;
  final String companyId, currency;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  final Future<void> Function(Map<String, dynamic>?) onTransaction;
  @override
  State<CashWorkspace> createState() => _CashWorkspaceState();
}

class _CashWorkspaceState extends State<CashWorkspace> {
  List<Map<String, dynamic>> wallets = [], entries = [], shifts = [];
  Map<String, dynamic>? openShift;
  String? walletId, error, entryCursor, shiftCursor, userId;
  String today = '';
  bool busy = false;
  RetriableCommand? pending;
  List<String> path(List<String> rest) => [
    'v1',
    'companies',
    widget.companyId,
    ...rest,
  ];
  Map<String, dynamic>? get selected =>
      wallets.where((w) => w['id'] == walletId).firstOrNull;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool moreEntries = false, bool moreShifts = false}) async {
    setState(() => busy = true);
    try {
      final w = jsonObject(
        await loadCompanyWallets(widget.api, widget.companyId),
      );
      if (!mounted) {
        return;
      }
      final all = (w['items'] as List).map(jsonObject).toList();
      walletId = all.any((w) => w['id'] == walletId)
          ? walletId
          : all.firstOrNull?['id'] as String?;
      today =
          w['businessDate'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10);
      final identity = jsonObject(
        await widget.api.request('GET', ['v1', 'auth', 'me']),
      );
      Map<String, dynamic> e = {'items': []},
          s = {'items': []},
          opened = {'items': []};
      if (walletId != null) {
        e = jsonObject(
          await widget.api.request(
            'GET',
            path(['wallets', walletId!, 'entries']),
            query: {
              'limit': '50',
              if (moreEntries && entryCursor != null) 'after': entryCursor!,
            },
          ),
        );
        if (!mounted) {
          return;
        }
        if (hasCompanyPermission(context, 'shifts.read')) {
          s = jsonObject(
            await widget.api.request(
              'GET',
              path(['shifts']),
              query: {
                'walletId': walletId!,
                'limit': '50',
                if (moreShifts && shiftCursor != null) 'after': shiftCursor!,
              },
            ),
          );
          opened = jsonObject(
            await widget.api.request(
              'GET',
              path(['shifts']),
              query: {'walletId': walletId!, 'status': 'OPEN'},
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          wallets = all;
          userId = identity['id'] as String;
          final nextEntries = (e['items'] as List).map(jsonObject).toList(),
              nextShifts = (s['items'] as List).map(jsonObject).toList();
          entries = moreEntries ? [...entries, ...nextEntries] : nextEntries;
          shifts = moreShifts ? [...shifts, ...nextShifts] : nextShifts;
          entryCursor = e['nextCursor'] as String?;
          shiftCursor = s['nextCursor'] as String?;
          openShift = (opened['items'] as List).map(jsonObject).firstOrNull;
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

  Future<void> changed() async {
    await widget.onChanged();
    if (mounted) {
      await load();
    }
  }

  Future<void> createWallet() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CreateWalletDialog(api: widget.api, companyId: widget.companyId),
    );
    if (result == true && mounted) {
      await load();
    }
  }

  Future<void> editWallet(Map<String, dynamic> wallet) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WalletCorrectionDialog(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        wallet: wallet,
        today: today,
      ),
    );
    if (result == true && mounted) {
      await changed();
    }
  }

  Future<void> transaction([Map<String, dynamic>? entry]) async {
    await widget.onTransaction(entry);
    if (mounted) {
      await load();
    }
  }

  Future<void> transfer([String? id]) async {
    await showWalletTransfer(
      context,
      api: widget.api,
      companyId: widget.companyId,
      currency: widget.currency,
      transferId: id,
      sourceWalletId: walletId,
    );
    if (mounted) {
      await changed();
    }
  }

  Future<void> open() async {
    pending ??= RetriableCommand('POST', path(['shifts']), {
      'walletId': walletId,
    });
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

  bool mayCorrect(Map<String, dynamic> shift) =>
      hasCompanyPermission(context, 'shifts.write') &&
      (shift['user_id'] == userId ||
          context
                  .dependOnInheritedWidgetOfExactType<CompanyAccess>()
                  ?.company
                  ?.role ==
              'owner' ||
          context.dependOnInheritedWidgetOfExactType<CompanyAccess>() == null);
  Future<void> close(
    Map<String, dynamic> shift, {
    bool correction = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftCountDialog(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        shift: shift,
        correction: correction,
      ),
    );
    if (result == true && mounted) {
      await load();
    }
  }

  Future<void> history(Map<String, dynamic> shift) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ShiftHistoryDialog(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        shiftId: shift['id'] as String,
      ),
    );
  }

  Future<void> journal(Map<String, dynamic> entry) async {
    try {
      final data = jsonObject(
        await widget.api.request(
          'GET',
          path(['accounting', 'journal', entry['journal_id'] as String]),
        ),
      );
      if (!mounted) {
        return;
      }
      if (data['sourceDebtId'] != null &&
          hasCompanyPermission(context, 'debts.read')) {
        await showOpeningDebt(
          context,
          api: widget.api,
          companyId: widget.companyId,
          debtId: data['sourceDebtId'] as String,
          currency: widget.currency,
          projects: widget.projects,
          onChanged: widget.onChanged,
        );
      } else if (data['sourcePayrollId'] != null &&
          hasCompanyPermission(context, 'payroll.read')) {
        await showPayrollRecord(
          context,
          api: widget.api,
          companyId: widget.companyId,
          payrollId: data['sourcePayrollId'] as String,
          currency: widget.currency,
          projects: widget.projects,
          onChanged: widget.onChanged,
        );
      } else if (data['sourceOrderId'] != null &&
          hasCompanyPermission(context, 'orders.read')) {
        await showGoodsOrder(
          context,
          api: widget.api,
          companyId: widget.companyId,
          orderId: data['sourceOrderId'] as String,
          currency: widget.currency,
          projects: widget.projects,
          onChanged: widget.onChanged,
        );
      } else {
        await showDialog<bool>(
          context: context,
          builder: (_) => JournalEditor(
            api: widget.api,
            companyId: widget.companyId,
            projects: widget.projects,
            entry: data,
          ),
        );
      }
      if (mounted) {
        await changed();
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  Widget shiftCard(Map<String, dynamic> s) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s['status'] == 'OPEN' ? 'Смена открыта' : 'Смена закрыта',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text('Открыта: ${s['opened_at']} · ${s['opened_by_name']}'),
          Text(
            'На открытии: ${moneyText(s['opening'] as num, widget.currency)}',
          ),
          if (s['status'] == 'CLOSED') ...[
            Text(
              'Фактически при закрытии: ${moneyText(s['closing'] as num, widget.currency)}',
            ),
            Text(
              s['expected_balance'] == null
                  ? 'Учётный остаток при закрытии не сохранён для этой старой записи.'
                  : 'По учёту при закрытии: ${moneyText(s['expected_balance'] as num, widget.currency)}',
            ),
            if (s['difference'] != null)
              Text(
                'Разница: ${moneyText(s['difference'] as num, widget.currency)}',
              ),
          ],
          Wrap(
            spacing: 12,
            children: [
              if (s['status'] == 'OPEN')
                FilledButton(
                  onPressed: busy || pending != null || !mayCorrect(s)
                      ? null
                      : () => close(s),
                  child: const Text('Закрыть смену'),
                ),
              if (s['status'] == 'CLOSED')
                TextButton(
                  onPressed: busy || pending != null || !mayCorrect(s)
                      ? null
                      : () => close(s, correction: true),
                  child: const Text('Исправить пересчёт'),
                ),
              TextButton(
                onPressed: busy ? null : () => history(s),
                child: const Text('История смены'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const Text(
        'Касса и денежные счета',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Счета общие для фирмы. Доходы и расходы относятся к выбранному проекту. Внутренние кассовые смены сохраняют фактический пересчёт; фискализация ККМ пока не подключена.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          ...wallets.map(
            (w) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      moneyText(w['balance'] as num, widget.currency),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          busy ||
                              pending != null ||
                              !hasCompanyPermission(context, 'wallets.write')
                          ? null
                          : () => editWallet(w),
                      child: const Text('Изменить счёт'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed:
                busy ||
                    pending != null ||
                    !hasCompanyPermission(context, 'wallets.write')
                ? null
                : createWallet,
            icon: const Icon(Icons.add),
            label: const Text('Добавить счёт'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed:
                busy ||
                    pending != null ||
                    !hasCompanyPermission(context, 'wallets.transact')
                ? null
                : () => transaction(),
            icon: const Icon(Icons.add),
            label: const Text('Поступление / расход'),
          ),
          OutlinedButton(
            onPressed:
                busy ||
                    pending != null ||
                    wallets.length < 2 ||
                    !hasCompanyPermission(context, 'wallets.transact')
                ? null
                : () => transfer(),
            child: const Text('Перевести между счетами'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (pending != null)
        TextButton(
          onPressed: busy ? null : open,
          child: const Text('Повторить открытие смены'),
        ),
      if (wallets.isNotEmpty)
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: walletId,
          decoration: const InputDecoration(
            labelText: 'Счёт для операций и смен',
          ),
          items: wallets
              .map(
                (w) => DropdownMenuItem(
                  value: w['id'] as String,
                  child: Text(w['name'] as String),
                ),
              )
              .toList(),
          onChanged: busy || pending != null
              ? null
              : (id) {
                  setState(() => walletId = id);
                  load();
                },
        ),
      if (hasCompanyPermission(context, 'shifts.read')) ...[
        const SizedBox(height: 24),
        const Text(
          'Кассовые смены',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (openShift != null)
          shiftCard(openShift!)
        else
          FilledButton(
            onPressed:
                busy ||
                    pending != null ||
                    walletId == null ||
                    !hasCompanyPermission(context, 'shifts.write')
                ? null
                : open,
            child: const Text('Открыть смену'),
          ),
        ...shifts.where((s) => s['status'] == 'CLOSED').map(shiftCard),
        if (shiftCursor != null)
          TextButton(
            onPressed: busy ? null : () => load(moreShifts: true),
            child: const Text('Загрузить смены ещё'),
          ),
      ],
      const SizedBox(height: 24),
      const Text(
        'Движения по счёту',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      ...entries.map(
        (e) => Card(
          child: ListTile(
            title: Text(
              e['description'] as String? ?? cashKinds[e['kind']] ?? 'Операция',
            ),
            subtitle: Text(
              '${cashKinds[e['kind']] ?? e['kind']} · ${(e['business_date'] ?? e['created_at']).toString().substring(0, 10)}',
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(moneyText(e['amount'] as num, widget.currency)),
                if (['INCOME', 'EXPENSE', 'CAPITAL'].contains(e['kind']))
                  IconButton(
                    tooltip: 'Изменить денежную операцию',
                    onPressed:
                        busy ||
                            !hasCompanyPermission(context, 'wallets.transact')
                        ? null
                        : () => transaction(e),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (['TRANSFER_IN', 'TRANSFER_OUT'].contains(e['kind']))
                  IconButton(
                    tooltip: 'Открыть перевод',
                    onPressed: busy
                        ? null
                        : () => transfer(e['reference_id'] as String),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                if (e['journal_id'] != null &&
                    hasCompanyPermission(context, 'accounting.read'))
                  IconButton(
                    tooltip: 'Открыть проводку',
                    onPressed: busy ? null : () => journal(e),
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
              ],
            ),
          ),
        ),
      ),
      if (entries.isEmpty && !busy) const Text('Движений пока нет.'),
      if (entryCursor != null)
        TextButton(
          onPressed: busy ? null : () => load(moreEntries: true),
          child: const Text('Загрузить движения ещё'),
        ),
      TextButton.icon(
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ],
  );
}

class WalletCorrectionDialog extends StatefulWidget {
  const WalletCorrectionDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.wallet,
    required this.today,
  });
  final BackendClient api;
  final String companyId, currency, today;
  final Map<String, dynamic> wallet;
  @override
  State<WalletCorrectionDialog> createState() => _WalletCorrectionDialogState();
}

class _WalletCorrectionDialogState extends State<WalletCorrectionDialog> {
  late final name = TextEditingController(
        text: widget.wallet['name'] as String,
      ),
      amount = TextEditingController(
        text: moneyInput(widget.wallet['balance'] as num),
      ),
      date = TextEditingController(text: widget.today);
  final reason = TextEditingController();
  bool correction = false, busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    date.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'wallets',
          widget.wallet['id'] as String,
        ],
        {
          'name': name.text,
          if (correction) ...{
            'balance': parseMoney(amount.text),
            'businessDate': date.text,
            'reason': reason.text,
          },
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
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null,
    child: AlertDialog(
      title: const Text('Изменить денежный счёт'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(labelText: 'Название счёта'),
              ),
              const SizedBox(height: 16),
              Text(
                'Текущий остаток: ${moneyText(widget.wallet['balance'] as num, widget.currency)}',
              ),
              if (hasCompanyPermission(context, 'wallets.transact'))
                CheckboxListTile(
                  value: correction,
                  title: const Text(
                    'Скорректировать остаток отдельной проводкой',
                  ),
                  onChanged: busy || pending != null
                      ? null
                      : (v) => setState(() => correction = v!),
                ),
              if (correction) ...[
                TextField(
                  controller: amount,
                  enabled: !busy && pending == null,
                  decoration: InputDecoration(
                    labelText:
                        'Текущий остаток после исправления, ${widget.currency}',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: date,
                  enabled: !busy && pending == null,
                  decoration: const InputDecoration(
                    labelText: 'Дата проводки YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reason,
                  enabled: !busy && pending == null,
                  decoration: const InputDecoration(
                    labelText: 'Причина корректировки',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Проводка изменяет текущий учётный остаток, сохраняет историю и не признаёт доход от продажи.',
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
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
          child: Text(
            pending == null ? 'Сохранить счёт' : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}

class WalletTransferDialog extends StatefulWidget {
  const WalletTransferDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    this.transferId,
    this.sourceWalletId,
  });
  final BackendClient api;
  final String companyId, currency;
  final String? transferId, sourceWalletId;
  @override
  State<WalletTransferDialog> createState() => _WalletTransferDialogState();
}

class _WalletTransferDialogState extends State<WalletTransferDialog> {
  final amount = TextEditingController(),
      date = TextEditingController(),
      description = TextEditingController(
        text: 'Перевод между денежными счетами',
      ),
      reason = TextEditingController();
  List<Map<String, dynamic>> wallets = [], history = [];
  String? source, target, error;
  bool busy = false;
  RetriableCommand? pending;
  int? revision;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final w = jsonObject(
        await loadCompanyWallets(widget.api, widget.companyId),
      );
      var data = <String, dynamic>{}, h = <Map<String, dynamic>>[];
      if (widget.transferId != null) {
        data = jsonObject(
          await widget.api.request('GET', [
            'v1',
            'companies',
            widget.companyId,
            'wallet-transfers',
            widget.transferId!,
          ]),
        );
        final res = jsonObject(
          await widget.api.request('GET', [
            'v1',
            'companies',
            widget.companyId,
            'wallet-transfers',
            widget.transferId!,
            'history',
          ]),
        );
        h = (res['items'] as List).map(jsonObject).toList();
      }
      if (mounted) {
        setState(() {
          wallets = (w['items'] as List).map(jsonObject).toList();
          source =
              data['sourceWalletId'] as String? ??
              widget.sourceWalletId ??
              wallets.firstOrNull?['id'] as String?;
          target =
              data['targetWalletId'] as String? ??
              wallets.where((w) => w['id'] != source).firstOrNull?['id']
                  as String?;
          date.text =
              data['businessDate'] as String? ??
              w['businessDate'] as String? ??
              DateTime.now().toIso8601String().substring(0, 10);
          if (data['amount'] != null) {
            amount.text = moneyInput(data['amount'] as num);
          }
          if (data['description'] != null) {
            description.text = data['description'] as String;
          }
          revision = data['revision'] as int?;
          history = h;
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

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    description.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (source == target) {
        throw const FormatException('Выберите разные счета.');
      }
      pending ??= RetriableCommand(
        widget.transferId == null ? 'POST' : 'PUT',
        [
          'v1',
          'companies',
          widget.companyId,
          'wallet-transfers',
          if (widget.transferId != null) widget.transferId!,
        ],
        {
          'sourceWalletId': source,
          'targetWalletId': target,
          'amount': parseMoney(amount.text),
          'businessDate': date.text,
          'description': description.text,
          if (widget.transferId != null) ...{
            'expectedRevision': revision,
            'reason': reason.text.trim().isEmpty
                ? 'Исправление перевода'
                : reason.text.trim(),
          },
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

  Widget select(String label, String? value, void Function(String?) action) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: wallets
            .map(
              (w) => DropdownMenuItem(
                value: w['id'] as String,
                child: Text(w['name'] as String),
              ),
            )
            .toList(),
        onChanged:
            busy ||
                pending != null ||
                !hasCompanyPermission(context, 'wallets.transact')
            ? null
            : action,
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null,
    child: AlertDialog(
      title: Text(
        widget.transferId == null
            ? 'Перевести между счетами'
            : 'Перевод между счетами',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) const LinearProgressIndicator(),
              select('Со счёта', source, (v) => setState(() => source = v)),
              const SizedBox(height: 14),
              select('На счёт', target, (v) => setState(() => target = v)),
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                enabled:
                    !busy &&
                    pending == null &&
                    hasCompanyPermission(context, 'wallets.transact'),
                decoration: InputDecoration(
                  labelText: 'Сумма перевода, ${widget.currency}',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: date,
                enabled:
                    !busy &&
                    pending == null &&
                    hasCompanyPermission(context, 'wallets.transact'),
                decoration: const InputDecoration(
                  labelText: 'Дата перевода YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: description,
                enabled:
                    !busy &&
                    pending == null &&
                    hasCompanyPermission(context, 'wallets.transact'),
                decoration: const InputDecoration(
                  labelText: 'Назначение перевода',
                ),
              ),
              if (widget.transferId != null) ...[
                TextField(
                  controller: reason,
                  enabled:
                      !busy &&
                      pending == null &&
                      hasCompanyPermission(context, 'wallets.transact'),
                  decoration: const InputDecoration(
                    labelText: 'Причина исправления',
                  ),
                ),
                const SizedBox(height: 18),
                Text('История изменений: ${history.length}'),
                ...history.map(
                  (h) => Text(
                    '${h['changed_at']} · ${h['actor_name']} · было ${jsonObject(h['snapshot'])['amount'] is num ? moneyText(jsonObject(h['snapshot'])['amount'] as num, widget.currency) : 'сложная проводка'}',
                  ),
                ),
              ],
              if (wallets.length < 2 && !busy)
                const Text('Добавьте хотя бы два денежных счёта.'),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (pending != null)
                const Text(
                  'При неизвестном результате повторите запрос с теми же данными.',
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
          child: const Text('Закрыть'),
        ),
        FilledButton(
          onPressed:
              busy ||
                  wallets.length < 2 ||
                  !hasCompanyPermission(context, 'wallets.transact')
              ? null
              : save,
          child: Text(
            pending == null
                ? widget.transferId == null
                      ? 'Перевести'
                      : 'Сохранить перевод'
                : 'Повторить запрос',
          ),
        ),
      ],
    ),
  );
}

class ShiftCountDialog extends StatefulWidget {
  const ShiftCountDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.shift,
    this.correction = false,
  });
  final BackendClient api;
  final String companyId, currency;
  final Map<String, dynamic> shift;
  final bool correction;
  @override
  State<ShiftCountDialog> createState() => _ShiftCountDialogState();
}

class _ShiftCountDialogState extends State<ShiftCountDialog> {
  late final amount = TextEditingController(
    text: widget.correction ? moneyInput(widget.shift['closing'] as num) : '',
  );
  final reason = TextEditingController();
  bool busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        widget.correction ? 'PUT' : 'POST',
        [
          'v1',
          'companies',
          widget.companyId,
          'shifts',
          widget.shift['id'] as String,
          if (!widget.correction) 'close',
        ],
        {
          'countedAmount': parseMoney(amount.text),
          if (widget.correction) 'reason': reason.text,
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
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null,
    child: AlertDialog(
      title: Text(
        widget.correction
            ? 'Исправить фактический пересчёт'
            : 'Закрыть кассовую смену',
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              enabled: !busy && pending == null,
              decoration: InputDecoration(
                labelText: 'Фактически в кассе, ${widget.currency}',
              ),
            ),
            if (widget.correction)
              TextField(
                controller: reason,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Причина исправления',
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Пересчёт сохраняется отдельно от денежных проводок. Учётный остаток при первоначальном закрытии остаётся в истории.',
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
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
          child: Text(
            pending == null
                ? widget.correction
                      ? 'Сохранить пересчёт'
                      : 'Закрыть смену'
                : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}

class ShiftHistoryDialog extends StatefulWidget {
  const ShiftHistoryDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.shiftId,
  });
  final BackendClient api;
  final String companyId, currency, shiftId;
  @override
  State<ShiftHistoryDialog> createState() => _ShiftHistoryDialogState();
}

class _ShiftHistoryDialogState extends State<ShiftHistoryDialog> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = jsonObject(
        await widget.api.request('GET', [
          'v1',
          'companies',
          widget.companyId,
          'shifts',
          widget.shiftId,
          'history',
        ]),
      );
      if (mounted) {
        setState(
          () => items = (data['items'] as List).map(jsonObject).toList(),
        );
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('История пересчёта'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!loading && items.isEmpty && error == null)
              const Text('Исправлений пересчёта пока нет.'),
            ...items.map((h) {
              final old = jsonObject(h['snapshot']);
              return ListTile(
                title: Text('${h['changed_at']} · ${h['actor_name']}'),
                subtitle: Text(
                  'Было: ${old['closing'] == null ? 'не указано' : moneyText(old['closing'] as num, widget.currency)}\n${old['correctionReason'] ?? ''}',
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
        child: const Text('Закрыть'),
      ),
    ],
  );
}
