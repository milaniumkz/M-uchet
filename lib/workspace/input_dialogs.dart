import 'package:flutter/material.dart';

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirm,
    this.initialValue = '',
  });
  final String title, label, confirm, initialValue;
  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      maxLength: 200,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: Text(widget.confirm),
      ),
    ],
  );
}

class PeriodStatusDialog extends StatefulWidget {
  const PeriodStatusDialog({super.key, required this.month});
  final String month;
  @override
  State<PeriodStatusDialog> createState() => _PeriodStatusDialogState();
}

class _PeriodStatusDialogState extends State<PeriodStatusDialog> {
  late final month = TextEditingController(text: widget.month);
  final reason = TextEditingController();
  @override
  void dispose() {
    month.dispose();
    reason.dispose();
    super.dispose();
  }

  void finish(String action) => Navigator.pop(context, {
    'month': month.text,
    'reason': reason.text,
    'action': action,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Состояние месяца'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: month,
          decoration: const InputDecoration(labelText: 'Месяц YYYY-MM'),
        ),
        TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Комментарий'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: () => finish('reopen'),
        child: const Text('Открыть'),
      ),
      FilledButton(
        onPressed: () => finish('close'),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
