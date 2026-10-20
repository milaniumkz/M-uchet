import 'main_server.dart' as independent;
import 'dart:async';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'backend/firestore_cache_rebuilder.dart';
import 'backend/backend.dart';
import '/user_design/user_design.dart';
import '/utils/browser_location.dart';
import '/utils/device_management_support.dart';
import '/utils/effective_company_support.dart';

// The default entry point uses the independently authenticated PostgreSQL API.
// Legacy widgets below remain available while their adapters are migrated.
void main() => independent.main();

class _BootstrapGateApp extends StatefulWidget {
  const _BootstrapGateApp({required this.launchUri});

  final Uri launchUri;

  @override
  State<_BootstrapGateApp> createState() => _BootstrapGateAppState();
}

class _BootstrapGateAppState extends State<_BootstrapGateApp> {
  late Future<FFAppState> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<FFAppState> _bootstrap() async {
    debugPrint('Bootstrap step: initFirebase');
    await initFirebase().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'Инициализация Firebase заняла слишком много времени.',
      ),
    );
    debugPrint('Bootstrap step: theme');
    await FlutterFlowTheme.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Инициализация темы заняла слишком много времени.',
      ),
    );
    debugPrint('Bootstrap step: app state');
    final appState = FFAppState();
    await appState.initializePersistedState().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Инициализация локального состояния заняла слишком много времени.',
          ),
        );
    debugPrint('Bootstrap step: done');
    return appState;
  }

  void _retry() {
    safeSetState(() {
      _bootstrapFuture = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FFAppState>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingApp();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          final error = snapshot.error;
          if (error != null) {
            debugPrint('Bootstrap failed: $error');
          }
          return _BootstrapErrorApp(
            message: error?.toString() ?? 'Неизвестная ошибка запуска.',
            onRetry: _retry,
          );
        }
        return ChangeNotifierProvider.value(
          value: snapshot.data!,
          child: MyApp(launchUri: widget.launchUri),
        );
      },
    );
  }
}

