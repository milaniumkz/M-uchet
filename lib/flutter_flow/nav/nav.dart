import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/utils/access_rules.dart';
import '/utils/browser_location.dart';

import '/auth/base_auth_user_provider.dart';

import '/main.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

bool _needsOnboarding() {
  final userDoc = currentUserDocument;
  if (userDoc == null) return false;
  final docUid = userDoc.uid.trim().isNotEmpty
      ? userDoc.uid.trim()
      : userDoc.reference.id.trim();
  return AccessRules.needsOnboarding(
    authUid: currentUserUid,
    userDocUid: docUid,
    role: userDoc.role,
    onboardingComplete: userDoc.snapshotData['onboarding_complete'] == true,
  );
}

bool _isOnboardingAllowedPath(String path) {
  final allowed = <String>{
    CompanyOnboardingWidget.routePath,
    CompanySetupWidget.routePath,
    SchetaWidget.routePath,
    ObyazWidget.routePath,
    ScladWidget.routePath,
    ShopWidget.routePath,
    TovarWidget.routePath,
    StatRasWidget.routePath,
    LoginWidget.routePath,
    RegPageWidget.routePath,
  };
  return AccessRules.isOnboardingAllowedPath(path, allowedPaths: allowed);
}

bool _isAuthEntryPath(String path) {
  return path == LoginWidget.routePath ||
      path == LoginWidget.adminRoutePath ||
      path == RegPageWidget.routePath ||
      path == RegPageDirectorWidget.routePath;
}

String _resolvePostAuthPath() {
  final userDoc = currentUserDocument;
  final role = valueOrDefault<String>(
    userDoc?.role,
    FFAppState().role,
  ).trim();
  if (AccessRules.isAdminRole(role)) {
    return _isAdminHost()
        ? SuperAdminWidget.routePath
        : HomeAdminWidget.routePath;
  }
  final companyId = valueOrDefault<String>(userDoc?.idCompany, '').trim();
  final pendingRole =
      (FFAppState().prefs?.getString('ff_pending_signup_role') ?? '').trim();

  if (_needsOnboarding() ||
      role == 'owner' ||
      pendingRole == 'owner' ||
      companyId.isEmpty) {
    return CompanySetupWidget.routePath;
  }
  return HomeWidget.routePath;
}

bool _isAdminUserData(Map<String, dynamic> data) {
  return AccessRules.isAdminUserData(data);
}

bool _pathEqualsOrNested(String currentPath, String routePath) {
  final current = currentPath.trim();
  final route = routePath.trim();
  return current == route || current.startsWith('$route/');
}

final Set<String> _adminRoutePaths = {
  HomeAdminWidget.routePath,
  SuperAdminWidget.routePath,
  CompanyAdminWidget.routePath,
  UsersAdminWidget.routePath,
  TarifAdminWidget.routePath,
  BilingAdminWidget.routePath,
  AnalitikaAdminWidget.routePath,
  SupportAdminWidget.routePath,
  MarketingAdminWidget.routePath,
  StatPageAdminWidget.routePath,
  SecruritiAdminWidget.routePath,
  SettingAdminWidget.routePath,
  DesignAdminWidget.routePath,
};

bool _isAdminHost() {
  final host = currentBrowserUri().host.toLowerCase();
  return host.contains('.admin.');
}

String _initialLocationFromUriBase([Uri? initialUri]) {
  final uri = initialUri ?? currentBrowserUri();
  final path = uri.path.trim().isEmpty ? '/' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  return '$path$query';
}

