import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/utils/effective_company_support.dart';
import '/utils/company_module_settings.dart';
import '/utils/onboarding_progress.dart';
import '/user_design/user_design.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import '/component/header/header_widget.dart';
import 'package:expandable/expandable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'drawers_users_model.dart';
export 'drawers_users_model.dart';

class DrawersUsersWidget extends StatefulWidget {
  const DrawersUsersWidget({super.key});

  @override
  State<DrawersUsersWidget> createState() => _DrawersUsersWidgetState();
}

class _DrawersUsersWidgetState extends State<DrawersUsersWidget>
    with TickerProviderStateMixin {
  late DrawersUsersModel _model;

  final animationsMap = <String, AnimationInfo>{};
  Future<bool>? _auditAlertFuture;
  String _auditAlertKey = '';
  bool _syncingSidebarSections = false;
  String? _activeSidebarSection;
  String? _lastSidebarRoutePath;

  bool _isActivePath(String path) {
    final location = GoRouterState.of(context).uri.path;
    return location == path || location.startsWith('$path/');
  }

  bool _isOrgViewActive(String view) {
    final uri = GoRouterState.of(context).uri;
    if (uri.path != OrgStructuraWidget.routePath) return false;
    final current = (uri.queryParameters['view'] ?? '').trim();
    if (current.isEmpty) {
      return view == 'business';
    }
    return current == view;
  }

  String _resolvedActiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    ).trim();
  }

  Future<bool> _loadAuditAlert(String companyId) async {
    if (companyId.isEmpty) return false;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_1c_runs')
          .where('idCompany', isEqualTo: companyId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (snapshot.docs.isEmpty) return false;
      final data = snapshot.docs.first.data();
      final indicators = (data['indicators'] is Map)
          ? Map<String, dynamic>.from(data['indicators'] as Map)
          : const <String, dynamic>{};
      final critical = (indicators['critical_count'] as num?)?.toInt() ?? 0;
      final high = (indicators['high_count'] as num?)?.toInt() ?? 0;
      return critical > 0 || high > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _auditAlertFutureForCompany(String companyId) {
    if (_auditAlertFuture == null || _auditAlertKey != companyId) {
      _auditAlertKey = companyId;
      _auditAlertFuture = _loadAuditAlert(companyId);
    }
    return _auditAlertFuture!;
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DrawersUsersModel());

    _model.expandableExpandableController1 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController2 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController3 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController4 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController5 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController6 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController7 =
        ExpandableController(initialExpanded: false);
    _model.expandableExpandableController8 =
        ExpandableController(initialExpanded: false);
    _wireSidebarSection('money', _model.expandableExpandableController1);
    _wireSidebarSection('goods', _model.expandableExpandableController2);
    _wireSidebarSection('sales', _model.expandableExpandableController3);
    _wireSidebarSection('analytics', _model.expandableExpandableController4);
    _wireSidebarSection('company', _model.expandableExpandableController5);
    _wireSidebarSection('security', _model.expandableExpandableController6);
    _wireSidebarSection('personal', _model.expandableExpandableController7);
    _wireSidebarSection('settings', _model.expandableExpandableController8);
    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 1.ms),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, 20.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  Map<String, ExpandableController> _sidebarControllers() => {
        'money': _model.expandableExpandableController1,
        'goods': _model.expandableExpandableController2,
        'sales': _model.expandableExpandableController3,
        'analytics': _model.expandableExpandableController4,
        'company': _model.expandableExpandableController5,
        'security': _model.expandableExpandableController6,
        'personal': _model.expandableExpandableController7,
        'settings': _model.expandableExpandableController8,
      };

  void _setOnlySidebarSectionExpanded(String key) {
    _syncingSidebarSections = true;
    final controller = _sidebarControllers()[key];
    if (controller != null && !controller.expanded) {
      controller.expanded = true;
    }
    _activeSidebarSection = key;
    _syncingSidebarSections = false;
  }

  void _wireSidebarSection(String key, ExpandableController controller) {
    controller.addListener(() {
      if (_syncingSidebarSections || !controller.expanded) return;
      _setOnlySidebarSectionExpanded(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final inherited = UserDesignScope.maybeOf(context);
    if (inherited == null) {
      return const UserDesignScopeLoader(
        child: DrawersUsersWidget(),
      );
    }
    final design = inherited;
    final isCollapsed = FFAppState().userSidebarCollapsed;

    final showTransactionsJournal = true;

    bool _can(String key) => PermissionsHelper.has(key);
    bool _canAny(List<String> keys) => keys.any(_can);
    bool _isCompanyAdmin() {
      final data = currentUserDocument?.snapshotData ?? const {};
      final roleRaw = (data['role'] ?? '').toString().toLowerCase().trim();
      return (data['is_admin'] == true) ||
          (data['admin'] == true) ||
          roleRaw == 'admin' ||
          roleRaw == 'owner' ||
          roleRaw == 'business_owner' ||
          roleRaw == 'владелец' ||
          roleRaw == 'владелец / директор';
    }

    Widget _auditAlertBadge() {
      final companyId = _resolvedActiveCompanyId();
      if (companyId.isEmpty) return const SizedBox.shrink();
      return FutureBuilder<bool>(
        future: _auditAlertFutureForCompany(companyId),
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();
          return Tooltip(
            message:
                'Бухучет недостоверный. Есть критические/существенные ошибки. Нажмите для перехода в аудит.',
            child: InkWell(
              onTap: () => context.pushNamed(Audit1CWidget.routeName),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 14,
                  color: Colors.transparent,
                ),
              ),
            ),
          );
        },
      );
    }

    final userData = currentUserDocument?.snapshotData ?? const {};
    final roleRaw = (userData['role'] ?? userData['role_name'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final isOwnerUser = roleRaw == 'owner' ||
        roleRaw == 'business_owner' ||
        roleRaw == 'владелец' ||
        roleRaw == 'владелец / директор';
    final companyModules = normalizeCompanyModules(
      userData['company_modules'] ?? userData['enabled_modules'],
    );
    bool _moduleEnabled(String key) =>
        isOwnerUser || companyModules[key] != false;
    final onboardingComplete = userData['onboarding_complete'] == true;
    final onboardingStepsRaw = userData['onboarding_steps'];
    final onboardingSteps = onboardingStepsRaw is Map
        ? onboardingStepsRaw
            .map((key, value) => MapEntry(key.toString(), value == true))
        : const <String, bool>{};
    final onboardingSkippedRaw = userData['onboarding_skipped'];
    final onboardingSkipped = onboardingSkippedRaw is Map
        ? onboardingSkippedRaw
            .map((key, value) => MapEntry(key.toString(), value == true))
        : const <String, bool>{};
    final skippedIncompleteStepKeys = OnboardingProgress.orderedSteps
        .where((step) =>
            onboardingSkipped[step.key] == true &&
            onboardingSteps[step.key] != true)
        .map((step) => step.key)
        .toList(growable: false);
    final hasSkippedIncompleteSteps = skippedIncompleteStepKeys.isNotEmpty;

    bool _stepNeedsAttention(String key) {
      if (onboardingSkipped[key] == true && onboardingSteps[key] != true) {
        return true;
      }
      if (onboardingComplete) return false;
      return onboardingSteps[key] != true;
    }

    bool _sectionNeedsAttention(String key) {
      switch (key) {
        case 'money':
          return _stepNeedsAttention('accounts') ||
              _stepNeedsAttention('budgets');
        case 'products':
          return _stepNeedsAttention('warehouses') ||
              _stepNeedsAttention('products');
        case 'sales':
          return _stepNeedsAttention('shops');
        case 'company':
          return _stepNeedsAttention('companies') ||
              _stepNeedsAttention('roles') ||
              _stepNeedsAttention('org') ||
              _stepNeedsAttention('employees');
        default:
          return false;
      }
    }

    Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

    Color _menuItemBackground(bool active, {Color? accent}) {
      if (active) {
        return design.activeSurfaceColor;
      }
      return Color.alphaBlend(
        design.surfaceColor.withValues(alpha: design.isDarkTheme ? 0.68 : 0.9),
        design.softSurfaceColor,
      );
    }

    Color _menuItemForeground(bool active, {Color? accent}) {
      return active ? design.buttonColor : design.textColor;
    }

    Color _menuWarnColor(bool active, String stepKey, Color fallback) {
      if (active) return design.buttonColor;
      if (_stepNeedsAttention(stepKey)) {
        return FlutterFlowTheme.of(context).error;
      }
      return fallback;
    }

    Color _menuWarnBg(bool active, String stepKey) {
      if (active) return design.activeSurfaceColor;
      if (_stepNeedsAttention(stepKey)) {
        return Color.alphaBlend(
          FlutterFlowTheme.of(context).error.withValues(alpha: 0.12),
          design.softSurfaceColor,
        );
      }
      return design.softSurfaceColor;
    }

    Future<void> _openMenuTarget(String routeName, {String? onboardingStep}) {
      if (onboardingStep != null &&
          onboardingSkipped[onboardingStep] == true &&
          onboardingSteps[onboardingStep] != true) {
        return context.pushNamed(
          CompanyOnboardingWidget.routeName,
          queryParameters: {'step': onboardingStep},
        );
      }
      return context.pushNamed(routeName);
    }

    final activeSections = <String, bool>{};

    Color _sectionAccent(String key) {
      final active = activeSections[key] == true;
      if (!active && _sectionNeedsAttention(key)) {
        return FlutterFlowTheme.of(context).error;
      }
      return active
          ? design.drawerSectionActiveIconColor
          : design.drawerSectionIconColor;
    }

    Color _sectionHeaderBg(String key) {
      final active = activeSections[key] == true;
      if (!active && _sectionNeedsAttention(key)) {
        return Color.alphaBlend(
          FlutterFlowTheme.of(context).error.withValues(alpha: 0.12),
          design.surfaceColor,
        );
      }
      return active
          ? design.activeSurfaceColor
          : Color.alphaBlend(
              design.softSurfaceColor.withValues(
                alpha: design.isDarkTheme ? 0.92 : 0.86,
              ),
              design.surfaceColor,
            );
    }

    TextStyle _sectionTextStyle(String key) {
      final active = activeSections[key] == true;
      final textColor = active
          ? design.drawerSectionActiveTextColor
          : design.drawerSectionTextColor;
      return FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            color: textColor,
            fontSize: 14.0,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w800,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
          );
    }

    Widget _sectionHeaderWrap(String key, Widget child, {bool? expanded}) {
      final active = activeSections[key] == true;
      final warned = !active && _sectionNeedsAttention(key);
      final bg = _sectionHeaderBg(key);
      return Container(
        width: double.infinity,
        margin: const EdgeInsetsDirectional.fromSTEB(10.0, 5.0, 10.0, 5.0),
        padding: const EdgeInsetsDirectional.fromSTEB(14.0, 8.0, 14.0, 8.0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: active
                ? design.activeSurfaceBorder
                : warned
                    ? FlutterFlowTheme.of(context).error.withValues(alpha: 0.6)
                    : design.softSurfaceBorder.withValues(
                        alpha: design.isDarkTheme ? 0.82 : 1.0,
                      ),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 16.0,
              color: Colors.black
                  .withValues(alpha: design.isDarkTheme ? 0.16 : 0.05),
              offset: const Offset(0.0, 8.0),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: child),
            const SizedBox(width: 8.0),
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                color: design.drawerSectionArrowBackgroundColor,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: active
                      ? design.activeSurfaceBorder
                      : warned
                          ? FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.5)
                          : design.softSurfaceBorder.withValues(
                              alpha: design.isDarkTheme ? 0.82 : 1.0,
                            ),
                ),
              ),
              child: Icon(
                expanded == true
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                size: 24.0,
                color: design.drawerSectionArrowIconColor,
              ),
            ),
          ],
        ),
      );
    }

    Widget _expandableSectionHeader({
      required String key,
      required ExpandableController controller,
      required Widget child,
    }) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _sectionHeaderWrap(
          key,
          child,
          expanded: controller.expanded,
        ),
      );
    }

    Widget _goodsMenuItem({
      required bool visible,
      required Future<void> Function() onTap,
      required IconData icon,
      required String label,
      String? routePath,
    }) {
      if (!visible) return const SizedBox.shrink();
      final isActive = routePath != null && _isActivePath(routePath);
      return InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          await onTap();
        },
        child: Container(
          height: 48.0,
          decoration: BoxDecoration(
            color: Colors.transparent,
          ),
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: _menuItemBackground(isActive),
            elevation: 0.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(
                color: isActive
                    ? design.buttonColor.withValues(alpha: 0.20)
                    : design.softSurfaceBorder.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 6.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    icon,
                    color: _menuItemForeground(isActive),
                    size: 24.0,
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                    child: Text(
                      label,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w500,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: _menuItemForeground(isActive),
                            fontSize: 14.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final showMoney = _moduleEnabled(kModuleMoney) &&
        _canAny([
          'scheta.view',
          'scheta.manage',
          'scheta.add',
          'uchet.view',
          'tranzaction.view',
          'tranzaction.add',
          'funding_requests.create',
          'money.expense_categories',
          'money.obligations',
        ]);
    final showGoods = _moduleEnabled(kModuleGoods) &&
        _canAny([
          'nomenclature.view',
          'nomenclature.add',
          'services.view',
          'suppliers.view',
          'warehouse.view',
          'sales.controls',
          'analytics.portfolio',
        ]);
    final showSales = _moduleEnabled(kModuleSales) &&
        _canAny([
          'sales.view',
          'sales.shops',
          'sales.clients',
          'sales.controls',
          'sales.cash',
          'sales.reports',
          'sales.income',
          'sales.expenses',
          'sales.profit.shop',
          'sales.profit.cashier',
          'sales.abc',
        ]);
    final showAnalytics = _moduleEnabled(kModuleAnalytics) &&
        _canAny([
          'analytics.view',
          'analytics.sales',
          'analytics.fin',
          'analytics.margin',
          'analytics.invest',
          'analytics.models',
          'analytics.abc',
          'analytics.portfolio',
        ]);
    final showCompany = _moduleEnabled(kModuleCompany) &&
        (_isCompanyAdmin() ||
            _canAny([
              'company.org',
              'company.hr',
              'settings.rekviziti',
              'settings.taxes',
            ]));
    final canOpenCompanySetup = _isCompanyAdmin() ||
        _canAny([
          'company.org',
          'company.hr',
          'settings.rekviziti',
          'settings.taxes',
        ]);
    final showAudit = _moduleEnabled(kModuleAnalytics) &&
        (_can('audit.view') ||
            (_isCompanyAdmin() &&
                _canAny([
                  'scheta.view',
                  'uchet.view',
                  'tranzaction.view',
                  'analytics.view',
                ])));
    final showSecurity = _moduleEnabled(kModuleSecurity) &&
        _canAny([
          'security.block',
          'security.restore',
          'security.delete',
        ]);
    final showSettings = _moduleEnabled(kModuleSettings) &&
        _canAny([
          'settings.view',
          'settings.currency',
          'settings.taxes',
          'settings.calculator',
          'settings.rekviziti',
          'settings.roles',
          'settings.users',
          'settings.tariffs',
        ]);
    final showPersonalMoney = _moduleEnabled(kModulePersonal) &&
        _canAny([
          'money.my',
          'money.my_expenses',
          'money.company_expenses',
        ]);

    final activeMoneySection = _isActivePath(SchetaWidget.routePath) ||
        _isActivePath(FundingRequestsWidget.routePath) ||
        _isActivePath(UchetWidget.routePath) ||
        _isActivePath(TranzactionWidget.routePath) ||
        _isActivePath(TranzactionJournalWidget.routePath) ||
        _isActivePath(StatRasWidget.routePath) ||
        _isActivePath(ObyazWidget.routePath);
    final activeGoodsSection = _isActivePath(ScladWidget.routePath) ||
        _isActivePath(TovarWidget.routePath) ||
        _isActivePath(UslugiWidget.routePath) ||
        _isActivePath(PortProductWidget.routePath) ||
        _isActivePath(ControlsSalesWidget.routePath) ||
        _isActivePath(KontrAgentWidget.routePath);
    final activeSalesSection = _isActivePath(ShopWidget.routePath) ||
        _isActivePath(ClientWidget.routePath) ||
        _isActivePath(ReceivablesWidget.routePath);
    final activeAnalyticsSection = _isActivePath(Audit1CWidget.routePath) ||
        _isActivePath(FinOtchetWidget.routePath) ||
        _isActivePath(OtchetSaleWidget.routePath) ||
        _isActivePath(FinModelsWidget.routePath) ||
        _isActivePath(InvestOtchetWidget.routePath) ||
        _isActivePath(MarjaWidget.routePath) ||
        _isActivePath(AbcPageSaleWidget.routePath);
    final activeCompanySection = _isActivePath(CompanySetupWidget.routePath) ||
        _isActivePath(OrgStructuraWidget.routePath) ||
        _isActivePath(HrControlsWidget.routePath);
    final activeSecuritySection = _isActivePath(BlocAppsWidget.routePath) ||
        _isActivePath(DeleteDataWidget.routePath) ||
        _isActivePath(RecoveryWidget.routePath);
    final activePersonalSection = _isActivePath(MyMoneyWidget.routePath) ||
        _isActivePath(MyMoneyCompWidget.routePath) ||
        _isActivePath(MyDecomeWidget.routePath) ||
        _isActivePath(MyDecomeCompWidget.routePath);
    final activeSettingsSection = _isActivePath(RoliWidget.routePath) ||
        _isActivePath(RekvizitiWidget.routePath) ||
        _isActivePath(NalogiWidget.routePath) ||
        _isActivePath(ValutaWidget.routePath) ||
        _isActivePath(CalculatWidget.routePath);

    activeSections.addAll({
      'money': activeMoneySection,
      'goods': activeGoodsSection,
      'sales': activeSalesSection,
      'analytics': activeAnalyticsSection,
      'company': activeCompanySection,
      'security': activeSecuritySection,
      'personal': activePersonalSection,
      'settings': activeSettingsSection,
    });

    String? routeActiveSection;
    for (final entry in activeSections.entries) {
      if (entry.value) {
        routeActiveSection = entry.key;
        break;
      }
    }
    final currentRoutePath = GoRouterState.of(context).uri.path;
    if (routeActiveSection != null &&
        _lastSidebarRoutePath != currentRoutePath) {
      _lastSidebarRoutePath = currentRoutePath;
      final controller = _sidebarControllers()[routeActiveSection];
      if (_activeSidebarSection != routeActiveSection ||
          controller?.expanded != true) {
        _setOnlySidebarSectionExpanded(routeActiveSection);
      }
    }

    Future<void> _openCollapsedTarget(String routeName) =>
        context.pushNamed(routeName);

    Widget _collapsedRailButton({
      required IconData icon,
      required String tooltip,
      required Future<void> Function() onTap,
      bool active = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () async => onTap(),
          borderRadius: BorderRadius.circular(14.0),
          child: Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color:
                  active ? design.activeSurfaceColor : design.softSurfaceColor,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: active
                    ? design.activeSurfaceBorder
                    : design.softSurfaceBorder,
              ),
            ),
            child: Icon(
              icon,
              color: active ? design.buttonColor : design.textColor,
              size: 24.0,
            ),
          ),
        ),
      );
    }

    if (isCollapsed) {
      return Container(
        decoration: BoxDecoration(
          gradient: design.sidebarBackground,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 18.0, 12.0, 16.0),
          child: Column(
            children: [
              _collapsedRailButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                tooltip: 'Развернуть боковое меню',
                onTap: () async {
                  FFAppState().update(() {
                    FFAppState().userSidebarCollapsed = false;
                  });
                },
              ),
              const SizedBox(height: 14.0),
              Container(
                width: 54.0,
                height: 54.0,
                decoration: BoxDecoration(
                  color: design.buttonColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: design.buttonColor,
                  size: 28.0,
                ),
              ),
              const SizedBox(height: 18.0),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 18.0),
                    child: Column(
                      children: [
                        if (hasSkippedIncompleteSteps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.playlist_add_check_circle_outlined,
                              tooltip: 'Дозаполнить пропущенные данные',
                              active: _isActivePath(
                                  CompanyOnboardingWidget.routePath),
                              onTap: () async => _openCollapsedTarget(
                                CompanyOnboardingWidget.routeName,
                              ),
                            ),
                          ),
                        if (showMoney)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.account_balance_wallet_rounded,
                              tooltip: 'Деньги',
                              active: activeMoneySection,
                              onTap: () async =>
                                  _openCollapsedTarget(SchetaWidget.routeName),
                            ),
                          ),
                        if (showGoods)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.inventory_2_rounded,
                              tooltip: 'Товары и склад',
                              active: activeGoodsSection,
                              onTap: () async =>
                                  _openCollapsedTarget(TovarWidget.routeName),
                            ),
                          ),
                        if (showSales)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.point_of_sale_rounded,
                              tooltip: 'Продажи',
                              active: activeSalesSection,
                              onTap: () async =>
                                  _openCollapsedTarget(ShopWidget.routeName),
                            ),
                          ),
                        if (showAnalytics)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.insights_rounded,
                              tooltip: 'Аналитика',
                              active: activeAnalyticsSection,
                              onTap: () async => _openCollapsedTarget(
                                FinOtchetWidget.routeName,
                              ),
                            ),
                          ),
                        if (showAudit)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.fact_check_outlined,
                              tooltip: 'Аудит бухучета',
                              active: _isActivePath(Audit1CWidget.routePath),
                              onTap: () async =>
                                  _openCollapsedTarget(Audit1CWidget.routeName),
                            ),
                          ),
                        if (showCompany)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.apartment_rounded,
                              tooltip: 'Компания',
                              active: activeCompanySection,
                              onTap: () async => _openCollapsedTarget(
                                OrgStructuraWidget.routeName,
                              ),
                            ),
                          ),
                        if (showSecurity)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.security_rounded,
                              tooltip: 'Безопасность',
                              active: activeSecuritySection,
                              onTap: () async => _openCollapsedTarget(
                                BlocAppsWidget.routeName,
                              ),
                            ),
                          ),
                        if (showPersonalMoney)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.account_balance_rounded,
                              tooltip: 'Личные деньги',
                              active: activePersonalSection,
                              onTap: () async =>
                                  _openCollapsedTarget(MyMoneyWidget.routeName),
                            ),
                          ),
                        if (showSettings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _collapsedRailButton(
                              icon: Icons.settings_rounded,
                              tooltip: 'Настройки',
                              active: activeSettingsSection,
                              onTap: () async => _openCollapsedTarget(
                                RekvizitiWidget.routeName,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: design.sidebarBackground,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0.0, 18.0, 0.0, 16.0),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(14.0, 0.0, 14.0, 12.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        design.surfaceColor,
                        Color.alphaBlend(
                          design.buttonColor.withValues(alpha: 0.06),
                          design.surfaceColor,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: design.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: design.buttonColor.withValues(alpha: 0.10),
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 138.0,
                        height: 54.0,
                        decoration: BoxDecoration(
                          color: design.buttonColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'UchetSD',
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.w800,
                            color: design.textColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Свернуть боковое меню',
                        child: InkWell(
                          onTap: () async {
                            FFAppState().update(() {
                              FFAppState().userSidebarCollapsed = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(12.0),
                          child: Container(
                            width: 38.0,
                            height: 38.0,
                            decoration: BoxDecoration(
                              color: design.buttonColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Icon(
                              Icons.keyboard_double_arrow_left_rounded,
                              color: design.buttonColor,
                              size: 22.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasSkippedIncompleteSteps)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      14.0, 0.0, 14.0, 12.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.0),
                    onTap: () async {
                      await context
                          .pushNamed(CompanyOnboardingWidget.routeName);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          FlutterFlowTheme.of(context)
                              .warning
                              .withValues(alpha: 0.16),
                          design.surfaceColor,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context)
                              .warning
                              .withValues(alpha: 0.65),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_add_check_circle_outlined,
                            color: FlutterFlowTheme.of(context).warning,
                            size: 22.0,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Дозаполнить данные',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: design.textColor,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                Text(
                                  'Вернуться к пропущенным блокам',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.plusJakartaSans(),
                                        color: design.mutedTextColor,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: design.mutedTextColor,
                            size: 22.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            design.surfaceColor,
                            Color.alphaBlend(
                              design.buttonColor.withValues(alpha: 0.04),
                              design.surfaceColor,
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 30.0,
                            color: design.buttonColor.withValues(alpha: 0.10),
                            offset: Offset(
                              0.0,
                              12.0,
                            ),
                          )
                        ],
                        borderRadius: BorderRadius.circular(22.0),
                        border: Border.all(
                          color: design.surfaceBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 4.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListView(
                              padding: EdgeInsets.zero,
                              primary: false,
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              children: [
                                if (showMoney)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.52),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: design.surfaceColor,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController1,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'money',
                                              controller: _model
                                                  .expandableExpandableController1,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.attach_money,
                                                    color:
                                                        _sectionAccent('money'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'win9ju05' /* Деньги компании */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'money',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_canAny([
                                                        'company.roles',
                                                        'company.users',
                                                        'company.org',
                                                        'company.hr',
                                                      ]) &&
                                                      !showCompany)
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          CompanySetupWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'companies',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                CompanySetupWidget
                                                                    .routePath),
                                                            'companies',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .apartment,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        CompanySetupWidget
                                                                            .routePath),
                                                                    'companies',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Компании',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(CompanySetupWidget.routePath),
                                                                            'companies',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'scheta.view',
                                                    'scheta.manage',
                                                    'scheta.add',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          SchetaWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'accounts',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                SchetaWidget
                                                                    .routePath),
                                                            'accounts',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .account_balance_wallet_rounded,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        SchetaWidget
                                                                            .routePath),
                                                                    'accounts',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'col4smk0' /* Счета */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(SchetaWidget.routePath),
                                                                            'accounts',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'funding_requests.create',
                                                      'funding_requests.responsible_sign',
                                                      'funding_requests.approve',
                                                      'funding_requests.final_approve',
                                                      'funding_requests.pay',
                                                    ]),
                                                    onTap: () async {
                                                      await _openMenuTarget(
                                                        FundingRequestsWidget
                                                            .routeName,
                                                      );
                                                    },
                                                    icon: Icons
                                                        .request_quote_outlined,
                                                    label: 'Заявки на деньги',
                                                    routePath:
                                                        FundingRequestsWidget
                                                            .routePath,
                                                  ),
                                                  if (_can('uchet.view'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            UchetWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color:
                                                              _menuItemBackground(
                                                            _isActivePath(
                                                              UchetWidget
                                                                  .routePath,
                                                            ),
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.apps,
                                                                  color:
                                                                      _menuItemForeground(
                                                                    _isActivePath(
                                                                      UchetWidget
                                                                          .routePath,
                                                                    ),
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            12.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                    child: Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Text(
                                                                            'Финансовый учет компании',
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                  font: GoogleFonts.plusJakartaSans(
                                                                                    fontWeight: FontWeight.w500,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                                  color: _menuItemForeground(
                                                                                    _isActivePath(UchetWidget.routePath),
                                                                                  ),
                                                                                  fontSize: 14.0,
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FontWeight.w500,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                8),
                                                                        _auditAlertBadge(),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'tranzaction.view',
                                                    'tranzaction.add',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                          TranzactionWidget
                                                              .routeName,
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color:
                                                              _menuItemBackground(
                                                            _isActivePath(
                                                                    TranzactionWidget
                                                                        .routePath) ||
                                                                _isActivePath(
                                                                  TranzactionJournalWidget
                                                                      .routePath,
                                                                ),
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .monetization_on,
                                                                  color:
                                                                      _menuItemForeground(
                                                                    _isActivePath(TranzactionWidget
                                                                            .routePath) ||
                                                                        _isActivePath(
                                                                            TranzactionJournalWidget.routePath),
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'xq19vlv6' /* Платежи */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuItemForeground(
                                                                            _isActivePath(TranzactionWidget.routePath) ||
                                                                                _isActivePath(TranzactionJournalWidget.routePath),
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                        'tranzaction.view',
                                                        'tranzaction.add',
                                                      ]) &&
                                                      showTransactionsJournal)
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                          TranzactionJournalWidget
                                                              .routeName,
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color:
                                                              _menuItemBackground(
                                                            _isActivePath(
                                                              TranzactionJournalWidget
                                                                  .routePath,
                                                            ),
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .receipt_long_rounded,
                                                                  color:
                                                                      _menuItemForeground(
                                                                    _isActivePath(
                                                                      TranzactionJournalWidget
                                                                          .routePath,
                                                                    ),
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Журнал платежей',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuItemForeground(
                                                                            _isActivePath(TranzactionJournalWidget.routePath),
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can(
                                                      'money.expense_categories'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            StatRasWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                StatRasWidget
                                                                    .routePath),
                                                            'budgets',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .trending_down,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        StatRasWidget
                                                                            .routePath),
                                                                    'budgets',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '2hdymksq' /* Статьи расходов */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(StatRasWidget.routePath),
                                                                            'budgets',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('money.obligations'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ObyazWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.055,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color:
                                                              _menuItemBackground(
                                                            _isActivePath(
                                                              ObyazWidget
                                                                  .routePath,
                                                            ),
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .clipboardList,
                                                                  color:
                                                                      _menuItemForeground(
                                                                    _isActivePath(
                                                                      ObyazWidget
                                                                          .routePath,
                                                                    ),
                                                                  ),
                                                                  size: 20.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          10.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'e74ljg33' /* Обязательства */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuItemForeground(
                                                                            _isActivePath(ObyazWidget.routePath),
                                                                          ),
                                                                          fontSize:
                                                                              13.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showPersonalMoney)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          context.pushNamed(
                                              MyMoneyWidget.routeName);
                                        },
                                        child: _sectionHeaderWrap(
                                          'personal',
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              FaIcon(
                                                FontAwesomeIcons
                                                    .solidMoneyBillAlt,
                                                color: _isActivePath(
                                                        MyMoneyWidget.routePath)
                                                    ? design
                                                        .drawerSectionActiveIconColor
                                                    : _sectionAccent(
                                                        'personal'),
                                                size: 24.0,
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 0.0, 0.0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    '0adhv4vh' /* Личные деньги */,
                                                  ),
                                                  style: _sectionTextStyle(
                                                    'personal',
                                                  ).copyWith(
                                                    color: _isActivePath(
                                                            MyMoneyWidget
                                                                .routePath)
                                                        ? design
                                                            .drawerSectionActiveTextColor
                                                        : _sectionAccent(
                                                            'personal'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (false && showAudit)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          context.pushNamed(
                                              Audit1CWidget.routeName);
                                        },
                                        child: _sectionHeaderWrap(
                                          'audit',
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Icon(
                                                Icons.fact_check_outlined,
                                                color: _isActivePath(
                                                        Audit1CWidget.routePath)
                                                    ? design
                                                        .drawerSectionActiveIconColor
                                                    : _sectionAccent('audit'),
                                                size: 24.0,
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 0.0, 0.0),
                                                child: Text(
                                                  'Аудит бухучета',
                                                  style: _sectionTextStyle(
                                                    'audit',
                                                  ).copyWith(
                                                    color: _isActivePath(
                                                            Audit1CWidget
                                                                .routePath)
                                                        ? design
                                                            .drawerSectionActiveTextColor
                                                        : _sectionAccent(
                                                            'audit'),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              _auditAlertBadge(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showAudit)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          context.pushNamed(
                                              Audit1CWidget.routeName);
                                        },
                                        child: _sectionHeaderWrap(
                                          'audit',
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Icon(
                                                Icons.fact_check_outlined,
                                                color: _isActivePath(
                                                        Audit1CWidget.routePath)
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primary
                                                    : _sectionAccent('audit'),
                                                size: 24.0,
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 0.0, 0.0),
                                                child: Text(
                                                  'Аудит бухучета',
                                                  style: _sectionTextStyle(
                                                    'audit',
                                                  ).copyWith(
                                                    color: _isActivePath(
                                                            Audit1CWidget
                                                                .routePath)
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .primary
                                                        : _sectionAccent(
                                                            'audit'),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              _auditAlertBadge(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showGoods)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController2,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'goods',
                                              controller: _model
                                                  .expandableExpandableController2,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  FaIcon(
                                                    FontAwesomeIcons.box,
                                                    color:
                                                        _sectionAccent('goods'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'd81sslj1' /* Товары */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'goods',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'warehouse.view',
                                                      'warehouse.add',
                                                      'warehouse.move',
                                                    ]),
                                                    onTap: () =>
                                                        _openMenuTarget(
                                                      ScladWidget.routeName,
                                                      onboardingStep:
                                                          'warehouses',
                                                    ),
                                                    icon: Icons
                                                        .warehouse_outlined,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      'n68sqxcn' /* Склады */,
                                                    ),
                                                    routePath:
                                                        ScladWidget.routePath,
                                                  ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'nomenclature.view',
                                                      'nomenclature.add',
                                                      'nomenclature.edit',
                                                      'nomenclature.delete',
                                                    ]),
                                                    onTap: () =>
                                                        _openMenuTarget(
                                                      TovarWidget.routeName,
                                                      onboardingStep:
                                                          'products',
                                                    ),
                                                    icon: FontAwesomeIcons.box,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      'eqoq34ua' /* Товары */,
                                                    ),
                                                    routePath:
                                                        TovarWidget.routePath,
                                                  ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'services.view',
                                                      'services.add',
                                                      'services.edit',
                                                      'services.delete',
                                                    ]),
                                                    onTap: () async {
                                                      context.pushNamed(
                                                          UslugiWidget
                                                              .routeName);
                                                    },
                                                    icon: Icons
                                                        .miscellaneous_services,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      'urs2evgn' /* Услуги */,
                                                    ),
                                                    routePath:
                                                        UslugiWidget.routePath,
                                                  ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'analytics.portfolio',
                                                      'analytics.view',
                                                    ]),
                                                    onTap: () async {
                                                      context.pushNamed(
                                                          PortProductWidget
                                                              .routeName);
                                                    },
                                                    icon: Icons.card_travel,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      '5np2lb2d' /* Портфель продуктов */,
                                                    ),
                                                    routePath: PortProductWidget
                                                        .routePath,
                                                  ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'sales.controls',
                                                      'sales.view',
                                                    ]),
                                                    onTap: () async {
                                                      context.pushNamed(
                                                          ControlsSalesWidget
                                                              .routeName);
                                                    },
                                                    icon: Icons.percent,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      '53srmciz' /* Управление скидками */,
                                                    ),
                                                    routePath:
                                                        ControlsSalesWidget
                                                            .routePath,
                                                  ),
                                                  _goodsMenuItem(
                                                    visible: _canAny([
                                                      'suppliers.view',
                                                      'suppliers.add',
                                                      'suppliers.edit',
                                                      'suppliers.delete',
                                                    ]),
                                                    onTap: () async {
                                                      context.pushNamed(
                                                          KontrAgentWidget
                                                              .routeName);
                                                    },
                                                    icon: Icons.group,
                                                    label: FFLocalizations.of(
                                                            context)
                                                        .getText(
                                                      'lw5c81d0' /* Контрагенты (Поставщики) */,
                                                    ),
                                                    routePath: KontrAgentWidget
                                                        .routePath,
                                                  ),
                                                  if (false &&
                                                      _canAny([
                                                        'nomenclature.view',
                                                        'nomenclature.add',
                                                        'nomenclature.edit',
                                                        'nomenclature.delete',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          TovarWidget.routeName,
                                                          onboardingStep:
                                                              'products',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            false,
                                                            'products',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .box,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    false,
                                                                    'products',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'eqoq34ua' /* Товары */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'analytics.portfolio',
                                                        'analytics.view',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            PortProductWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .card_travel,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '5np2lb2d' /* Портфель продуктов */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'services.view',
                                                        'services.add',
                                                        'services.edit',
                                                        'services.delete',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            UslugiWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .miscellaneous_services,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'urs2evgn' /* Услуги */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'suppliers.view',
                                                        'suppliers.add',
                                                        'suppliers.edit',
                                                        'suppliers.delete',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            KontrAgentWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.group,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'lw5c81d0' /* Контрагенты (Поставщики) */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'warehouse.view',
                                                        'warehouse.add',
                                                        'warehouse.move',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          ScladWidget.routeName,
                                                          onboardingStep:
                                                              'warehouses',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .warehouse_outlined,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'n68sqxcn' /* Склады */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'sales.controls',
                                                        'sales.view',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ControlsSalesWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.percent,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '53srmciz' /* Управление скидками */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showSales)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController3,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'sales',
                                              controller: _model
                                                  .expandableExpandableController3,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.card_travel,
                                                    color:
                                                        _sectionAccent('sales'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'up5h54fb' /* Продажи */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'sales',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_canAny([
                                                    'sales.shops',
                                                    'sales.view',
                                                    'sales.cash',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          ShopWidget.routeName,
                                                          onboardingStep:
                                                              'shops',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                TovarWidget
                                                                    .routePath),
                                                            'products',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .store,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        TovarWidget
                                                                            .routePath),
                                                                    'products',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'zliveeb8' /* Магазины */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(TovarWidget.routePath),
                                                                            'products',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.clients',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ReceivablesWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                ReceivablesWidget
                                                                    .routePath),
                                                            'sales',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.group,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        ReceivablesWidget
                                                                            .routePath),
                                                                    'sales',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Дебиторская задолженность',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(ReceivablesWidget.routePath),
                                                                            'sales',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'sales.controls',
                                                        'sales.view',
                                                        'sales.cash',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ControlsSaleWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                ShopWidget
                                                                    .routePath),
                                                            'shops',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.percent,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        ShopWidget
                                                                            .routePath),
                                                                    'shops',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '7rkhisgl' /* Управление скидками */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(ShopWidget.routePath),
                                                                            'shops',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.income',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          IncomeShopWidget
                                                              .routeName,
                                                          onboardingStep: 'org',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                OrgStructuraWidget
                                                                    .routePath),
                                                            'org',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .trending_up,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        OrgStructuraWidget
                                                                            .routePath),
                                                                    'org',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'u65lwzuz' /* Доходы магазинов */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(OrgStructuraWidget.routePath),
                                                                            'org',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.expenses',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          DecomeShopWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'employees',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                HrControlsWidget
                                                                    .routePath),
                                                            'employees',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .trending_down,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        HrControlsWidget
                                                                            .routePath),
                                                                    'employees',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'jwrsbzyt' /* Расходы магазинов */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(HrControlsWidget.routePath),
                                                                            'employees',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.profit.shop',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          PribilShopWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'roles',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                RoliWidget
                                                                    .routePath),
                                                            'roles',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .attach_money,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        RoliWidget
                                                                            .routePath),
                                                                    'roles',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            12.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                    child: Text(
                                                                      FFLocalizations.of(
                                                                              context)
                                                                          .getText(
                                                                        'vdzh89qi' /* Чистая прибыль */,
                                                                      ),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .start,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.plusJakartaSans(
                                                                              fontWeight: FontWeight.w500,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).primaryText,
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.profit.cashier',
                                                    'sales.view',
                                                    'sales.reports',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            PribilKassirWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .monetization_on_outlined,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'a10yhdor' /* Прибыль по кассирам */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(RoliWidget.routePath),
                                                                            'roles',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.controls',
                                                    'sales.view',
                                                    'sales.cash',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ControlsSaleWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                ShopWidget
                                                                    .routePath),
                                                            'shops',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.percent,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        ShopWidget
                                                                            .routePath),
                                                                    'shops',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '7rkhisgl' /* Управление скидками */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(ShopWidget.routePath),
                                                                            'shops',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.abc',
                                                    'analytics.abc',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            AbcPageSaleWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .abc_outlined,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '003diwf3' /* Заявки на закуп товаров */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'sales.clients',
                                                    'sales.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ClientWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                ScladWidget
                                                                    .routePath),
                                                            'warehouses',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.group,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        ScladWidget
                                                                            .routePath),
                                                                    'warehouses',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '2xtr8k22' /* Клиенты */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(ScladWidget.routePath),
                                                                            'warehouses',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showAnalytics)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController4,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'analytics',
                                              controller: _model
                                                  .expandableExpandableController4,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.analytics_rounded,
                                                    color: _sectionAccent(
                                                        'analytics'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'uub8snhv' /* Аналитика */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'analytics',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_canAny([
                                                    'analytics.view',
                                                    'analytics.fin',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            BalanceWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _isActivePath(
                                                                  BalanceWidget
                                                                      .routePath)
                                                              ? const Color(
                                                                  0xFFE8EEF8)
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .account_balance_wallet_rounded,
                                                                  color: _isActivePath(
                                                                          BalanceWidget
                                                                              .routePath)
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primary
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Баланс',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color: _isActivePath(BalanceWidget.routePath)
                                                                              ? design.buttonColor
                                                                              : FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'analytics.fin',
                                                    'analytics.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            FinOtchetWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .receipt,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'm8t7x50z' /* Фин отчеты */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'analytics.sales',
                                                    'analytics.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            OtchetSaleWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .report_problem_sharp,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'hvoo7blc' /* Отчеты про продажам */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'analytics.models',
                                                    'analytics.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            FinModelsWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .monetization_on,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'gaej7bmt' /* Финансовая модель */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'analytics.invest',
                                                    'analytics.view',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            InvestOtchetWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .clipboardList,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'qh40yqcp' /* Инвестиционные отчеты */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (false &&
                                                      _canAny([
                                                        'analytics.margin',
                                                        'analytics.view',
                                                      ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            MarjaWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .trending_down,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '56yajhft' /* Маржинальность */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showCompany)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController5,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'company',
                                              controller: _model
                                                  .expandableExpandableController5,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.settings_sharp,
                                                    color: _sectionAccent(
                                                        'company'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'rd83xark' /* Компания */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'company',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (canOpenCompanySetup)
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          CompanySetupWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'companies',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _menuWarnBg(
                                                            _isActivePath(
                                                                CompanySetupWidget
                                                                    .routePath),
                                                            'companies',
                                                          ),
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .business_rounded,
                                                                  color:
                                                                      _menuWarnColor(
                                                                    _isActivePath(
                                                                        CompanySetupWidget
                                                                            .routePath),
                                                                    'companies',
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Данные компании',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              _menuWarnColor(
                                                                            _isActivePath(CompanySetupWidget.routePath),
                                                                            'companies',
                                                                            FlutterFlowTheme.of(context).primaryText,
                                                                          ),
                                                                          fontSize:
                                                                              13.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('company.org'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await context.pushNamed(
                                                          OrgStructuraWidget
                                                              .routeName,
                                                          queryParameters: const {
                                                            'view': 'business'
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _isOrgViewActive(
                                                                  'business')
                                                              ? const Color(
                                                                  0xFFE8EEF8)
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .codeBranch,
                                                                  color: _isOrgViewActive(
                                                                          'business')
                                                                      ? design
                                                                          .buttonColor
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'tumlh7nq' /* Структура бизнеса */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color: _isOrgViewActive('business')
                                                                              ? design.buttonColor
                                                                              : FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              13.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('company.org'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await context.pushNamed(
                                                          OrgStructuraWidget
                                                              .routeName,
                                                          queryParameters: const {
                                                            'view': 'company'
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _isOrgViewActive(
                                                                  'company')
                                                              ? const Color(
                                                                  0xFFE8EEF8)
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .hive,
                                                                  color: _isOrgViewActive(
                                                                          'company')
                                                                      ? design
                                                                          .buttonColor
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'Орг структура компании',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color: _isOrgViewActive('company')
                                                                              ? design.buttonColor
                                                                              : FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('company.hr'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          HrControlsWidget
                                                              .routeName,
                                                          onboardingStep:
                                                              'employees',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: _isActivePath(
                                                                  HrControlsWidget
                                                                      .routePath)
                                                              ? const Color(
                                                                  0xFFE8EEF8)
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .hive,
                                                                  color: _isActivePath(
                                                                          HrControlsWidget
                                                                              .routePath)
                                                                      ? design
                                                                          .buttonColor
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    'HR контроль',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color: _isActivePath(HrControlsWidget.routePath)
                                                                              ? design.buttonColor
                                                                              : FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showSecurity)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController6,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'security',
                                              controller: _model
                                                  .expandableExpandableController6,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.security_outlined,
                                                    color: _sectionAccent(
                                                        'security'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'kipkxeux' /* Безопасность */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'security',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_can('security.block'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            BlocAppsWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .block_sharp,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'lw7rutdf' /* Блокировка приложения */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('security.delete'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            DeleteDataWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .delete_sweep,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'vaoc4lkd' /* Очистка данных */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('security.restore'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            RecoveryWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .rev,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'c0t1m2o0' /* Восстановление данных */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (false && showPersonalMoney)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.transparent,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController7,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'personal',
                                              controller: _model
                                                  .expandableExpandableController7,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  FaIcon(
                                                    FontAwesomeIcons
                                                        .solidMoneyBillAlt,
                                                    color: _sectionAccent(
                                                        'personal'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        '0adhv4vh' /* Личные деньги */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'personal',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_can('money.my'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            MyMoneyWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .account_balance_wallet_rounded,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'mjr1qv7d' /* Доходы личные */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('money.my_expenses'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            MyDecomeWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .monetization_on,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'skrptuka' /* Расходы личные */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can(
                                                      'money.company_expenses'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            MyDecomeCompWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .clipboardList,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '66juhpbh' /* Рахсоды на компанию */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showSettings)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: design.surfaceColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 0.0,
                                            color: design.surfaceBorder
                                                .withValues(alpha: 0.32),
                                            offset: Offset(
                                              0.0,
                                              1.0,
                                            ),
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: design.surfaceColor,
                                        child: ExpandableNotifier(
                                          controller: _model
                                              .expandableExpandableController8,
                                          child: ExpandablePanel(
                                            header: _expandableSectionHeader(
                                              key: 'settings',
                                              controller: _model
                                                  .expandableExpandableController8,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.settings_sharp,
                                                    color: _sectionAccent(
                                                        'settings'),
                                                    size: 24.0,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'ytgmbu9a' /* Настройки */,
                                                      ),
                                                      style: _sectionTextStyle(
                                                        'settings',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            collapsed: Container(
                                              width: 100.0,
                                              height: 1.0,
                                              decoration: BoxDecoration(
                                                color: design.surfaceBorder
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            expanded: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  if (_can(
                                                      'settings.rekviziti'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            RekvizitiWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons.domain,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '7lxep4bw' /* Реквизиты */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('settings.currency'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            ValutaWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .attach_money,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'lqpoh5ah' /* Валюта */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can('settings.taxes'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            NalogiWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .thList,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '9u77chkx' /* Налоги */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_can(
                                                      'settings.calculator'))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        context.pushNamed(
                                                            CalculatWidget
                                                                .routeName);
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .calculate_sharp,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      'l3nnwzu8' /* Калькулятор */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_canAny([
                                                    'settings.roles',
                                                    'settings.users',
                                                  ]))
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await _openMenuTarget(
                                                          RoliWidget.routeName,
                                                          onboardingStep:
                                                              'roles',
                                                        );
                                                      },
                                                      child: Container(
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height *
                                                                0.06,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                        ),
                                                        child: Card(
                                                          clipBehavior: Clip
                                                              .antiAliasWithSaveLayer,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          elevation: 2.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4.0),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        8.0,
                                                                        0.0,
                                                                        6.0,
                                                                        0.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .folderOpen,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  size: 24.0,
                                                                ),
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          12.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Text(
                                                                    FFLocalizations.of(
                                                                            context)
                                                                        .getText(
                                                                      '1ugg0mir' /* Роли */,
                                                                    ),
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
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
                                            ),
                                            theme: ExpandableThemeData(
                                              tapHeaderToExpand: true,
                                              tapBodyToExpand: false,
                                              tapBodyToCollapse: false,
                                              headerAlignment:
                                                  ExpandablePanelHeaderAlignment
                                                      .center,
                                              hasIcon: false,
                                              expandIcon:
                                                  Icons.chevron_right_rounded,
                                              collapseIcon: Icons
                                                  .keyboard_arrow_down_rounded,
                                              iconSize: 24.0,
                                              iconColor: Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    GoRouter.of(context).prepareAuthEvent();
                                    await authManager.signOut();
                                    GoRouter.of(context)
                                        .clearRedirectLocation();

                                    context.goNamedAuth(
                                        LoginWidget.routeName, context.mounted);
                                  },
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    width: double.infinity,
                                    height: 44.0,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12.0),
                                      shape: BoxShape.rectangle,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          8.0, 0.0, 6.0, 0.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Icon(
                                            Icons.login_sharp,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12.0, 0.0, 0.0, 0.0),
                                            child: Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'uyv5m01n' /* Выйти */,
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animateOnPageLoad(
                        animationsMap['containerOnPageLoadAnimation']!),
                  ],
                ),
              ),
              Divider(
                height: 12.0,
                thickness: 2.0,
                color: Color(0xFFE5E7EB),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Закрыть боковое меню',
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.keyboard_double_arrow_left_rounded,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 24.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
