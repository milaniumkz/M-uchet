import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend/rest/api_client.dart';

const permissionGroups = {
  'catalog': 'Справочники',
  'organization': 'Реквизиты и структура фирмы',
  'planning': 'Планирование',
  'devices': 'Устройства',
  'support': 'Обращения',
  'inventory': 'Склад',
  'orders': 'Товарные заказы',
  'accounting': 'Бухгалтерия',
  'payments': 'Оплаты заказов',
  'files': 'Файлы',
  'audit': 'История действий',
  'wallets': 'Денежные счета',
  'debts': 'Задолженность',
  'shifts': 'Кассовые смены',
  'reports': 'Отчёты',
  'periods': 'Месяцы',
  'documents': 'Документы услуг',
  'projects': 'Проекты',
  'bank': 'Банковские выписки',
  'assets': 'Основные средства',
  'employees': 'Кадровые данные и оклады',
  'payroll': 'Зарплата и удержания',
};
const permissionActions = {
  'read': 'Просмотр',
  'write': 'Добавление и изменение',
  'post': 'Проведение',
  'edit': 'Исправление записей',
  'settle': 'Расчёты и оплаты',
  'export': 'Печать и экспорт',
  'transact': 'Денежные операции',
  'fulfill': 'Резерв и отгрузка',
  'receive': 'Поступление',
  'move': 'Перемещение',
  'writeoff': 'Списание',
  'close': 'Закрытие',
  'reopen': 'Открытие',
  'command': 'Управление устройствами',
  'import': 'Загрузка выписок',
  'review': 'Сопоставление',
};
String permissionLabel(String value) {
  final parts = value.split('.');
  return '${permissionGroups[parts.first] ?? parts.first}: ${permissionActions[parts.last] ?? parts.last}';
}

class AccessWorkspace extends StatefulWidget {
  const AccessWorkspace({
    super.key,
    required this.api,
    required this.companyId,
  });
  final BackendClient api;
  final String companyId;
  @override
  State<AccessWorkspace> createState() => _AccessWorkspaceState();
}

class _AccessWorkspaceState extends State<AccessWorkspace> {
  List<Map<String, dynamic>> members = [], invitations = [];
  List<String> available = [];
  bool busy = false;
  String? error;
  List<String> path(String name) => ['v1', 'companies', widget.companyId, name];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final m = await widget.api.request('GET', path('members')),
          i = jsonObject(await widget.api.request('GET', path('invitations'))),
          c = jsonObject(
            await widget.api.request('GET', ['v1', 'capabilities']),
          );
      if (mounted) {
        setState(() {
          members = (m as List).map(jsonObject).toList();
          invitations = (i['items'] as List).map(jsonObject).toList();
          available = (c['permissions'] as List).cast<String>();
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

  Future<void> edit([Map<String, dynamic>? member]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AccessEditor(
        api: widget.api,
        companyId: widget.companyId,
        available: available,
        member: member,
      ),
    );
    if (result != null && mounted) {
      if (result['token'] != null) {
        await showDialog<void>(
          context: context,
          builder: (_) => InvitationCodeDialog(invitation: result),
        );
      }
      if (mounted) {
        await load();
      }
    }
  }

  Future<void> revokeMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отозвать доступ к фирме?'),
        content: Text(
          'Пользователь ${member['name']} потеряет доступ к данным этой фирмы. Доступ к другим фирмам сохранится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отозвать доступ'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await run(
      () => widget.api.request('DELETE', [
        ...path('members'),
        member['userId'] as String,
      ]),
    );
  }

  Future<void> run(Future<Object?> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      await load();
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

  String inviteStatus(Map<String, dynamic> i) => i['revoked'] == true
      ? 'Отозвано'
      : i['accepted_at'] != null
      ? 'Принято'
      : (i['expires_at'] as num) <= DateTime.now().millisecondsSinceEpoch
      ? 'Срок истёк'
      : 'Ожидает принятия';
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
            'Доступ к фирме',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed: busy ? null : () => edit(),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Пригласить пользователя'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Приглашения и права действуют только в этой фирме. Кадровые данные и денежные операции выдаются отдельными полномочиями.',
      ),
      const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      ...members.map(
        (m) => Card(
          elevation: 0,
          child: ListTile(
            title: Text(m['name'] as String),
            subtitle: Text(
              m['role'] == 'owner'
                  ? 'Владелец'
                  : 'Выдано полномочий: ${(m['permissions'] as List).length}',
            ),
            trailing: m['role'] == 'owner'
                ? const Icon(Icons.verified_user_outlined)
                : Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Изменить права',
                        onPressed: busy ? null : () => edit(m),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Отозвать доступ',
                        onPressed: busy ? null : () => revokeMember(m),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Приглашения',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      ...invitations.map(
        (i) => Card(
          elevation: 0,
          child: ListTile(
            title: Text('${i['name']} · ${i['login']}'),
            subtitle: Text(inviteStatus(i)),
            trailing: i['revoked'] == true || i['accepted_at'] != null
                ? null
                : TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            () => widget.api.request('POST', [
                              ...path('invitations'),
                              i['id'] as String,
                              'revoke',
                            ], body: {}),
                          ),
                    child: const Text('Отозвать приглашение'),
                  ),
          ),
        ),
      ),
      if (invitations.isEmpty && !busy) const Text('Приглашений пока нет.'),
      TextButton.icon(
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh),
        label: const Text('Обновить'),
      ),
    ],
  );
}

