import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key, required this.api});
  final BackendClient api;
  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final oldPassword = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  Map<String, dynamic>? identity;
  String? error;
  bool loading = true, busy = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = jsonObject(
        await widget.api.request('GET', ['v1', 'auth', 'me']),
      );
      if (mounted) {
        setState(() => identity = result);
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
  void dispose() {
    oldPassword.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> change() async {
    if (password.text.length < 12 || password.text.length > 256) {
      setState(
        () => error = 'Новый пароль должен содержать от 12 до 256 символов.',
      );
      return;
    }
    if (password.text != confirmation.text) {
      setState(() => error = 'Новые пароли не совпадают.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        'POST',
        ['v1', 'auth', 'password'],
        body: {'oldPassword': oldPassword.text, 'password': password.text},
      );
      if (mounted) {
        Navigator.pop(context, 'changed');
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          uncertain = e.status == null || e.status! >= 500;
          error = uncertain
              ? 'Не удалось подтвердить результат. Вернитесь ко входу и попробуйте новый пароль. Если он не принят, используйте прежний.'
              : e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !uncertain,
    child: AlertDialog(
      title: const Text('Мой аккаунт'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading || busy) const LinearProgressIndicator(),
              if (identity != null) ...[
                Text(
                  identity!['name'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SelectableText(identity!['login'] as String),
              ],
              const SizedBox(height: 20),
              const Text(
                'Смена пароля завершит все сеансы этого аккаунта, включая текущий.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: oldPassword,
                obscureText: true,
                enabled: !busy && !uncertain,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Текущий пароль'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                enabled: !busy && !uncertain,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Новый пароль',
                  helperText: 'От 12 до 256 символов',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: true,
                enabled: !busy && !uncertain,
                decoration: const InputDecoration(
                  labelText: 'Повторите новый пароль',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
        if (uncertain)
          FilledButton(
            onPressed: () => Navigator.pop(context, 'uncertain'),
            child: const Text('Вернуться ко входу'),
          )
        else ...[
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: busy || loading ? null : change,
            child: const Text('Сменить пароль'),
          ),
        ],
      ],
    ),
  );
}
