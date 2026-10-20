import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';

class CompanyCreation extends StatefulWidget {
  const CompanyCreation(
      {super.key,
      required this.api,
      required this.onCreated,
      required this.onCancel});
  final BackendClient api;
  final void Function(CompanyDto) onCreated;
  final VoidCallback onCancel;
  @override
  State<CompanyCreation> createState() => _CompanyCreationState();
}

class _CompanyCreationState extends State<CompanyCreation> {
  final name = TextEditingController();
  RetriableCommand? pending;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) {
      return;
    }
    if (pending == null && name.text.trim().isEmpty) {
      setState(() => error = 'Укажите название фирмы.');
      return;
    }
    pending ??= RetriableCommand('POST', ['v1', 'companies'],
        {'name': name.text.trim(), 'currency': 'KZT'});
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final created = CompanyDto.fromJson(await pending!.execute(widget.api));
      if (mounted) {
        widget.onCreated(created);
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
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.business_outlined,
                          size: 42, color: Color(0xFF5654E8)),
                      const SizedBox(height: 24),
                      const Text('Создать фирму',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text(
                          'Внутри фирмы вы сможете создавать свои проекты и вести отдельный учёт по каждому. Общая сводка объединяет все проекты.'),
                      const SizedBox(height: 24),
                      TextField(
                          controller: name,
                          enabled: !busy && pending == null,
                          maxLength: 200,
                          decoration: const InputDecoration(
                              labelText: 'Название фирмы'),
                          onSubmitted: (_) => save()),
                      const SizedBox(height: 12),
                      const Text(
                          'Валюта — тенге (KZT). Юридические реквизиты и налоговый режим указываются в настройках фирмы.'),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                      if (pending != null && !busy)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                                'Результат запроса ещё не подтверждён. Повторите его — вторая фирма не создастся.')),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: busy ? null : save,
                          child: Text(busy
                              ? 'Создаём…'
                              : pending == null
                                  ? 'Создать фирму'
                                  : 'Повторить запрос')),
                      TextButton(
                          onPressed:
                              busy || pending != null ? null : widget.onCancel,
                          child: const Text('Назад')),
                    ],
                  )),
            )),
      ));
}