class AccessEditor extends StatefulWidget {
  const AccessEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.available,
    this.member,
  });
  final BackendClient api;
  final String companyId;
  final List<String> available;
  final Map<String, dynamic>? member;
  @override
  State<AccessEditor> createState() => _AccessEditorState();
}

class _AccessEditorState extends State<AccessEditor> {
  final name = TextEditingController(), login = TextEditingController();
  Set<String> granted = {};
  String preset = 'custom';
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      granted = (widget.member!['permissions'] as List).cast<String>().toSet();
    }
  }

  @override
  void dispose() {
    name.dispose();
    login.dispose();
    super.dispose();
  }

  void choose(String value) {
    setState(() {
      preset = value;
      granted = switch (value) {
        'accountant' =>
          widget.available.where((p) => !p.startsWith('devices.')).toSet(),
        'viewer' =>
          widget.available
              .where(
                (p) =>
                    p.endsWith('.read') &&
                    !p.startsWith('employees.') &&
                    !p.startsWith('payroll.'),
              )
              .toSet(),
        'operator' => {
          'catalog.read',
          'catalog.write',
          'documents.read',
          'documents.write',
          'orders.read',
          'orders.write',
          'inventory.read',
          'projects.read',
          'files.read',
          'files.write',
        },
        _ => {},
      };
    });
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final result = jsonObject(
        await widget.api.request(
          widget.member == null ? 'POST' : 'PUT',
          [
            'v1',
            'companies',
            widget.companyId,
            widget.member == null ? 'invitations' : 'members',
            if (widget.member != null) widget.member!['userId'] as String,
          ],
          body: {
            if (widget.member == null) ...{
              'login': login.text,
              'name': name.text,
            },
            'permissions': granted.toList(),
          },
        ),
      );
      if (mounted) {
        Navigator.pop(context, result);
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.member == null ? 'Пригласить пользователя' : 'Права пользователя',
    ),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.member == null) ...[
              TextField(
                controller: name,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: login,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Электронная почта',
                ),
              ),
              const SizedBox(height: 14),
            ] else
              Text(widget.member!['name'] as String),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: preset,
              decoration: const InputDecoration(labelText: 'Набор полномочий'),
              items: const [
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('Выбрать самостоятельно'),
                ),
                DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
                DropdownMenuItem(
                  value: 'operator',
                  child: Text('Оператор документов'),
                ),
                DropdownMenuItem(
                  value: 'viewer',
                  child: Text('Наблюдатель без кадровых данных'),
                ),
              ],
              onChanged: busy ? null : (v) => choose(v!),
            ),
            const SizedBox(height: 14),
            ...widget.available.map(
              (p) => CheckboxListTile(
                dense: true,
                value: granted.contains(p),
                title: Text(permissionLabel(p)),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        preset = 'custom';
                        if (v == true) {
                          granted.add(p);
                        } else {
                          granted.remove(p);
                        }
                      }),
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (widget.member == null)
              const Text(
                'Код приглашения будет показан один раз. Передайте его адресату самостоятельно. Повторная выдача этому адресу отменяет прежний непринятый код. Письма автоматически не отправляются.',
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
        onPressed: busy ? null : save,
        child: Text(
          widget.member == null ? 'Создать приглашение' : 'Сохранить права',
        ),
      ),
    ],
  );
}

