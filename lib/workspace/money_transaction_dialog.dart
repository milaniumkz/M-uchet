import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';
import 'company_access.dart';

String moneyInput(num value) {
  final amount = value.toInt().abs();
  return '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
}

class MoneyTransactionDialog extends StatefulWidget {
  const MoneyTransactionDialog({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.wallets,
    required this.projects,
    required this.today,
    this.entry,
    this.projectId,
  });
  final BackendClient api;
  final String companyId, currency, today;
  final List<Map<String, dynamic>> wallets, projects;
  final Map<String, dynamic>? entry;
  final String? projectId;
  @override
  State<MoneyTransactionDialog> createState() => _MoneyTransactionDialogState();
}

class _MoneyTransactionDialogState extends State<MoneyTransactionDialog> {
  final amount = TextEditingController(),
      description = TextEditingController(),
      date = TextEditingController();
  late String walletId;
  String type = 'INCOME';
  String? projectId, error;
  bool busy = false;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    walletId =
        widget.entry?['wallet_id'] as String? ??
        widget.wallets.first['id'] as String;
    projectId = widget.entry == null
        ? widget.projectId
        : widget.entry!['project_id'] as String?;
    date.text = widget.entry?['business_date'] as String? ?? widget.today;
    if (widget.entry != null) {
      amount.text = moneyInput(widget.entry!['amount'] as num);
      description.text = widget.entry!['description'] as String? ?? '';
      type = widget.entry!['kind'] as String;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (pending == null) {
        final minor = parseMoney(amount.text),
            parsed = DateTime.tryParse(date.text);
        if (minor <= 0) {
          throw const FormatException('Сумма должна быть больше нуля.');
        }
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date.text) ||
            parsed == null ||
            parsed.toIso8601String().substring(0, 10) != date.text) {
          throw const FormatException('Введите корректную дату YYYY-MM-DD.');
        }
        pending = RetriableCommand(
          widget.entry == null ? 'POST' : 'PUT',
          [
            'v1',
            'companies',
            widget.companyId,
            'wallets',
            walletId,
            if (widget.entry == null)
              'transactions'
            else ...[
              'entries',
              widget.entry!['id'] as String,
            ],
          ],
          {
            'type': type,
            'amount': minor,
            'description': description.text.trim(),
            'businessDate': date.text,
            'projectId': projectId,
          },
        );
      }
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
    canPop: !busy && pending == null,
    child: AlertDialog(
      title: const Text('Денежная операция'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Счёт'),
                items: widget.wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w['id'] as String,
                        child: Text(w['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: busy || pending != null || widget.entry != null
                    ? null
                    : (v) => setState(() => walletId = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Вид операции'),
                items: const [
                  DropdownMenuItem(value: 'INCOME', child: Text('Доход')),
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Расход')),
                  DropdownMenuItem(
                    value: 'CAPITAL',
                    child: Text('Вклад собственника'),
                  ),
                ],
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: projectId ?? 'unassigned',
                decoration: const InputDecoration(labelText: 'Проект'),
                items: [
                  const DropdownMenuItem(
                    value: 'unassigned',
                    child: Text('Общие операции фирмы'),
                  ),
                  ...widget.projects.map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  ),
                  if (projectId != null &&
                      !widget.projects.any((p) => p['id'] == projectId))
                    DropdownMenuItem(
                      value: projectId,
                      child: const Text('Текущий проект'),
                    ),
                ],
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(
                        () => projectId = v == 'unassigned' ? null : v,
                      ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                enabled: !busy && pending == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Сумма, ${widget.currency}',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: description,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Основание операции',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: date,
                enabled: !busy && pending == null,
                decoration: const InputDecoration(
                  labelText: 'Дата операции YYYY-MM-DD',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (pending != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Результат запроса не подтверждён. Повторите сохранение: используются исходные данные и тот же ключ, повторной проводки не будет.',
                  ),
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
          onPressed: busy || !hasCompanyPermission(context, 'wallets.transact')
              ? null
              : save,
          child: Text(pending == null ? 'Сохранить' : 'Повторить сохранение'),
        ),
      ],
    ),
  );
}

class CreateWalletDialog extends StatefulWidget {
  const CreateWalletDialog({
    super.key,
    required this.api,
    required this.companyId,
  });
  final BackendClient api;
  final String companyId;
  @override
  State<CreateWalletDialog> createState() => _CreateWalletDialogState();
}

class _CreateWalletDialogState extends State<CreateWalletDialog> {
  final name = TextEditingController();
  bool busy = false;
  String? error;
  RetriableCommand? pending;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (pending == null && name.text.trim().isEmpty) {
      setState(() => error = 'Укажите название счёта.');
      return;
    }
    setState(() => busy = true);
    try {
      pending ??= RetriableCommand(
        'POST',
        ['v1', 'companies', widget.companyId, 'wallets'],
        {'name': name.text.trim(), 'scope': 'ACCOUNTING'},
      );
      await pending!.execute(widget.api);
      pending = null;
      if (mounted) {
        Navigator.pop(context, true);
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
    canPop: !busy && pending == null,
    child: AlertDialog(
      title: const Text('Добавьте денежный счёт'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              enabled: !busy && pending == null,
              decoration: const InputDecoration(labelText: 'Название счёта'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (pending != null)
              const Text('Повтор использует тот же ключ операции.'),
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
          onPressed: busy || !hasCompanyPermission(context, 'wallets.write')
              ? null
              : save,
          child: Text(pending == null ? 'Создать' : 'Повторить создание'),
        ),
      ],
    ),
  );
}
