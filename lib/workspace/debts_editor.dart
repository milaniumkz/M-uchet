import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';
import 'company_access.dart';
import 'commercial_repository.dart';
import 'money_transaction_dialog.dart' show moneyInput;
import 'debts_repository.dart';

class DebtEditor extends StatefulWidget {
  const DebtEditor({
    super.key,
    required this.repo,
    required this.currency,
    required this.projects,
    required this.today,
    this.record,
    this.projectId,
    this.initialType = 'AR',
    this.initialScope = 'ACCOUNTING',
  });
  final DebtsRepository repo;
  final String currency, today, initialType, initialScope;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? record;
  final String? projectId;
  @override
  State<DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<DebtEditor> {
  late final amount = TextEditingController(
        text: widget.record == null
            ? '0.00'
            : moneyInput(widget.record!['total'] as num),
      ),
      date = TextEditingController(
        text: widget.record?['business_date'] as String? ?? widget.today,
      ),
      due = TextEditingController(
        text: widget.record?['due_date'] as String? ?? '',
      ),
      notes = TextEditingController(
        text: (widget.record?['data'] as Map?)?['notes'] as String? ?? '',
      );
  late String type = widget.record?['type'] as String? ?? widget.initialType,
      scope = widget.record?['scope'] as String? ?? widget.initialScope;
  late String? partyId = widget.record?['counterparty_id'] as String?,
      projectId = widget.record?['project_id'] as String? ?? widget.projectId;
  bool busy = false, refreshParty = false, confirm = false;
  String? error;
  List<ResourceDto> parties = [];
  RetriableCommand? pending;
  bool get writable => hasCompanyPermission(context, 'debts.write');
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    due.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final rows = await widget.repo.parties(
        type == 'AR' ? 'clients' : 'suppliers',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        parties = rows;
        if (partyId != null &&
            !rows.any((p) => p.id == partyId) &&
            widget.record?['type'] == type) {
          parties = [
            ...rows,
            ResourceDto(
              partyId!,
              jsonObject(
                jsonObject(widget.record!['data'])['counterparty'] ?? {},
              ),
              0,
            ),
          ];
        }
        if (!parties.any((p) => p.id == partyId)) {
          partyId = parties.firstOrNull?.id;
        }
        error = null;
      });
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

