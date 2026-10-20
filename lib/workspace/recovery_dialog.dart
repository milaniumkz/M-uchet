import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';

class RecoveryDialog extends StatefulWidget {
  const RecoveryDialog({super.key, required this.api});
  final BackendClient api;
  @override
  State<RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<RecoveryDialog> {
  final token = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, success = false, uncertain = false;
  String? error;
  @override
  void dispose() {
    token.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> reset() async {
    if (password.text != confirmation.text) {
      setState(() => error = 'Пароли не совпадают.');
      return;
    }
    if (password.text.length < 12 || password.text.length > 256) {
      setState(() => error = 'Пароль должен содержать от 12 до 256 символов.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        'POST',
        ['v1', 'auth', 'reset-password'],
        authenticated: false,
        body: {'token': token.text.trim(), 'password': password.text},
      );
      if (mounted) {
        setState(() {
          success = true;
          uncertain = false;
        });
        token.clear();
        password.clear();
        confirmation.clear();
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          uncertain = e.code == 'network_error' || (e.status ?? 0) >= 500;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Восстановить доступ'),
    content: SizedBox(
      width: 484,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (success)
              const Text(
                'Пароль изменён. Все прежние сеансы завершены. Войдите с новым паролем.',
              )
            else ...[
              const Text(
                'Получите одноразовый код у администратора вашего сервера. Код действует 15 минут. Автоматическая отправка по почте пока не подключена.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: token,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Код восстановления',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmation,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Повторите новый пароль',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (uncertain)
                const Text(
                  'Результат запроса не подтверждён. Попробуйте войти с новым паролем. Если он не принят, повторите восстановление.',
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Вернуться ко входу'),
      ),
      if (!success)
        FilledButton(
          onPressed: busy ? null : reset,
          child: Text(busy ? 'Сохраняем…' : 'Изменить пароль'),
        ),
    ],
  );
}