final List<MapEntry<String, String>> _routePermissions = [
  MapEntry(SchetaWidget.routePath, 'scheta.manage'),
  MapEntry(FundingRequestsWidget.routePath, 'funding_requests.view'),
  MapEntry(FundingRequestsWidget.routePath, 'funding_requests.create'),
  MapEntry(
      FundingRequestsWidget.routePath, 'funding_requests.responsible_sign'),
  MapEntry(FundingRequestsWidget.routePath, 'funding_requests.approve'),
  MapEntry(FundingRequestsWidget.routePath, 'funding_requests.final_approve'),
  MapEntry(FundingRequestsWidget.routePath, 'funding_requests.pay'),
  MapEntry(UchetWidget.routePath, 'uchet.view'),
  MapEntry(TranzactionWidget.routePath, 'tranzaction.view'),
  MapEntry(TranzactionJournalWidget.routePath, 'tranzaction.view'),
  MapEntry(ObyazWidget.routePath, 'money.obligations'),
  MapEntry(StatRasWidget.routePath, 'money.expense_categories'),
  MapEntry(TovarWidget.routePath, 'nomenclature.view'),
  MapEntry(PortProductWidget.routePath, 'analytics.portfolio'),
  MapEntry(UslugiWidget.routePath, 'services.view'),
  MapEntry(KontrAgentWidget.routePath, 'suppliers.view'),
  MapEntry(ScladWidget.routePath, 'warehouse.view'),
  MapEntry(ControlsSaleWidget.routePath, 'sales.controls'),
  MapEntry(ShopWidget.routePath, 'sales.shops'),
  MapEntry(ShopWidget.routePath, 'sales.cash'),
  MapEntry(ClientWidget.routePath, 'sales.clients'),
  MapEntry(ReceivablesWidget.routePath, 'sales.clients'),
  MapEntry(ControlsSalesWidget.routePath, 'sales.controls'),
  MapEntry(ControlsSalesWidget.routePath, 'sales.cash'),
  MapEntry(IncomeShopWidget.routePath, 'sales.view'),
  MapEntry(DecomeShopWidget.routePath, 'sales.view'),
  MapEntry(PribilShopWidget.routePath, 'sales.view'),
  MapEntry(PribilKassirWidget.routePath, 'sales.view'),
  MapEntry(PribilKassirWidget.routePath, 'sales.reports'),
  MapEntry(AbcPageSaleWidget.routePath, 'analytics.abc'),
  MapEntry(BalanceWidget.routePath, 'analytics.fin'),
  MapEntry(FinOtchetWidget.routePath, 'analytics.fin'),
  MapEntry(OtchetSaleWidget.routePath, 'analytics.sales'),
  MapEntry(FinModelsWidget.routePath, 'analytics.models'),
  MapEntry(InvestOtchetWidget.routePath, 'analytics.invest'),
  MapEntry(MarjaWidget.routePath, 'analytics.margin'),
  MapEntry(Audit1CWidget.routePath, 'audit.view'),
  MapEntry(OrgStructuraWidget.routePath, 'company.org'),
  MapEntry(HrControlsWidget.routePath, 'company.hr'),
  MapEntry(BlocAppsWidget.routePath, 'security.block'),
  MapEntry(DeleteDataWidget.routePath, 'security.delete'),
  MapEntry(RecoveryWidget.routePath, 'security.restore'),
  MapEntry(MyMoneyWidget.routePath, 'money.my'),
  MapEntry(MyMoneyCompWidget.routePath, 'money.company'),
  MapEntry(MyDecomeWidget.routePath, 'money.my_expenses'),
  MapEntry(MyDecomeCompWidget.routePath, 'money.company_expenses'),
  MapEntry(RekvizitiWidget.routePath, 'settings.rekviziti'),
  MapEntry(RoliWidget.routePath, 'settings.roles'),
  MapEntry(NalogiWidget.routePath, 'settings.taxes'),
  MapEntry(ValutaWidget.routePath, 'settings.currency'),
  MapEntry(CalculatWidget.routePath, 'settings.calculator'),
];

List<String> _permissionsForPath(String path) {
  final keys = <String>[];
  for (final entry in _routePermissions) {
    if (_pathEqualsOrNested(path, entry.key)) {
      keys.add(entry.value);
    }
  }
  return keys;
}

bool _isAdminPath(String path) {
  for (final routePath in _adminRoutePaths) {
    if (_pathEqualsOrNested(path, routePath)) return true;
  }
  return false;
}

String _firstAllowedPathForUser(Map<String, dynamic> data) {
  for (final entry in _routePermissions) {
    if (AccessRules.hasPermission(
      data: data,
      permissionKey: entry.value,
    )) {
      return entry.key;
    }
  }
  return HomeWidget.routePath;
}