class _BootstrapLoadingApp extends StatelessWidget {
  const _BootstrapLoadingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFFFFBF5),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFFC9A15B),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Загрузка приложения...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F241C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Не удалось запустить приложение',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5B4B3A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A15B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.launchUri});

  final Uri launchUri;

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const MethodChannel _securityChannel =
      MethodChannel('uchetsd/security');
  static const MethodChannel _securityEventsChannel =
      MethodChannel('uchetsd/security_events');
  Locale? _locale;

  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  bool get _isAdminHost {
    final host = Uri.base.host.toLowerCase();
    return host.contains('.admin.');
  }

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});
  bool _securityRuntimeBusy = false;
  bool _secureScreenEnabled = false;
  bool _privacyShieldActive = false;
  String _lastSecurityPath = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier, initialUri: widget.launchUri);
    userStream = uchetSDFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        unawaited(_runSecurityRuntime(user));
      });
    jwtTokenStream.listen((_) {});
    _securityEventsChannel.setMethodCallHandler(_handleSecurityEvent);
    Future.delayed(
      Duration(milliseconds: 1500),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final path = _safeCurrentPath();
    if (!_isSensitivePath(path)) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final shouldShield = state != AppLifecycleState.resumed;
      if (_privacyShieldActive != shouldShield) {
        safeSetState(() => _privacyShieldActive = shouldShield);
      }
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_logSecurityEvent(
        'sensitive_screen_hidden',
        <String, dynamic>{'path': path, 'state': state.name},
      ));
    }
  }

  Future<void> _runSecurityRuntime(BaseAuthUser user) async {
    if (_securityRuntimeBusy || !user.loggedIn || user.uid == null) return;
    _securityRuntimeBusy = true;
    try {
      final companyId =
          (currentUserDocument?.idCompany ?? user.uid ?? '').toString().trim();
      final userId = (user.uid ?? '').trim();
      if (companyId.isEmpty || userId.isEmpty) return;
      await registerCurrentDevice(
        firestore: FirebaseFirestore.instance,
        companyId: companyId,
        userId: userId,
      );
      final results = await processPendingDeviceCommands(
        firestore: FirebaseFirestore.instance,
        companyId: companyId,
      );
      if (results.any((result) => result.requiresLogout)) {
        await authManager.signOut();
      }
    } catch (_) {
      // Keep startup resilient.
    } finally {
      _securityRuntimeBusy = false;
    }
  }

  String _safeCurrentPath() {
    try {
      return getRoute();
    } catch (_) {
      return '/';
    }
  }

  bool _isSensitivePath(String path) {
    return true;
  }

  Future<void> _syncSensitiveScreenProtection(String path) async {
    final shouldSecure = _isSensitivePath(path);
    if (_lastSecurityPath == path && _secureScreenEnabled == shouldSecure) {
      return;
    }
    _lastSecurityPath = path;
    if (!shouldSecure && _privacyShieldActive) {
      safeSetState(() => _privacyShieldActive = false);
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _secureScreenEnabled = shouldSecure;
      return;
    }
    if (_secureScreenEnabled == shouldSecure) return;
    _secureScreenEnabled = shouldSecure;
    try {
      await _securityChannel.invokeMethod('setSecureScreen', <String, dynamic>{
        'enabled': shouldSecure,
      });
    } catch (_) {
      // Best-effort only.
    }
    if (shouldSecure) {
      unawaited(_logSecurityEvent(
        'secure_screen_enabled',
        <String, dynamic>{'path': path},
      ));
    }
  }

  Future<void> _handleSecurityEvent(MethodCall call) async {
    if (call.method != 'screenshotTaken') return;
    await _logSecurityEvent(
      'screenshot_taken',
      <String, dynamic>{
        'path': _safeCurrentPath(),
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  Future<void> _logSecurityEvent(
    String action,
    Map<String, dynamic> details,
  ) async {
    final userId = currentUserUid;
    if (userId.isEmpty) return;
    final companyId = resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: userId,
    );
    if (companyId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('activity_log').add({
        'idCompany': companyId,
        'user_id': userId,
        'user_name': currentUserDocument?.displayName ?? currentUserEmail ?? '',
        'action': action,
        'entity': 'security_screen',
        'details': details,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void dispose() {
    authUserSub.cancel();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        if (_isAdminHost) {
          _themeMode = ThemeMode.dark;
          return;
        }
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  bool _shouldApplyUserDesign(String path) {
    const excludedPrefixes = <String>{
      '/login',
      '/regPage',
      '/regPageDirector',
      '/homeAdmin',
      '/superAdmin',
      '/companyAdmin',
      '/usersAdmin',
      '/tarifAdmin',
      '/bilingAdmin',
      '/analitikaAdmin',
      '/supportAdmin',
      '/marketingAdmin',
      '/statPageAdmin',
      '/secruritiAdmin',
      '/settingAdmin',
      '/designAdmin',
    };
    return !excludedPrefixes.any(
      (prefix) => path == prefix || path.startsWith('$prefix/'),
    );
  }

  Widget _buildDeviceStateGuard() {
    final deviceStatus = FFAppState()
            .prefs
            ?.getString('ff_device_status')
            ?.trim()
            .toUpperCase() ??
        '';
    if (deviceStatus != DeviceStatus.blocked.storageValue &&
        deviceStatus != DeviceStatus.wiped.storageValue) {
      return const SizedBox.shrink();
    }
    final blockedTitle = deviceStatus == DeviceStatus.wiped.storageValue
        ? 'Данные удалены'
        : 'Устройство заблокировано';
    final blockedBody = deviceStatus == DeviceStatus.wiped.storageValue
        ? 'Локальные данные стерты. Требуется повторная настройка и вход.'
        : 'Доступ к приложению временно заблокирован удаленной командой.';
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phonelink_lock_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                blockedTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                blockedBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) => FirestoreCacheRebuilder(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'UchetSD',
          scrollBehavior: MyAppScrollBehavior(),
          localizationsDelegates: [
            FFLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FallbackMaterialLocalizationDelegate(),
            FallbackCupertinoLocalizationDelegate(),
          ],
          locale: _locale,
          supportedLocales: const [
            Locale('ru'),
            Locale('kk'),
            Locale('uz'),
          ],
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: false,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: false,
          ),
          themeMode: _isAdminHost ? ThemeMode.dark : _themeMode,
          builder: (context, child) {
            final deviceGuard = _buildDeviceStateGuard();
            if (deviceGuard is! SizedBox) {
              return deviceGuard;
            }
            final routedChild = child ?? const SizedBox.shrink();
            final path = _safeCurrentPath();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_syncSensitiveScreenProtection(path));
            });
            final content = !_shouldApplyUserDesign(path)
                ? routedChild
                : UserDesignTheme(
                    child: UserScaffoldBackground(
                      child: routedChild,
                    ),
                  );
            return Stack(
              children: [
                Positioned.fill(child: content),
                if (_privacyShieldActive)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ),
              ],
            );
          },
          routerConfig: _router,
        ),
      ),
    );
  }
}
