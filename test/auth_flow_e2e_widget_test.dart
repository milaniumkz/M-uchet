import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uchet_s_d/auth/login/login_widget.dart';
import 'package:uchet_s_d/auth/reg_page/reg_page_widget.dart';
import 'package:uchet_s_d/app_state.dart';
import 'package:uchet_s_d/flutter_flow/internationalization.dart';

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final appState = FFAppState();
  await appState.initializePersistedState();

  await tester.pumpWidget(
    ChangeNotifierProvider<FFAppState>.value(
      value: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FallbackMaterialLocalizationDelegate(),
          FallbackCupertinoLocalizationDelegate(),
        ],
        supportedLocales: const [
          Locale('ru'),
          Locale('kk'),
          Locale('uz'),
        ],
        home: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Auth E2E Widget Flow', () {
    testWidgets('Login screen renders required controls',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const LoginWidget());

      expect(find.text('Добро пожаловать'), findsOneWidget);
      expect(find.text('Войдите в аккаунт'), findsOneWidget);
      expect(find.text('Телефон или email'), findsOneWidget);
      expect(find.text('Пароль'), findsOneWidget);
      expect(find.text('Войти'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('Login validates empty phone', (WidgetTester tester) async {
      await _pumpScreen(tester, const LoginWidget());

      await tester.tap(find.text('Войти'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Введите номер телефона'), findsOneWidget);
      expect(find.text('Ok'), findsOneWidget);
    });

    testWidgets('Login validates empty password', (WidgetTester tester) async {
      await _pumpScreen(tester, const LoginWidget());

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.first, '7011234567');
      await tester.tap(find.text('Войти'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Введите пароль'), findsOneWidget);
    });

    testWidgets('Registration screen smoke', (WidgetTester tester) async {
      await _pumpScreen(tester, const RegPageWidget());

      expect(find.text('Добро пожаловать'), findsOneWidget);
      expect(find.text('Создайте аккаунт'), findsOneWidget);
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });
  });
}