GoRouter createRouter(
  AppStateNotifier appStateNotifier, {
  Uri? initialUri,
}) =>
    GoRouter(
      initialLocation: _initialLocationFromUriBase(initialUri),
      overridePlatformDefaultLocation: true,
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) => appStateNotifier.loggedIn
          ? (_isAdminHost() ? const SuperAdminWidget() : HomeWidget())
          : LoginWidget(adminMode: _isAdminHost()),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => appStateNotifier.loggedIn
              ? (_isAdminHost() ? const SuperAdminWidget() : HomeWidget())
              : LoginWidget(adminMode: _isAdminHost()),
        ),
        FFRoute(
          name: HomeWidget.routeName,
          path: HomeWidget.routePath,
          builder: (context, params) => HomeWidget(),
        ),
        FFRoute(
          name: LoginWidget.routeName,
          path: LoginWidget.routePath,
          builder: (context, params) => LoginWidget(),
        ),
        FFRoute(
          name: LoginWidget.adminRouteName,
          path: LoginWidget.adminRoutePath,
          builder: (context, params) => LoginWidget(adminMode: true),
        ),
        FFRoute(
          name: RegPageWidget.routeName,
          path: RegPageWidget.routePath,
          builder: (context, params) => RegPageWidget(),
        ),
        FFRoute(
          name: RegPageDirectorWidget.routeName,
          path: RegPageDirectorWidget.routePath,
          builder: (context, params) => RegPageDirectorWidget(),
        ),
        FFRoute(
          name: CompanySetupWidget.routeName,
          path: CompanySetupWidget.routePath,
          builder: (context, params) => CompanySetupWidget(),
        ),
        FFRoute(
          name: CompanyOnboardingWidget.routeName,
          path: CompanyOnboardingWidget.routePath,
          builder: (context, params) => const CompanyOnboardingWidget(),
        ),
        FFRoute(
          name: HomeAdminWidget.routeName,
          path: HomeAdminWidget.routePath,
          builder: (context, params) => HomeAdminWidget(),
        ),
        FFRoute(
          name: SuperAdminWidget.routeName,
          path: SuperAdminWidget.routePath,
          builder: (context, params) => SuperAdminWidget(),
        ),
        FFRoute(
          name: CompanyAdminWidget.routeName,
          path: CompanyAdminWidget.routePath,
          builder: (context, params) => CompanyAdminWidget(),
        ),
        FFRoute(
          name: UsersAdminWidget.routeName,
          path: UsersAdminWidget.routePath,
          builder: (context, params) => UsersAdminWidget(),
        ),
        FFRoute(
          name: TarifAdminWidget.routeName,
          path: TarifAdminWidget.routePath,
          builder: (context, params) => TarifAdminWidget(),
        ),
        FFRoute(
          name: BilingAdminWidget.routeName,
          path: BilingAdminWidget.routePath,
          builder: (context, params) => BilingAdminWidget(),
        ),
        FFRoute(
          name: AnalitikaAdminWidget.routeName,
          path: AnalitikaAdminWidget.routePath,
          builder: (context, params) => AnalitikaAdminWidget(),
        ),
        FFRoute(
          name: SupportAdminWidget.routeName,
          path: SupportAdminWidget.routePath,
          builder: (context, params) => SupportAdminWidget(),
        ),
        FFRoute(
          name: MarketingAdminWidget.routeName,
          path: MarketingAdminWidget.routePath,
          builder: (context, params) => MarketingAdminWidget(),
        ),
        FFRoute(
          name: StatPageAdminWidget.routeName,
          path: StatPageAdminWidget.routePath,
          builder: (context, params) => StatPageAdminWidget(),
        ),
        FFRoute(
          name: SecruritiAdminWidget.routeName,
          path: SecruritiAdminWidget.routePath,
          builder: (context, params) => SecruritiAdminWidget(),
        ),
        FFRoute(
          name: SettingAdminWidget.routeName,
          path: SettingAdminWidget.routePath,
          builder: (context, params) => SettingAdminWidget(),
        ),
        FFRoute(
          name: DesignAdminWidget.routeName,
          path: DesignAdminWidget.routePath,
          builder: (context, params) => DesignAdminWidget(),
        ),
        FFRoute(
          name: SchetaWidget.routeName,
          path: SchetaWidget.routePath,
          builder: (context, params) => SchetaWidget(),
        ),
        FFRoute(
          name: FundingRequestsWidget.routeName,
          path: FundingRequestsWidget.routePath,
          builder: (context, params) => FundingRequestsWidget(),
        ),
        FFRoute(
          name: UchetWidget.routeName,
          path: UchetWidget.routePath,
          builder: (context, params) => UchetWidget(),
        ),
        FFRoute(
          name: BalanceWidget.routeName,
          path: BalanceWidget.routePath,
          builder: (context, params) => BalanceWidget(),
        ),
        FFRoute(
          name: TranzactionWidget.routeName,
          path: TranzactionWidget.routePath,
          builder: (context, params) =>
              TranzactionWidget(initialFilters: params.queryParameters),
        ),
        FFRoute(
          name: TranzactionJournalWidget.routeName,
          path: TranzactionJournalWidget.routePath,
          builder: (context, params) =>
              TranzactionJournalWidget(initialFilters: params.queryParameters),
        ),
        FFRoute(
          name: ObyazWidget.routeName,
          path: ObyazWidget.routePath,
          builder: (context, params) => ObyazWidget(),
        ),
        FFRoute(
          name: StatRasWidget.routeName,
          path: StatRasWidget.routePath,
          builder: (context, params) => StatRasWidget(),
        ),
        FFRoute(
          name: Audit1CWidget.routeName,
          path: Audit1CWidget.routePath,
          builder: (context, params) => Audit1CWidget(),
        ),
        FFRoute(
          name: TovarWidget.routeName,
          path: TovarWidget.routePath,
          builder: (context, params) => TovarWidget(),
        ),
        FFRoute(
          name: PortProductWidget.routeName,
          path: PortProductWidget.routePath,
          builder: (context, params) => PortProductWidget(),
        ),
        FFRoute(
          name: UslugiWidget.routeName,
          path: UslugiWidget.routePath,
          builder: (context, params) => UslugiWidget(),
        ),
        FFRoute(
          name: KontrAgentWidget.routeName,
          path: KontrAgentWidget.routePath,
          builder: (context, params) => KontrAgentWidget(),
        ),
        FFRoute(
          name: ScladWidget.routeName,
          path: ScladWidget.routePath,
          builder: (context, params) => ScladWidget(),
        ),
        FFRoute(
          name: ControlsSaleWidget.routeName,
          path: ControlsSaleWidget.routePath,
          builder: (context, params) => ControlsSaleWidget(),
        ),
        FFRoute(
          name: ShopWidget.routeName,
          path: ShopWidget.routePath,
          builder: (context, params) => ShopWidget(),
        ),
        FFRoute(
          name: ClientWidget.routeName,
          path: ClientWidget.routePath,
          builder: (context, params) => ClientWidget(),
        ),
        FFRoute(
          name: ReceivablesWidget.routeName,
          path: ReceivablesWidget.routePath,
          builder: (context, params) => ReceivablesWidget(),
        ),
        FFRoute(
          name: ControlsSalesWidget.routeName,
          path: ControlsSalesWidget.routePath,
          builder: (context, params) => ControlsSalesWidget(),
        ),
        FFRoute(
          name: IncomeShopWidget.routeName,
          path: IncomeShopWidget.routePath,
          builder: (context, params) => IncomeShopWidget(),
        ),
        FFRoute(
          name: DecomeShopWidget.routeName,
          path: DecomeShopWidget.routePath,
          builder: (context, params) => DecomeShopWidget(),
        ),
        FFRoute(
          name: PribilShopWidget.routeName,
          path: PribilShopWidget.routePath,
          builder: (context, params) => PribilShopWidget(),
        ),
        FFRoute(
          name: PribilKassirWidget.routeName,
          path: PribilKassirWidget.routePath,
          builder: (context, params) => PribilKassirWidget(),
        ),
        FFRoute(
          name: AbcPageSaleWidget.routeName,
          path: AbcPageSaleWidget.routePath,
          builder: (context, params) => AbcPageSaleWidget(),
        ),
        FFRoute(
          name: FinOtchetWidget.routeName,
          path: FinOtchetWidget.routePath,
          builder: (context, params) => FinOtchetWidget(),
        ),
        FFRoute(
          name: OtchetSaleWidget.routeName,
          path: OtchetSaleWidget.routePath,
          builder: (context, params) => OtchetSaleWidget(),
        ),
        FFRoute(
          name: FinModelsWidget.routeName,
          path: FinModelsWidget.routePath,
          builder: (context, params) => FinModelsWidget(),
        ),
        FFRoute(
          name: InvestOtchetWidget.routeName,
          path: InvestOtchetWidget.routePath,
          builder: (context, params) => InvestOtchetWidget(),
        ),
        FFRoute(
          name: MarjaWidget.routeName,
          path: MarjaWidget.routePath,
          builder: (context, params) => MarjaWidget(),
        ),
        FFRoute(
          name: OrgStructuraWidget.routeName,
          path: OrgStructuraWidget.routePath,
          builder: (context, params) => OrgStructuraWidget(),
        ),
        FFRoute(
          name: HrControlsWidget.routeName,
          path: HrControlsWidget.routePath,
          builder: (context, params) => HrControlsWidget(),
        ),
        FFRoute(
          name: BlocAppsWidget.routeName,
          path: BlocAppsWidget.routePath,
          builder: (context, params) => BlocAppsWidget(),
        ),
        FFRoute(
          name: DeleteDataWidget.routeName,
          path: DeleteDataWidget.routePath,
          builder: (context, params) => DeleteDataWidget(),
        ),
        FFRoute(
          name: RecoveryWidget.routeName,
          path: RecoveryWidget.routePath,
          builder: (context, params) => RecoveryWidget(),
        ),
        FFRoute(
          name: MyMoneyWidget.routeName,
          path: MyMoneyWidget.routePath,
          builder: (context, params) => MyMoneyWidget(),
        ),
        FFRoute(
          name: MyMoneyCompWidget.routeName,
          path: MyMoneyCompWidget.routePath,
          builder: (context, params) => MyMoneyCompWidget(),
        ),
        FFRoute(
          name: MyDecomeWidget.routeName,
          path: MyDecomeWidget.routePath,
          builder: (context, params) => MyDecomeWidget(),
        ),
        FFRoute(
          name: MyDecomeCompWidget.routeName,
          path: MyDecomeCompWidget.routePath,
          builder: (context, params) => MyDecomeCompWidget(),
        ),
        FFRoute(
          name: RekvizitiWidget.routeName,
          path: RekvizitiWidget.routePath,
          builder: (context, params) => RekvizitiWidget(),
        ),
        FFRoute(
          name: RoliWidget.routeName,
          path: RoliWidget.routePath,
          builder: (context, params) => RoliWidget(),
        ),
        FFRoute(
          name: NalogiWidget.routeName,
          path: NalogiWidget.routePath,
          builder: (context, params) => NalogiWidget(),
        ),
        FFRoute(
          name: ValutaWidget.routeName,
          path: ValutaWidget.routePath,
          builder: (context, params) => ValutaWidget(),
        ),
        FFRoute(
          name: CalculatWidget.routeName,
          path: CalculatWidget.routePath,
          builder: (context, params) => CalculatWidget(),
        ),
        FFRoute(
          name: AddPinCodeWidget.routeName,
          path: AddPinCodeWidget.routePath,
          builder: (context, params) => AddPinCodeWidget(),
        )
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  Map<String, String> get queryParameters => state.uri.queryParameters;

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login';
          }

          if (appStateNotifier.loggedIn) {
            final userDoc = currentUserDocument;
            final path = state.uri.path;
            if (_isAuthEntryPath(path)) {
              final target = _resolvePostAuthPath();
              if (target != path) return target;
            }
            final permissionKeys = _permissionsForPath(path);
            if (userDoc != null) {
              final data = userDoc.snapshotData;

              if (_isAdminPath(path) && !_isAdminUserData(data)) {
                return HomeWidget.routePath;
              }

              if (permissionKeys.isNotEmpty &&
                  !permissionKeys.any(
                    (permissionKey) => AccessRules.hasPermission(
                      data: data,
                      permissionKey: permissionKey,
                    ),
                  )) {
                final fallbackPath = HomeWidget.routePath;
                if (fallbackPath != path) return fallbackPath;
              }
            }
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Container(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  child: Center(
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      size: 72,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  ),
                )
              : page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