class InvitationCodeDialog extends StatefulWidget {
  const InvitationCodeDialog({super.key, required this.invitation});
  final Map<String, dynamic> invitation;
  @override
  State<InvitationCodeDialog> createState() => _InvitationCodeDialogState();
}

class _InvitationCodeDialogState extends State<InvitationCodeDialog> {
  bool copied = false;
  String? error;
  Future<void> copy() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: widget.invitation['token'] as String),
      );
      if (mounted) {
        setState(() => copied = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось скопировать. Выделите код вручную.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Приглашение создано'),
    content: SizedBox(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Адресат: ${widget.invitation['login']}'),
          const SizedBox(height: 16),
          SelectableText(widget.invitation['token'] as String),
          const SizedBox(height: 16),
          const Text(
            'Код действует 7 дней. Пользователь выбирает «Принять приглашение» на экране входа. Не публикуйте код в открытом доступе.',
          ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: copy,
        child: Text(copied ? 'Код скопирован' : 'Скопировать код'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Готово'),
      ),
    ],
  );
}

class InvitationAcceptanceDialog extends StatefulWidget {
  const InvitationAcceptanceDialog({
    super.key,
    required this.api,
    this.initialToken = '',
  });
  final BackendClient api;
  final String initialToken;
  @override
  State<InvitationAcceptanceDialog> createState() =>
      _InvitationAcceptanceDialogState();
}

class _InvitationAcceptanceDialogState
    extends State<InvitationAcceptanceDialog> {
  late final token = TextEditingController(text: widget.initialToken);
  final password = TextEditingController();
  Map<String, dynamic>? preview;
  Map<String, dynamic>? pending;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    token.dispose();
    password.dispose();
    super.dispose();
  }

  String invitationToken() {
    final value = token.text.trim(), uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme
        ? Uri.splitQueryString(uri.fragment)['invite'] ?? value
        : value;
  }

  Future<void> check() async {
    setState(() => busy = true);
    try {
      final data = jsonObject(
        await widget.api.request(
          'POST',
          ['v1', 'auth', 'invitations', 'preview'],
          authenticated: false,
          body: {'token': invitationToken()},
        ),
      );
      if (mounted) {
        setState(() {
          preview = data;
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

  Future<void> accept() async {
    setState(() => busy = true);
    try {
      pending ??= Map.unmodifiable({
        'token': invitationToken(),
        'password': password.text,
      });
      final result = jsonObject(
        await widget.api.request(
          'POST',
          ['v1', 'auth', 'invitations', 'accept'],
          authenticated: false,
          body: pending,
        ),
      );
      if (mounted) {
        Navigator.pop(context, {...result, 'password': pending!['password']});
      }
    } on BackendException catch (e) {
      if (e.code != 'network_error' && (e.status ?? 0) < 500) {
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Принять приглашение'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: token,
              enabled: !busy && pending == null,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Код приглашения'),
              onChanged: (_) => setState(() => preview = null),
            ),
            const SizedBox(height: 16),
            if (preview != null) ...[
              Text('Фирма: ${preview!['companyName']}'),
              Text('Аккаунт: ${preview!['login']}'),
              Text('Имя: ${preview!['name']}'),
              const SizedBox(height: 12),
              ...((preview!['permissions'] as List).cast<String>().map(
                (p) => Text('• ${permissionLabel(p)}'),
              )),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                enabled: !busy && pending == null,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: preview!['accountExists'] == true
                      ? 'Пароль существующего аккаунта'
                      : 'Создайте пароль, от 12 символов',
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (pending != null)
              const Text(
                'Повтор использует исходные данные. Доступ не будет выдан дважды.',
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
      if (preview == null)
        FilledButton(
          onPressed: busy ? null : check,
          child: const Text('Проверить приглашение'),
        )
      else
        FilledButton(
          onPressed: busy ? null : accept,
          child: Text(
            pending == null ? 'Принять приглашение' : 'Повторить принятие',
          ),
        ),
    ],
  );
}
