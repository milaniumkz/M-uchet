import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'backend/rest/api_client.dart';
import 'backend/rest/repositories.dart';
import 'workspace/project_repository.dart';
import 'workspace/company_settings_dialog.dart';
import 'workspace/money_entries_dialog.dart';

void main() => runApp(const AccountingWorkspace());
const ink = Color(0xFF171B35),
    accent = Color(0xFF5654E8),
    muted = Color(0xFF626E84);

class AccountingWorkspace extends StatefulWidget {
  const AccountingWorkspace({super.key, this.client});
  final BackendClient? client;
  @override
  State<AccountingWorkspace> createState() => _AccountingWorkspaceState();
}

class _AccountingWorkspaceState extends State<AccountingWorkspace> {
  final navigator = GlobalKey<NavigatorState>();
  late final api = widget.client ??
      BackendClient(
          origin:
              Uri.parse(const String.fromEnvironment('API_ORIGIN').isNotEmpty
                  ? const String.fromEnvironment('API_ORIGIN')
                  : kIsWeb
                      ? Uri.base.origin
                      : 'http://127.0.0.1:8080'));
  final login = TextEditingController(), password = TextEditingController();
  CompanyDto? company;
  List<CompanyDto> companies = [];
  List<Map<String, dynamic>> projects = [];
  Map<String, dynamic>? report;
  String? selected, error;
  DateTimeRange? period;
  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  bool busy = false;
  ProjectRepository get repository => ProjectRepository(api, company!.id);
  @override
  void dispose() {
    api.close();
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          if (!api.authenticated) company = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Не удалось загрузить данные. Повторите действие.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    projects = await repository.list();
    report = await repository.report(
        projectId: selected,
        from: period == null ? null : date(period!.start),
        to: period == null ? null : date(period!.end));
  }

  Future<void> signIn() => perform(() async {
        final identity = IdentityRepository(api);
        await identity.login(login.text.trim(), password.text);
        password.clear();
        companies = await identity.companies();
        if (companies.isEmpty) throw const BackendException('no_company');
        company = companies.first;
        selected = null;
        await refresh();
      });
  Future<void> companySettings() async {
    await showDialog<bool>(
        context: navigator.currentContext!,
        builder: (context) =>
            CompanySettingsDialog(api: api, companyId: company!.id));
  }