  Widget field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          enabled: writable && !busy && pending == null,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
        ),
      );
  Future<void> save() async {
    try {
      if (pending == null) {
        if (partyId == null) {
          throw const FormatException('Выберите контрагента.');
        }
        final mismatches = widget.record?['sourceMismatches'] as List? ?? [];
        if (mismatches.isNotEmpty && !confirm) {
          throw const FormatException(
            'Подтвердите пересчёт расходящихся старых данных.',
          );
        }
        pending = widget.repo.command(
          widget.record == null ? 'POST' : 'PUT',
          [if (widget.record != null) widget.record!['id'] as String],
          {
            'type': type,
            'counterpartyId': partyId,
            'amount': parseMoney(amount.text),
            'scope': scope,
            'projectId': projectId,
            'businessDate': date.text.trim(),
            'dueDate': due.text.trim().isEmpty ? null : due.text.trim(),
            'notes': notes.text.trim(),
            'refreshCounterparty': refreshParty,
            'confirmRecalculation': confirm,
            if (widget.record != null) 'version': widget.record!['version'],
          },
        );
      }
      setState(() => busy = true);
      final result = await pending!.execute(widget.repo.api);
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: pending == null && !busy,
    child: AlertDialog(
      title: Text(
        widget.record == null ? 'Начальный долг' : 'Изменить начальный долг',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) const LinearProgressIndicator(),
              const Text(
                'Начальный остаток не создаёт доход или расход. Оплаты учитываются отдельно и сохраняются при исправлении.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Вид долга'),
                items: debtTypes.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: busy || pending != null || !writable
                    ? null
                    : (v) {
                        setState(() {
                          type = v!;
                          partyId = null;
                        });
                        load();
                      },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('$type:$partyId'),
                initialValue: partyId,
                decoration: const InputDecoration(labelText: 'Контрагент'),
                items: parties
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.data['name'] as String? ?? p.id,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy || pending != null || !writable
                    ? null
                    : (v) => setState(() => partyId = v),
              ),
              const SizedBox(height: 14),
              field(amount, 'Сумма начального долга, ${widget.currency}'),
              field(date, 'Дата остатка YYYY-MM-DD'),
              field(due, 'Срок оплаты YYYY-MM-DD'),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'Контур'),
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
                onChanged: busy || pending != null || !writable
                    ? null
                    : (v) => setState(() => scope = v!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: projectId ?? 'common',
                decoration: const InputDecoration(labelText: 'Проект'),
                items: [
                  const DropdownMenuItem(
                    value: 'common',
                    child: Text('Общие операции фирмы'),
                  ),
                  for (final p in projectChoices(widget.projects, projectId))
                    DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(
                        p['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy || pending != null || !writable
                    ? null
                    : (v) =>
                          setState(() => projectId = v == 'common' ? null : v),
              ),
              const SizedBox(height: 14),
              field(notes, 'Примечание', lines: 3),
              if (widget.record != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Обновить снимок реквизитов контрагента'),
                  value: refreshParty,
                  onChanged: busy || pending != null || !writable
                      ? null
                      : (v) => setState(() => refreshParty = v!),
                ),
              if ((widget.record?['sourceMismatches'] as List? ?? [])
                  .isNotEmpty) ...[
                const Text(
                  'Старый регистр расходится с журналом. При сохранении введённые данные станут исправлением; история сохранится.',
                ),
                for (final m
                    in (widget.record!['sourceMismatches'] as List).map(
                      jsonObject,
                    ))
                  Text(
                    '${m['kind']}: регистр ${moneyText(m['storedAmount'] as num, widget.currency)}, журнал ${moneyText(m['ledgerAmount'] as num, widget.currency)}',
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Подтверждаю пересчёт по введённым данным'),
                  value: confirm,
                  onChanged: busy || pending != null
                      ? null
                      : (v) => setState(() => confirm = v!),
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
          onPressed: busy || !writable ? null : save,
          child: Text(
            pending == null ? 'Сохранить долг' : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}

class DebtPaymentEditor extends StatefulWidget {
  const DebtPaymentEditor({
    super.key,
    required this.repo,
    required this.currency,
    required this.debt,
    this.payment,
  });
  final DebtsRepository repo;
  final String currency;
  final Map<String, dynamic> debt;
  final Map<String, dynamic>? payment;
  @override
  State<DebtPaymentEditor> createState() => _DebtPaymentEditorState();
}

class _DebtPaymentEditorState extends State<DebtPaymentEditor> {
  late final amount = TextEditingController(
        text: moneyInput(
          (widget.payment?['amount'] ?? widget.debt['remaining']) as num,
        ),
      ),
      date = TextEditingController(
        text:
            widget.payment?['business_date'] as String? ??
            widget.debt['companyBusinessDate'] as String,
      );
  late String direction =
      widget.payment?['direction'] as String? ??
      (widget.debt['type'] == 'AR' ? 'IN' : 'OUT');
  String? walletId, error;
  List<Map<String, dynamic>> wallets = [];
  bool busy = false, advance = false, confirm = false;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await loadCompanyWallets(widget.repo.api, widget.repo.companyId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        wallets = (data['items'] as List)
            .map(jsonObject)
            .where((w) => w['scope'] == widget.debt['scope'])
            .toList();
        final old = widget.payment?['wallet_id'] as String?;
        walletId = wallets.any((w) => w['id'] == old)
            ? old
            : wallets.firstOrNull?['id'] as String?;
      });
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
    try {
      if (pending == null) {
        if (walletId == null) {
          throw const FormatException(
            'Нужен денежный счёт того же контура. Создайте его в разделе «Касса».',
          );
        }
        if ((widget.debt['sourceMismatches'] as List? ?? []).isNotEmpty &&
            !confirm) {
          throw const FormatException(
            'Подтвердите пересчёт расходящихся старых данных.',
          );
        }
        pending = widget.repo.command(
          widget.payment == null ? 'POST' : 'PUT',
          [
            widget.debt['id'] as String,
            if (widget.payment == null) 'settlements' else 'payments',
            if (widget.payment != null) widget.payment!['id'] as String,
          ],
          {
            'walletId': walletId,
            'amount': parseMoney(amount.text),
            'businessDate': date.text.trim(),
            'direction': direction,
            'allowAdvance': advance,
            'confirmRecalculation': confirm,
            'debtVersion': widget.debt['version'],
            if (widget.payment != null) 'version': widget.payment!['version'],
          },
        );
      }
      setState(() => busy = true);
      await pending!.execute(widget.repo.api);
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
    canPop: pending == null && !busy,
    child: AlertDialog(
      title: Text(
        widget.payment == null
            ? 'Оплата начального долга'
            : 'Изменить оплату долга',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (widget.payment?['voided'] == true)
                const Text(
                  'Оплата отменена. Исправленные данные применятся при её восстановлении.',
                ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: direction,
                decoration: const InputDecoration(
                  labelText: 'Направление денег',
                ),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Поступление')),
                  DropdownMenuItem(value: 'OUT', child: Text('Списание')),
                ],
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => direction = v!),
              ),
              const SizedBox(height: 14),
              const Text(
                'Направление отражает фактическое движение денег. Изменение вида долга не меняет его автоматически.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey(walletId),
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Денежный счёт'),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w['id'] as String,
                        child: Text(
                          w['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => walletId = v),
              ),
              TextField(
                controller: amount,
                enabled: !busy && pending == null,
                decoration: InputDecoration(
                  labelText: 'Сумма оплаты, ${widget.currency}',
                ),
              ),
              TextField(
                controller: date,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Дата оплаты YYYY-MM-DD',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Разрешить учёт превышения как аванса'),
                value: advance,
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => advance = v!),
              ),
              if ((widget.debt['sourceMismatches'] as List? ?? [])
                  .isNotEmpty) ...[
                const Text(
                  'Старые суммы регистра расходятся с журналом. Сохранение пересчитает взаиморасчёты по введённым данным.',
                ),
                for (final raw in widget.debt['sourceMismatches'] as List)
                  Builder(
                    builder: (_) {
                      final m = jsonObject(raw);
                      return Text(
                        '${m['kind']}: регистр ${moneyText(m['storedAmount'] as num, widget.currency)}, журнал ${moneyText(m['ledgerAmount'] as num, widget.currency)}',
                      );
                    },
                  ),
                CheckboxListTile(
                  value: confirm,
                  onChanged: busy || pending != null
                      ? null
                      : (v) => setState(() => confirm = v!),
                  title: const Text('Подтверждаю пересчёт по введённым данным'),
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
            pending == null ? 'Сохранить оплату' : 'Повторить сохранение',
          ),
        ),
      ],
    ),
  );
}
