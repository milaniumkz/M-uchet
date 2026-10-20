import 'workspace/debts_workspace.dart';
import 'workspace/company_search.dart';
import 'workspace/commercial_detail.dart';
import 'workspace/counterparty_workspace.dart';
import 'workspace/tax_calendar_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'backend/rest/api_client.dart';
import 'backend/rest/repositories.dart';
import 'workspace/project_repository.dart';
import 'workspace/company_settings_dialog.dart';
import 'workspace/money_entries_dialog.dart';
import 'workspace/commercial_workspace.dart';
import 'workspace/catalog_workspace.dart';
import 'workspace/company_creation.dart';
import 'workspace/bank_workspace.dart';
import 'workspace/ledger_workspace.dart';
import 'workspace/inventory_workspace.dart';
import 'workspace/recovery_dialog.dart';
import 'workspace/assets_workspace.dart';
import 'workspace/employees_workspace.dart';
import 'workspace/access_workspace.dart';
import 'workspace/company_access.dart';
import 'workspace/money_transaction_dialog.dart';
import 'workspace/cash_workspace.dart';
import 'workspace/account_dialog.dart';
import 'workspace/help_workspace.dart';
import 'workspace/goods_workspace.dart';
import 'workspace/payroll_workspace.dart';
import 'workspace/commercial_repository.dart' show moneyText;

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
  late final api =
      widget.client ??
      BackendClient(
        origin: Uri.parse(
          const String.fromEnvironment('API_ORIGIN').isNotEmpty
              ? const String.fromEnvironment('API_ORIGIN')
              : kIsWeb
              ? Uri.base.origin
              : 'http://127.0.0.1:8080',
        ),
      );
  final login = TextEditingController(), password = TextEditingController();
  CompanyDto? company;
  List<CompanyDto> companies = [];
  List<Map<String, dynamic>> projects = [];
  Map<String, dynamic>? report;
  String? selected, error;
  String section = 'projects';
  final sections = const {
    'projects': 'Проекты',
    'sales': 'Продажи',
    'goods': 'Товарные продажи',
    'purchases': 'Покупки',
    'bank': 'Деньги',
    'cash': 'Касса',
    'debts': 'Долги',
    'inventory': 'Склад',
    'assets': 'Активы',
    'employees': 'Сотрудники',
    'payroll': 'Зарплата',
    'tax-calendar': 'Налоги',
    'access': 'Доступ',
    'reports': 'Отчёты',
    'journal': 'Бухгалтерские записи',
    'periods': 'Закрытие месяца',
    'counterparties': 'Контрагенты',
    'catalog': 'Товары и услуги',
    'help': 'Помощь и обучение',
  };
  bool can(String permission) => company?.allows(permission) ?? true;
  bool visible(String key) => switch (key) {
    'tax-calendar' => can('tax-calendar.read'),
    'access' => company?.role == 'owner',
    'help' => true,
    'projects' => can('projects.read') && can('reports.read'),
    'sales' || 'purchases' => can('documents.read'),
    'goods' => can('orders.read') && can('catalog.read'),
    'bank' => can('bank.read') && can('wallets.read'),
    'cash' => can('wallets.read'),
    'debts' => can('debts.read'),
    'inventory' => can('inventory.read') && can('catalog.read'),
    'assets' => can('assets.read'),
    'employees' => can('employees.read'),
    'payroll' => can('payroll.read') && can('employees.read'),
    'reports' => can('reports.read') && can('accounting.read'),
    'journal' || 'periods' => can('accounting.read'),
    _ => can('catalog.read'),
  };
  Iterable<MapEntry<String, String>> get visibleSections =>
      sections.entries.where((e) => visible(e.key));
  DateTimeRange? period;
  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  bool busy = false;
  bool creatingCompany = false;
  bool canCreateCompanies = true;
  ProjectRepository get repository => ProjectRepository(api, company!.id);
  @override
  void initState() {
    super.initState();
    api.onUnauthorized = () {
      if (!mounted) {
        return;
      }
      navigator.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        company = null;
        creatingCompany = false;
        companies = [];
        projects = [];
        report = null;
        error = 'Сессия завершена. Войдите снова.';
      });
    };
  }

  @override
  void dispose() {
    api.onUnauthorized = null;
    api.close();
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) {
      return;
    }
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
          if (!api.authenticated) {
            company = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Не удалось загрузить данные. Повторите действие.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> refresh() async {
    if (company == null || !api.authenticated) {
      projects = [];
      report = null;
      return;
    }
    projects = can('projects.read') ? await repository.list() : [];
    report = can('reports.read')
        ? await repository.report(
            projectId: selected,
            from: period == null ? null : date(period!.start),
            to: period == null ? null : date(period!.end),
          )
        : null;
    if (!visible(section)) {
      section = visibleSections.firstOrNull?.key ?? 'none';
    }
  }

  Future<void> refreshAccess() async {
    final previous = company?.id;
    companies = await IdentityRepository(api).companies();
    company = companies.where((c) => c.id == previous).firstOrNull;
    if (company == null) {
      projects = [];
      report = null;
      selected = null;
      return;
    }
    await refresh();
  }

  Future<void> signIn() => perform(() async {
    final identity = IdentityRepository(api);
    final account = await identity.login(login.text.trim(), password.text);
    canCreateCompanies = account['canCreateCompanies'] != false;
    password.clear();
    companies = await identity.companies();
    if (companies.isEmpty) {
      creatingCompany = canCreateCompanies;
      return;
    }
    company = companies.first;
    selected = null;
    await refresh();
  });
  void companyCreated(CompanyDto created) {
    setState(() {
      companies = [...companies, created];
      company = created;
      creatingCompany = false;
      report = null;
      projects = [];
      selected = null;
    });
    perform(refresh);
  }

  Future<void> acceptInvitation() async {
    String initial = '';
    try {
      initial = Uri.splitQueryString(Uri.base.fragment)['invite'] ?? '';
    } on FormatException {
      initial = '';
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: navigator.currentContext!,
      builder: (_) =>
          InvitationAcceptanceDialog(api: api, initialToken: initial),
    );
    if (result == null) {
      return;
    }
    await perform(() async {
      final identity = IdentityRepository(api);
      final account = await identity.login(
        result['login'] as String,
        result['password'] as String,
      );
      canCreateCompanies = account['canCreateCompanies'] != false;
      login.text = result['login'] as String;
      companies = await identity.companies();
      company = companies.where((c) => c.id == result['companyId']).firstOrNull;
      if (company == null) {
        throw const BackendException('no_company');
      }
      creatingCompany = false;
      section = 'projects';
      selected = null;
      await refresh();
    });
  }

  Future<void> companySettings() async {
    await showDialog<bool>(
      context: navigator.currentContext!,
      builder: (context) =>
          CompanySettingsDialog(api: api, companyId: company!.id),
    );
  }

  Future<void> logout() => perform(() async {
    await IdentityRepository(api).logout();
    company = null;
    report = null;
    selected = null;
    projects = [];
    companies = [];
  });
  Future<void> account() async {
    final result = await showDialog<String>(
      context: navigator.currentContext!,
      barrierDismissible: false,
      builder: (_) => AccountDialog(api: api),
    );
    if (result != null && mounted) {
      api.clearSession();
      navigator.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        company = null;
        companies = [];
        report = null;
        projects = [];
        selected = null;
        creatingCompany = false;
        error = result == 'changed'
            ? 'Пароль изменён. Войдите с новым паролем.'
            : 'Проверьте вход с новым паролем. Если он не принят, используйте прежний.';
      });
    }
  }

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
          decoration: const InputDecoration(labelText: 'Название проекта'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                Navigator.pop(context, name.trim());
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  onChanged: (v) => name = v,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Название проекта',
                  ),
                ),
                SwitchListTile(
                  title: const Text('В архиве'),
                  subtitle: const Text('Все операции и история сохраняются'),
                  value: archived,
                  onChanged: (v) => update(() => archived = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (name.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
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
      saveText: 'Применить',
    );
    if (value != null) {
      await perform(() async {
        period = value;
        await refresh();
      });
    }
  }

  Future<void> addTransaction([
    Map<String, dynamic>? entry,
    bool companyWide = false,
  ]) async {
    List<Map<String, dynamic>> wallets = [];
    String? today;
    await perform(() async {
      final data = jsonObject(await loadCompanyWallets(api, company!.id));
      wallets = (data['items'] as List).map(jsonObject).toList();
      today = data['businessDate'] as String?;
    });
    if (error != null || !mounted || company == null) {
      return;
    }
    if (wallets.isEmpty) {
      final created = await showDialog<bool>(
        barrierDismissible: false,
        context: navigator.currentContext!,
        builder: (_) => CreateWalletDialog(api: api, companyId: company!.id),
      );
      if (created == true && mounted) {
        await addTransaction(entry, companyWide);
      }
      return;
    }
    final saved = await showDialog<bool>(
      barrierDismissible: false,
      context: navigator.currentContext!,
      builder: (_) => MoneyTransactionDialog(
        api: api,
        companyId: company!.id,
        currency: company!.currency,
        wallets: wallets,
        projects: projects,
        today: today ?? DateTime.now().toIso8601String().substring(0, 10),
        entry: entry,
        projectId: companyWide
            ? null
            : selected == 'unassigned'
            ? null
            : selected,
      ),
    );
    if (saved == true && mounted) {
      await perform(refresh);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'М-учёт',
    builder: (context, child) =>
        CompanyAccess(company: company, child: child ?? const SizedBox()),
    locale: const Locale('ru', 'RU'),
    supportedLocales: const [Locale('ru', 'RU'), Locale('kk', 'KZ')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'DejaVuSans',
      colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E9F2)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF5F7FB)),
        dividerThickness: 1,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14, letterSpacing: 0),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFE5E9F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: accent),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFE5E9F2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: creatingCompany && api.authenticated
            ? CompanyCreation(
                api: api,
                onCreated: companyCreated,
                onCancel: () {
                  if (company == null) {
                    logout();
                  }
                  setState(() => creatingCompany = false);
                },
              )
            : company == null
            ? (api.authenticated && !canCreateCompanies
                  ? noCompanyView()
                  : authView())
            : workspace(),
        floatingActionButton:
            company == null ||
                creatingCompany ||
                section != 'projects' ||
                !can('projects.write')
            ? null
            : FloatingActionButton(
                onPressed: busy ? null : createProject,
                tooltip: 'Создать проект',
                child: const Icon(Icons.add),
              ),
      ),
    ),
  );
  Widget noPermissionsView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Владелец ещё не выдал права на разделы этой фирмы.'),
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: company!.id,
            items: companies
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: busy
                ? null
                : (id) => perform(() async {
                    company = companies.firstWhere((c) => c.id == id);
                    selected = null;
                    await refresh();
                  }),
          ),
          TextButton(
            onPressed: busy ? null : () => perform(refreshAccess),
            child: const Text('Обновить доступ'),
          ),
          if (canCreateCompanies)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => creatingCompany = true),
              child: const Text('Добавить фирму'),
            ),
          TextButton(
            onPressed: busy ? null : logout,
            child: const Text('Выйти'),
          ),
        ],
      ),
    ),
  );
  Widget noCompanyView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Нет доступных фирм',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Попросите владельца предоставить доступ или передать новый код приглашения.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : acceptInvitation,
            child: const Text('Принять приглашение'),
          ),
          TextButton(
            onPressed: busy ? null : logout,
            child: const Text('Выйти'),
          ),
        ],
      ),
    ),
  );
  Widget authView() => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth >= 1100 && constraints.maxHeight >= 700
        ? desktopLogin()
        : Row(
            children: [
              if (constraints.maxWidth >= 1000)
                Expanded(
                  child: Container(
                    color: const Color(0xFFEFEEFE),
                    padding: const EdgeInsets.all(65),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'М-УЧЁТ',
                          style: TextStyle(
                            fontSize: 33,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Бухгалтерия,\nв которой\nвсё понятно.',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        SizedBox(height: 30),
                        Text(
                          'Доходы, расходы и проекты вашей компании\nв одном рабочем пространстве.',
                          style: TextStyle(
                            fontSize: 19,
                            color: muted,
                            height: 1.6,
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 484),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Вход в М-Учёт',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Продолжите работу с вашей компанией',
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 56),
                          TextField(
                            controller: login,
                            decoration: const InputDecoration(
                              labelText: 'Электронная почта',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Пароль',
                            ),
                            onSubmitted: (_) => busy ? null : signIn(),
                          ),
                          const SizedBox(height: 32),
                          FilledButton(
                            onPressed: busy ? null : signIn,
                            child: Text(busy ? 'Входим…' : 'Войти'),
                          ),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: navigator.currentContext!,
                              builder: (_) => RecoveryDialog(api: api),
                            ),
                            child: const Text('Забыли пароль?'),
                          ),
                          TextButton(
                            onPressed: busy ? null : acceptInvitation,
                            child: const Text('Принять приглашение'),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
  Widget desktopLogin() {
    Widget at(double x, double y, double width, Widget child) =>
        Positioned(left: x, top: y, width: width, child: child);
    Widget label(
      String value,
      double size, {
      Color color = ink,
      bool bold = false,
    }) => Text(
      value,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1440,
            height: 960,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: 700,
                  height: 960,
                  child: Container(color: const Color(0xFFEFEEFE)),
                ),
                at(60, 54, 300, label('М-учёт', 33, bold: true)),
                at(
                  550,
                  62,
                  120,
                  Chip(
                    label: label('Казахстан', 11),
                    side: BorderSide.none,
                    backgroundColor: Colors.white,
                  ),
                ),
                at(65, 231, 590, label('Бухгалтерия,', 44, bold: true)),
                at(65, 290, 590, label('в которой', 44, bold: true)),
                at(
                  65,
                  349,
                  590,
                  label('всё понятно.', 44, bold: true, color: accent),
                ),
                at(
                  68,
                  435,
                  535,
                  const Text(
                    'Для предпринимателя, который хочет заниматься бизнесом, а не разбираться в сложных терминах.',
                    style: TextStyle(fontSize: 19, color: muted, height: 1.52),
                  ),
                ),
                Positioned(
                  left: 65,
                  top: 584,
                  width: 564,
                  height: 170,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E9F2)),
                    ),
                  ),
                ),
                at(
                  94,
                  614,
                  510,
                  label('Сегодня у вас всё под контролем', 20, bold: true),
                ),
                at(
                  94,
                  658,
                  500,
                  label('Документы  ·  Деньги  ·  Налоги', 15, color: muted),
                ),
                at(
                  94,
                  700,
                  370,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: label(
                      'Один рабочий день без лишней рутины',
                      11,
                      color: const Color(0xFF087A56),
                    ),
                  ),
                ),
                at(811, 210, 484, label('Рады видеть вас', 29, bold: true)),
                at(
                  811,
                  260,
                  490,
                  label('Войдите, чтобы продолжить работу с компанией.', 14),
                ),
                at(811, 330, 484, label('Электронная почта', 12, color: muted)),
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
                        hintText: 'name@company.kz',
                      ),
                    ),
                  ),
                ),
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
                        hintText: '••••••••••••',
                      ),
                    ),
                  ),
                ),
                at(
                  1130,
                  513,
                  165,
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: navigator.currentContext!,
                      builder: (_) => RecoveryDialog(api: api),
                    ),
                    child: const Text(
                      'Забыли пароль?',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                at(
                  811,
                  567,
                  484,
                  SizedBox(
                    height: 43,
                    child: FilledButton(
                      onPressed: busy ? null : signIn,
                      child: Text(busy ? 'Входим…' : 'Войти'),
                    ),
                  ),
                ),
                at(
                  811,
                  636,
                  484,
                  TextButton(
                    onPressed: busy ? null : acceptInvitation,
                    child: const Text('Принять приглашение'),
                  ),
                ),
                at(
                  811,
                  695,
                  484,
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEEFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Ваши данные под защитой', 13, bold: true),
                        const SizedBox(height: 8),
                        label(
                          'Используйте личный аккаунт. Не передавайте пароль коллегам.',
                          12,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null)
                  at(811, 800, 484, label(error!, 13, color: Colors.red)),
                Positioned(
                  left: 65,
                  top: 880,
                  width: 1309,
                  child: Container(height: 1, color: const Color(0xFFE5E9F2)),
                ),
                at(
                  66,
                  904,
                  900,
                  label(
                    'М-учёт · рабочее пространство компании',
                    11,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> companySearch() async {
    final selectedCompany = company;
    if (selectedCompany == null) {
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: navigator.currentContext!,
      builder: (_) =>
          CompanySearchDialog(api: api, companyId: selectedCompany.id),
    );
    if (result == null || !mounted || company?.id != selectedCompany.id) {
      return;
    }
    final id = result['id'] as String, kind = result['kind'] as String;
    final base = ['v1', 'companies', selectedCompany.id];
    if (kind == 'PROJECT') {
      await perform(() async {
        selected = id;
        section = 'projects';
        await refresh();
      });
      return;
    }
    if (kind == 'DEBT') {
      await showOpeningDebt(
        navigator.currentContext!,
        api: api,
        companyId: selectedCompany.id,
        debtId: id,
        currency: selectedCompany.currency,
        projects: projects,
        onChanged: refresh,
      );
      return;
    }
    Map<String, dynamic>? entity;
    ResourceDto? resource;
    if (!['GOODS', 'ASSET'].contains(kind)) {
      await perform(() async {
        if (['SALE_INVOICE', 'SALE_ACT', 'PURCHASE_ACT'].contains(kind)) {
          entity = jsonObject(
            await api.request('GET', [...base, 'commercial-documents', id]),
          );
        } else if (kind == 'EMPLOYEE') {
          entity = jsonObject(
            await api.request('GET', [...base, 'employees', id]),
          );
        } else {
          resource = ResourceDto.fromJson(
            await api.request('GET', [...base, 'resources', kind, id]),
          );
        }
      });
      if (entity == null && resource == null) {
        return;
      }
    }
    if (!mounted || company?.id != selectedCompany.id) {
      return;
    }
    if (['SALE_INVOICE', 'SALE_ACT', 'PURCHASE_ACT'].contains(kind)) {
      await showDialog<void>(
        context: navigator.currentContext!,
        barrierDismissible: false,
        builder: (_) => CommercialDetail(
          api: api,
          companyId: selectedCompany.id,
          currency: selectedCompany.currency,
          document: entity!,
          projects: projects,
          onChanged: refresh,
        ),
      );
    } else if (kind == 'GOODS') {
      await showGoodsOrder(
        navigator.currentContext!,
        api: api,
        companyId: selectedCompany.id,
        orderId: id,
        currency: selectedCompany.currency,
        projects: projects,
        onChanged: refresh,
      );
    } else if (kind == 'ASSET') {
      await showAssetDetails(
        navigator.currentContext!,
        api: api,
        companyId: selectedCompany.id,
        assetId: id,
        currency: selectedCompany.currency,
        projects: projects,
        onChanged: refresh,
      );
    } else if (kind == 'EMPLOYEE') {
      await showDialog<bool>(
        context: navigator.currentContext!,
        barrierDismissible: false,
        builder: (_) => EmployeeEditor(
          api: api,
          companyId: selectedCompany.id,
          currency: selectedCompany.currency,
          projects: projects,
          employee: entity,
        ),
      );
    } else if (['clients', 'suppliers'].contains(kind) &&
        can('documents.read') &&
        can('accounting.read')) {
      await navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => CounterpartyWorkspace(
            api: api,
            companyId: selectedCompany.id,
            kind: kind,
            party: resource!,
            currency: selectedCompany.currency,
            projects: projects,
            onChanged: refresh,
          ),
        ),
      );
    } else {
      await showCatalogResource(
        navigator.currentContext!,
        api: api,
        companyId: selectedCompany.id,
        kind: kind,
        resource: resource!,
      );
    }
    if (mounted && company?.id == selectedCompany.id) {
      await perform(refresh);
    }
  }

  Widget searchButton() => Tooltip(
    message: 'Поиск по фирме',
    child: OutlinedButton.icon(
      onPressed: busy ? null : companySearch,
      icon: const Icon(Icons.search),
      label: const Text('Поиск по фирме'),
    ),
  );

  Widget navigation() => Container(
    width: 222,
    color: Colors.white,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'М-УЧЁТ',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        Text(
          company!.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: visibleSections
                .map(
                  (entry) => ListTile(
                    dense: true,
                    minTileHeight: 44,
                    selectedTileColor: const Color(0xFFEFEEFE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.zero,
                    selected: section == entry.key,
                    selectedColor: accent,
                    leading: Icon(switch (entry.key) {
                      'projects' => Icons.folder_outlined,
                      'sales' => Icons.receipt_long_outlined,
                      'goods' => Icons.local_shipping_outlined,
                      'purchases' => Icons.shopping_bag_outlined,
                      'bank' => Icons.account_balance_wallet_outlined,
                      'cash' => Icons.payments_outlined,
                      'debts' => Icons.handshake_outlined,
                      'reports' => Icons.bar_chart_outlined,
                      'inventory' => Icons.warehouse_outlined,
                      'assets' => Icons.computer_outlined,
                      'employees' => Icons.badge_outlined,
                      'payroll' => Icons.calculate_outlined,
                      'tax-calendar' => Icons.event_note_outlined,
                      'access' => Icons.admin_panel_settings_outlined,
                      'help' => Icons.help_outline,
                      'journal' => Icons.menu_book_outlined,
                      'periods' => Icons.calendar_month_outlined,
                      'counterparties' => Icons.people_outline,
                      _ => Icons.inventory_2_outlined,
                    }),
                    title: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: busy
                        ? null
                        : () => setState(() => section = entry.key),
                  ),
                )
                .toList(),
          ),
        ),
        if (canCreateCompanies)
          TextButton.icon(
            onPressed: busy
                ? null
                : () => setState(() => creatingCompany = true),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Добавить фирму'),
          ),
        TextButton.icon(
          onPressed: busy || !can('organization.read') ? null : companySettings,
          icon: const Icon(Icons.business_outlined),
          label: const Text('Фирма'),
        ),
        TextButton.icon(
          onPressed: busy ? null : account,
          icon: const Icon(Icons.person_outline),
          label: const Text('Мой аккаунт'),
        ),
        TextButton(onPressed: busy ? null : logout, child: const Text('Выйти')),
      ],
    ),
  );
  Widget sectionPicker() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (canCreateCompanies)
        IconButton(
          tooltip: 'Добавить фирму',
          onPressed: busy ? null : () => setState(() => creatingCompany = true),
          icon: const Icon(Icons.add_business_outlined),
        ),
      Expanded(
        child: DropdownButton<String>(
          value: section,
          isExpanded: true,
          items: visibleSections
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: busy ? null : (value) => setState(() => section = value!),
        ),
      ),
    ],
  );
  Widget workspace() {
    if (!visible(section)) {
      return noPermissionsView();
    }
    if (section == 'projects') {
      return projectWorkspace();
    }
    return LayoutBuilder(
      builder: (context, size) => Row(
        children: [
          if (size.maxWidth >= 1000) navigation(),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 33,
                    vertical: 16,
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (size.maxWidth < 1000)
                        SizedBox(width: 200, child: sectionPicker()),
                      SizedBox(
                        width: 250,
                        child: DropdownButton<String>(
                          value: company!.id,
                          isExpanded: true,
                          items: companies
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (id) => perform(() async {
                                  company = companies.firstWhere(
                                    (c) => c.id == id,
                                  );
                                  selected = null;
                                  await refresh();
                                }),
                        ),
                      ),
                      if ([
                        'sales',
                        'purchases',
                        'goods',
                        'employees',
                        'debts',
                        'payroll',
                        'reports',
                        'journal',
                      ].contains(section))
                        SizedBox(
                          width: 240,
                          child: DropdownButton<String>(
                            value: selected ?? 'all',
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('Вся фирма'),
                              ),
                              const DropdownMenuItem(
                                value: 'unassigned',
                                child: Text('Общие операции'),
                              ),
                              ...projects.map(
                                (p) => DropdownMenuItem(
                                  value: p['id'] as String,
                                  child: Text(
                                    p['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: busy
                                ? null
                                : (id) => perform(() async {
                                    selected = id == 'all' ? null : id;
                                    await refresh();
                                  }),
                          ),
                        ),
                      searchButton(),
                      IconButton(
                        tooltip: 'Обновить доступ и данные',
                        onPressed: busy ? null : () => perform(refreshAccess),
                        icon: const Icon(Icons.refresh),
                      ),
                      if ([
                        'sales',
                        'purchases',
                        'goods',
                        'reports',
                        'journal',
                      ].contains(section))
                        TextButton.icon(
                          onPressed: busy ? null : choosePeriod,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            period == null
                                ? 'За всё время'
                                : '${date(period!.start)} — ${date(period!.end)}',
                          ),
                        ),
                      IconButton(
                        tooltip: 'Мой аккаунт',
                        onPressed: busy ? null : account,
                        icon: const Icon(Icons.person_outline),
                      ),
                      if (size.maxWidth < 1000)
                        IconButton(
                          tooltip: 'Фирма',
                          onPressed: busy || !can('organization.read')
                              ? null
                              : companySettings,
                          icon: const Icon(Icons.business_outlined),
                        ),
                    ],
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                Expanded(
                  child: section == 'help'
                      ? HelpWorkspace(
                          api: api,
                          companyName: company!.name,
                          canOpen: visible,
                          onOpen: (key) => setState(() => section = key),
                        )
                      : ['sales', 'purchases'].contains(section)
                      ? CommercialWorkspace(
                          key: ValueKey(
                            '${company!.id}:$selected:$section:$period',
                          ),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          direction: section,
                          projects: projects,
                          projectId: selected,
                          from: period == null ? null : date(period!.start),
                          to: period == null ? null : date(period!.end),
                          onChanged: refresh,
                        )
                      : section == 'goods'
                      ? GoodsWorkspace(
                          key: ValueKey(
                            '${company!.id}:goods:$selected:$period',
                          ),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          projectId: selected,
                          from: period == null ? null : date(period!.start),
                          to: period == null ? null : date(period!.end),
                          onChanged: refresh,
                        )
                      : section == 'bank'
                      ? BankWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          onChanged: refresh,
                          onEditMoney: (entry) => addTransaction(entry),
                        )
                      : section == 'cash'
                      ? CashWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          onChanged: refresh,
                          onTransaction: (entry) => addTransaction(entry, true),
                        )
                      : section == 'access'
                      ? AccessWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                        )
                      : section == 'payroll'
                      ? PayrollWorkspace(
                          key: ValueKey('${company!.id}:payroll:$selected'),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          projectId: selected,
                          onChanged: refresh,
                          onEmployees: () =>
                              setState(() => section = 'employees'),
                        )
                      : section == 'debts'
                      ? DebtsWorkspace(
                          key: ValueKey('${company!.id}:debts:$selected'),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          projectId: selected,
                          onChanged: refresh,
                        )
                      : section == 'tax-calendar'
                      ? TaxCalendarWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                          onProfile: companySettings,
                        )
                      : section == 'employees'
                      ? EmployeesWorkspace(
                          key: ValueKey('${company!.id}:$selected'),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          projectId: selected,
                        )
                      : section == 'assets'
                      ? AssetsWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          onChanged: refresh,
                        )
                      : section == 'inventory'
                      ? InventoryWorkspace(
                          key: ValueKey(company!.id),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          projects: projects,
                          onChanged: refresh,
                        )
                      : ['reports', 'journal', 'periods'].contains(section)
                      ? LedgerWorkspace(
                          key: ValueKey(
                            '${company!.id}:$section:$selected:$period',
                          ),
                          api: api,
                          companyId: company!.id,
                          currency: company!.currency,
                          mode: section,
                          projects: projects,
                          projectId: selected,
                          from: period == null ? null : date(period!.start),
                          to: period == null ? null : date(period!.end),
                          onChanged: refresh,
                        )
                      : CatalogWorkspace(
                          key: ValueKey('${company!.id}:$section'),
                          api: api,
                          companyId: company!.id,
                          mode: section,
                          currency: company!.currency,
                          projects: projects,
                          onChanged: refresh,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget projectWorkspace() => LayoutBuilder(
    builder: (context, size) => Row(
      children: [
        if (size.maxWidth >= 1000) navigation(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(size.maxWidth < 600 ? 20 : 33),
            children: [
              if (size.maxWidth < 1000)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SizedBox(width: 240, child: sectionPicker()),
                ),
              const Text(
                'Бизнес под контролем',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Проекты и общая сводка фирмы',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: size.maxWidth < 600 ? size.maxWidth - 40 : 350,
                    child: DropdownButton<String>(
                      value: company!.id,
                      isExpanded: true,
                      items: companies
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) => perform(() async {
                              company = companies.firstWhere((c) => c.id == id);
                              selected = null;
                              report = null;
                              await refresh();
                            }),
                    ),
                  ),
                  SizedBox(
                    width: size.maxWidth < 600 ? size.maxWidth - 40 : 220,
                    child: DropdownButton<String>(
                      value: selected ?? 'all',
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Вся фирма'),
                        ),
                        const DropdownMenuItem(
                          value: 'unassigned',
                          child: Text('Общие операции'),
                        ),
                        ...projects.map(
                          (p) => DropdownMenuItem(
                            value: p['id'] as String,
                            child: Text(
                              '${p['name']}${p['archived'] == true ? ' · архив' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (id) => perform(() async {
                              selected = id == 'all' ? null : id;
                              await refresh();
                            }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy || !can('wallets.transact')
                        ? null
                        : addTransaction,
                    icon: const Icon(Icons.add),
                    label: const Text('Доход / расход'),
                  ),
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
                              onEdit: (entry) => addTransaction(entry),
                            ),
                          ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Операции'),
                  ),
                  searchButton(),
                  IconButton(
                    tooltip: 'Мой аккаунт',
                    onPressed: busy ? null : account,
                    icon: const Icon(Icons.person_outline),
                  ),
                  TextButton.icon(
                    onPressed: busy || !can('organization.read')
                        ? null
                        : companySettings,
                    icon: const Icon(Icons.business_outlined),
                    label: const Text('Фирма'),
                  ),
                  if (size.maxWidth < 1000)
                    IconButton(
                      onPressed: busy ? null : logout,
                      tooltip: 'Выйти',
                      icon: const Icon(Icons.logout),
                    ),
                  TextButton.icon(
                    onPressed: busy ? null : choosePeriod,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      period == null
                          ? 'За всё время'
                          : '${date(period!.start)} — ${date(period!.end)}',
                    ),
                  ),
                  if (period != null)
                    IconButton(
                      tooltip: 'Сбросить период',
                      onPressed: busy
                          ? null
                          : () => perform(() async {
                              period = null;
                              await refresh();
                            }),
                      icon: const Icon(Icons.clear),
                    ),
                  if (selected != null && selected != 'unassigned')
                    IconButton(
                      tooltip: 'Настройки проекта',
                      onPressed: busy || !can('projects.write')
                          ? null
                          : editProject,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  IconButton(
                    onPressed: busy ? null : () => perform(refreshAccess),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Обновить',
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              if (report != null) ...[
                Wrap(
                  spacing: 26,
                  runSpacing: 20,
                  children: [
                    metric('Доходы', 'revenue'),
                    metric('Расходы и себестоимость', 'costs'),
                    metric('Прибыль', 'netProfit'),
                  ],
                ),
                const SizedBox(height: 32),
                ...((report!['items'] as List).map((raw) {
                  final p = jsonObject(raw);
                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 30,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: Text(
                              p['name'] as String,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text('Доходы: ${money(p['revenue'])}'),
                          Text(
                            'Расходы и себестоимость: ${money(p['costs'] ?? 0)}',
                          ),
                          Text(
                            'Прибыль: ${money(p['netProfit'])}',
                            style: TextStyle(
                              color: (p['netProfit'] as num) < 0
                                  ? Colors.red
                                  : const Color(0xFF087A56),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })),
              ],
              if (projects.isEmpty && !busy)
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: Text(
                    'Создайте первый проект кнопкой +. Название и количество проектов определяете вы.',
                  ),
                ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    ),
  );
  String money(Object? value) => moneyText(value as num, company!.currency);
  Widget metric(String title, String key) {
    final rows = report!['items'] as List;
    final summary = jsonObject(
      report!['selectionTotal'] ??
          (selected == null
              ? report!['total']
              : rows.isEmpty
              ? <String, dynamic>{}
              : rows.first),
    );
    final amount = summary[key] as num? ?? 0;
    return Container(
      width: 290,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: muted)),
          const SizedBox(height: 20),
          Text(
            money(amount),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