  Future<void> logout() => perform(() async {
        await IdentityRepository(api).logout();
        company = null;
        report = null;
        selected = null;
        projects = [];
        companies = [];
      });
  Future<void> createProject() async {
    var name = '';
    final value = await showDialog<String>(
        context: navigator.currentContext!,
        builder: (context) => AlertDialog(
                title: const Text('Новый проект'),
                content: TextField(
                    onChanged: (value) => name = value,
                    autofocus: true,
                    maxLength: 160,
                    decoration:
                        const InputDecoration(labelText: 'Название проекта')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () {
                        if (name.trim().isNotEmpty) {
                          Navigator.pop(context, name.trim());
                        }
                      },
                      child: const Text('Создать'))
                ]));
    if (value != null) {
      final key = OperationKey();
      await perform(() async {
        await repository.create(value, key);
        await refresh();
      });
    }
  }

  Future<void> editProject() async {
    final project = projects.firstWhere((p) => p['id'] == selected);
    var name = project['name'] as String,
        archived = project['archived'] as bool;
    final saved = await showDialog<bool>(
        context: navigator.currentContext!,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: const Text('Настройки проекта'),
                    content: SizedBox(
                        width: 420,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              initialValue: name,
                              onChanged: (v) => name = v,
                              maxLength: 160,
                              decoration: const InputDecoration(
                                  labelText: 'Название проекта')),
                          SwitchListTile(
                              title: const Text('В архиве'),
                              subtitle: const Text(
                                  'Все операции и история сохраняются'),
                              value: archived,
                              onChanged: (v) => update(() => archived = v))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      FilledButton(
                          onPressed: () {
                            if (name.trim().isNotEmpty) {
                              Navigator.pop(context, true);
                            }
                          },
                          child: const Text('Сохранить'))
                    ])));
    if (saved == true) {
      await perform(() async {
        await repository.update(project, name.trim(), archived, OperationKey());
        await refresh();
      });
    }
  }

  Future<void> choosePeriod() async {
    final value = await showDateRangePicker(
        context: navigator.currentContext!,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: period,
        helpText: 'Период отчёта',
        saveText: 'Применить');
    if (value != null) {
      await perform(() async {
        period = value;
        await refresh();
      });
    }
  }

  Future<void> addTransaction([Map<String, dynamic>? entry]) async {
    List<Map<String, dynamic>> wallets = [];
    await perform(() async {
      final response = jsonObject(await api
          .request('GET', ['v1', 'companies', company!.id, 'wallets']));
      wallets = (response['items'] as List).map(jsonObject).toList();
    });
    if (error != null || !mounted) return;
    if (wallets.isEmpty) {
      var name = '';
      final value = await showDialog<String>(
          context: navigator.currentContext!,
          builder: (context) => AlertDialog(
                  title: const Text('Добавьте денежный счёт'),
                  content: TextField(
                      onChanged: (v) => name = v,
                      decoration:
                          const InputDecoration(labelText: 'Название счёта')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () {
                          if (name.trim().isNotEmpty) {
                            Navigator.pop(context, name.trim());
                          }
                        },
                        child: const Text('Создать'))
                  ]));
      if (value == null) return;
      await perform(() async {
        await api.request('POST', ['v1', 'companies', company!.id, 'wallets'],
            body: {'name': value}, operation: OperationKey());
      });
      if (error == null) await addTransaction();
      return;
    }
    var walletId =
            entry?['wallet_id'] as String? ?? wallets.first['id'] as String,
        type = entry?['kind'] as String? ?? 'INCOME',
        amount = entry == null
            ? ''
            : ((entry['amount'] as num).abs() / 100).toStringAsFixed(2),
        description = entry?['description'] as String? ?? '';
    var projectId = entry == null
        ? (selected == 'unassigned' ? null : selected)
        : entry['project_id'] as String?;
    String? validation;
    final result = await showDialog<Map<String, dynamic>>(
        context: navigator.currentContext!,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: const Text('Денежная операция'),
                    content: SingleChildScrollView(
                        child: SizedBox(
                            width: 420,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButtonFormField<String>(
                                      initialValue: walletId,
                                      decoration: const InputDecoration(
                                          labelText: 'Денежный счёт'),
                                      items: wallets
                                          .map((w) => DropdownMenuItem(
                                              value: w['id'] as String,
                                              child: Text(w['name'] as String)))
                                          .toList(),
                                      onChanged: (v) => walletId = v!),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      initialValue: type,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'INCOME',
                                            child: Text('Доход')),
                                        DropdownMenuItem(
                                            value: 'EXPENSE',
                                            child: Text('Расход')),
                                        DropdownMenuItem(
                                            value: 'CAPITAL',
                                            child: Text('Вклад владельца'))
                                      ],
                                      onChanged: (v) => type = v!),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      initialValue: projectId ?? 'unassigned',
                                      decoration: const InputDecoration(
                                          labelText: 'Проект'),
                                      items: [
                                        const DropdownMenuItem(
                                            value: 'unassigned',
                                            child:
                                                Text('Общие операции фирмы')),
                                        ...projects.map((p) => DropdownMenuItem(
                                            value: p['id'] as String,
                                            child: Text(p['name'] as String)))
                                      ],
                                      onChanged: (v) => projectId =
                                          v == 'unassigned' ? null : v),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                      initialValue: amount,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (v) => amount = v,
                                      decoration: InputDecoration(
                                          labelText:
                                              'Сумма, ${company!.currency}')),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                      initialValue: description,
                                      onChanged: (v) => description = v,
                                      decoration: const InputDecoration(
                                          labelText: 'Основание операции')),
                                  if (validation != null)
                                    Text(validation!,
                                        style:
                                            const TextStyle(color: Colors.red))
                                ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена')),
                      FilledButton(
                          onPressed: () {
                            final normalized =
                                amount.trim().replaceAll(',', '.');
                            if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$')
                                    .hasMatch(normalized) ||
                                description.trim().isEmpty) {
                              update(() => validation =
                                  'Введите положительную сумму и основание.');
                              return;
                            }
                            final parts = normalized.split('.');
                            final minor = int.parse(parts[0]) * 100 +
                                int.parse(parts.length == 1
                                    ? '0'
                                    : parts[1].padRight(2, '0'));
                            if (minor <= 0 || minor > 1000000000000) {
                              update(() => validation = 'Проверьте сумму.');
                              return;
                            }
                            Navigator.pop(context, {
                              'walletId': walletId,
                              'type': type,
                              'amount': minor,
                              'projectId': projectId,
                              'description': description.trim()
                            });
                          },
                          child: const Text('Сохранить'))
                    ])));
    if (result != null) {
      await perform(() async {
        final wallet = result.remove('walletId') as String;
        await api.request(
            entry == null ? 'POST' : 'PUT',
            [
              'v1',
              'companies',
              company!.id,
              'wallets',
              wallet,
              if (entry == null)
                'transactions'
              else ...['entries', entry['id'] as String]
            ],
            body: result,
            operation: OperationKey());
        await refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'М-учёт',
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU'), Locale('kk', 'KZ')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          fontFamily: 'DejaVuSans',
          colorScheme: ColorScheme.fromSeed(seedColor: accent),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          textTheme: const TextTheme(
              bodyMedium:
                  TextStyle(color: ink, fontSize: 14, letterSpacing: 0)),
          inputDecorationTheme: const InputDecorationTheme(
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: Color(0xFFE5E9F2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: accent)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: Color(0xFFE5E9F2)))),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20)))),
      home: Builder(
          builder: (context) => Scaffold(
              body: company == null ? authView() : workspace(),
              floatingActionButton: company == null ? null : FloatingActionButton(onPressed: busy ? null : createProject, tooltip: 'Создать проект', child: const Icon(Icons.add)))));
  Widget authView() => LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1100 &&
              constraints.maxHeight >= 700
          ? desktopLogin()
          : Row(children: [
              if (constraints.maxWidth >= 1000)
                Expanded(
                    child: Container(
                        color: const Color(0xFFEFEEFE),
                        padding: const EdgeInsets.all(65),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('М-УЧЁТ',
                                  style: TextStyle(
                                      fontSize: 33,
                                      fontWeight: FontWeight.bold)),
                              Spacer(),
                              Text('Бухгалтерия,\nв которой\nвсё понятно.',
                                  style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.bold,
                                      color: accent)),
                              SizedBox(height: 30),
                              Text(
                                  'Доходы, расходы и проекты вашей компании\nв одном рабочем пространстве.',
                                  style: TextStyle(
                                      fontSize: 19, color: muted, height: 1.6)),
                              Spacer()
                            ]))),
              Expanded(
                  child: Center(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(40),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 484),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Вход в М-Учёт',
                                        style: TextStyle(
                                            fontSize: 29,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    const Text(
                                        'Продолжите работу с вашей компанией',
                                        style: TextStyle(color: muted)),
                                    const SizedBox(height: 56),
                                    TextField(
                                        controller: login,
                                        decoration: const InputDecoration(
                                            labelText: 'Электронная почта'),
                                        keyboardType:
                                            TextInputType.emailAddress),
                                    const SizedBox(height: 28),
                                    TextField(
                                        controller: password,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Пароль'),
                                        onSubmitted: (_) =>
                                            busy ? null : signIn()),
                                    const SizedBox(height: 32),
                                    FilledButton(
                                        onPressed: busy ? null : signIn,
                                        child:
                                            Text(busy ? 'Входим…' : 'Войти')),
                                    if (error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16),
                                          child: Text(error!,
                                              style: const TextStyle(
                                                  color: Colors.red)))
                                  ])))))
            ]));
  Widget desktopLogin() {
    Widget at(double x, double y, double width, Widget child) =>
        Positioned(left: x, top: y, width: width, child: child);
    Widget label(String value, double size,
            {Color color = ink, bool bold = false}) =>
        Text(value,
            style: TextStyle(
                fontSize: size,
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal));
    return ColoredBox(
        color: Colors.white,
        child: Center(
            child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                    width: 1440,
                    height: 960,
                    child: Stack(children: [
                      Positioned(
                          left: 0,
                          top: 0,
                          width: 700,
                          height: 960,
                          child: Container(color: const Color(0xFFEFEEFE))),
                      at(60, 54, 300, label('М-учёт', 33, bold: true)),
                      at(
                          550,
                          62,
                          120,
                          Chip(
                              label: label('Казахстан', 11),
                              side: BorderSide.none,
                              backgroundColor: Colors.white)),
                      at(65, 231, 590, label('Бухгалтерия,', 44, bold: true)),
                      at(65, 290, 590, label('в которой', 44, bold: true)),
                      at(65, 349, 590,
                          label('всё понятно.', 44, bold: true, color: accent)),
                      at(
                          68,
                          435,
                          535,
                          const Text(
                              'Для предпринимателя, который хочет заниматься бизнесом, а не разбираться в сложных терминах.',
                              style: TextStyle(
                                  fontSize: 19, color: muted, height: 1.52))),
                      Positioned(
                          left: 65,
                          top: 584,
                          width: 564,
                          height: 170,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFE5E9F2))))),
                      at(
                          94,
                          614,
                          510,
                          label('Сегодня у вас всё под контролем', 20,
                              bold: true)),
                      at(
                          94,
                          658,
                          500,
                          label('Документы  ·  Деньги  ·  Налоги', 15,
                              color: muted)),
                      at(
                          94,
                          700,
                          370,
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE9F8F0),
                                  borderRadius: BorderRadius.circular(8)),
                              child: label(
                                  'Один рабочий день без лишней рутины', 11,
                                  color: const Color(0xFF087A56)))),
                      at(811, 210, 484,
                          label('Рады видеть вас', 29, bold: true)),
                      at(
                          811,
                          260,
                          490,
                          label('Войдите, чтобы продолжить работу с компанией.',
                              14)),
                      at(811, 330, 484,
                          label('Электронная почта', 12, color: muted)),
                      at(
                          811,
                          355,
                          484,
                          SizedBox(
                              height: 49,
                              child: TextField(
                                  controller: login,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                      hintText: 'name@company.kz')))),
                      at(811, 435, 484, label('Пароль', 12, color: muted)),
                      at(
                          811,
                          460,
                          484,
                          SizedBox(
                              height: 49,
                              child: TextField(
                                  controller: password,
                                  obscureText: true,
                                  onSubmitted: (_) => busy ? null : signIn(),
                                  decoration: const InputDecoration(
                                      hintText: '••••••••••••')))),
                      at(
                          1130,
                          513,
                          165,
                          TextButton(
                              onPressed: () => showDialog<void>(
                                  context: navigator.currentContext!,
                                  builder: (context) => AlertDialog(
                                          title: const Text(
                                              'Восстановление доступа'),
                                          content: const Text(
                                              'Обратитесь к владельцу сервера для восстановления доступа к личному аккаунту.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Понятно'))
                                          ])),
                              child: const Text('Забыли пароль?',
                                  style: TextStyle(fontSize: 12)))),
                      at(
                          811,
                          567,
                          484,
                          SizedBox(
                              height: 43,
                              child: FilledButton(
                                  onPressed: busy ? null : signIn,
                                  child: Text(busy ? 'Входим…' : 'Войти')))),
                      at(
                          811,
                          636,
                          484,
                          label('Нужен доступ? Обратитесь к владельцу', 13,
                              color: accent)),
                      at(
                          811,
                          695,
                          484,
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEFEEFE),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label('Ваши данные под защитой', 13,
                                        bold: true),
                                    const SizedBox(height: 8),
                                    label(
                                        'Используйте личный аккаунт. Не передавайте пароль коллегам.',
                                        12,
                                        color: muted)
                                  ]))),
                      if (error != null)
                        at(811, 800, 484, label(error!, 13, color: Colors.red)),
                      Positioned(
                          left: 65,
                          top: 880,
                          width: 1309,
                          child: Container(
                              height: 1, color: const Color(0xFFE5E9F2))),
                      at(
                          66,
                          904,
                          900,
                          label('М-учёт · рабочее пространство компании', 11,
                              color: muted))
                    ])))));
  }

  Widget workspace() => LayoutBuilder(
      builder: (context, size) => Row(children: [
            if (size.maxWidth >= 1000)
              Container(
                  width: 222,
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('М-УЧЁТ',
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 40),
                        Text(company!.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 36),
                        const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.folder_outlined, color: accent),
                            title: Text('Проекты',
                                style: TextStyle(color: accent))),
                        const Spacer(),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () => perform(() async {
                                      await IdentityRepository(api).logout();
                                      company = null;
                                      report = null;
                                    }),
                            child: const Text('Выйти'))
                      ])),
            Expanded(
                child: ListView(
                    padding: EdgeInsets.all(size.maxWidth < 600 ? 20 : 33),
                    children: [
                  const Text('Бизнес под контролем',
                      style:
                          TextStyle(fontSize: 29, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Проекты и общая сводка фирмы',
                      style: TextStyle(color: muted)),
                  const SizedBox(height: 28),
                  Wrap(spacing: 16, runSpacing: 16, children: [
                    DropdownButton<String>(
                        value: company!.id,
                        items: companies
                            .map((c) => DropdownMenuItem(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: busy
                            ? null
                            : (id) => perform(() async {
                                  company =
                                      companies.firstWhere((c) => c.id == id);
                                  selected = null;
                                  report = null;
                                  await refresh();
                                })),
                    DropdownButton<String>(
                        value: selected ?? 'all',
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Вся фирма')),
                          const DropdownMenuItem(
                              value: 'unassigned',
                              child: Text('Общие операции')),
                          ...projects.map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                  '${p['name']}${p['archived'] == true ? ' · архив' : ''}')))
                        ],
                        onChanged: busy
                            ? null
                            : (id) => perform(() async {
                                  selected = id == 'all' ? null : id;
                                  await refresh();
                                })),
                    FilledButton.icon(
                        onPressed: busy ? null : addTransaction,
                        icon: const Icon(Icons.add),
                        label: const Text('Доход / расход')),
                    TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => showDialog<void>(
                                context: navigator.currentContext!,
                                builder: (context) => MoneyEntriesDialog(
                                    api: api,
                                    companyId: company!.id,
                                    currency: company!.currency,
                                    projectId: selected,
                                    onEdit: (entry) => addTransaction(entry))),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Операции')),
                    TextButton.icon(
                        onPressed: busy ? null : companySettings,
                        icon: const Icon(Icons.business_outlined),
                        label: const Text('Фирма')),
                    if (size.maxWidth < 1000)
                      IconButton(
                          onPressed: busy ? null : logout,
                          tooltip: 'Выйти',
                          icon: const Icon(Icons.logout)),
                    TextButton.icon(
                        onPressed: busy ? null : choosePeriod,
                        icon: const Icon(Icons.date_range),
                        label: Text(period == null
                            ? 'За всё время'
                            : '${date(period!.start)} — ${date(period!.end)}')),
                    if (period != null)
                      IconButton(
                          tooltip: 'Сбросить период',
                          onPressed: busy
                              ? null
                              : () => perform(() async {
                                    period = null;
                                    await refresh();
                                  }),
                          icon: const Icon(Icons.clear)),
                    if (selected != null && selected != 'unassigned')
                      IconButton(
                          tooltip: 'Настройки проекта',
                          onPressed: busy ? null : editProject,
                          icon: const Icon(Icons.settings_outlined)),
                    IconButton(
                        onPressed: busy ? null : () => perform(refresh),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Обновить')
                  ]),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 24),
                  if (report != null) ...[
                    Wrap(spacing: 26, runSpacing: 20, children: [
                      metric('Доходы', 'revenue'),
                      metric('Расходы и себестоимость', 'costs'),
                      metric('Прибыль', 'netProfit')
                    ]),
                    const SizedBox(height: 32),
                    ...((report!['items'] as List).map((raw) {
                      final p = jsonObject(raw);
                      return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child:
                                  Wrap(spacing: 30, runSpacing: 12, children: [
                                SizedBox(
                                    width: 240,
                                    child: Text(p['name'] as String,
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold))),
                                Text('Доходы: ${money(p['revenue'])}'),
                                Text(
                                    'Расходы и себестоимость: ${money((p['expenses'] as num) + (p['cogs'] as num))}'),
                                Text('Прибыль: ${money(p['netProfit'])}',
                                    style: TextStyle(
                                        color: (p['netProfit'] as num) < 0
                                            ? Colors.red
                                            : const Color(0xFF087A56)))
                              ])));
                    }))
                  ],
                  if (projects.isEmpty && !busy)
                    const Padding(
                        padding: EdgeInsets.only(top: 28),
                        child: Text(
                            'Создайте первый проект кнопкой +. Название и количество проектов определяете вы.')),
                  const SizedBox(height: 60)
                ]))
          ]));
  String money(Object? value) =>
      '${((value as num) / 100).toStringAsFixed(2)} ${company!.currency}';
  Widget metric(String title, String key) {
    final items = (report!['items'] as List).map(jsonObject);
    final amount = items.fold<num>(
        0,
        (sum, p) =>
            sum +
            (key == 'costs'
                ? (p['expenses'] as num) + (p['cogs'] as num)
                : (p[key] as num)));
    return Container(
        width: 290,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E9F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: muted)),
          const SizedBox(height: 20),
          Text(money(amount),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
        ]));
  }
}
