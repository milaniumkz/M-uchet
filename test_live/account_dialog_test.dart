import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/account_dialog.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'account form keeps session after wrong current password and revokes all sessions on a successful change',
    (tester) async {
      final fixture =
          jsonDecode(
                File(
                  Platform.environment['MUCHET_TEST_FIXTURE']!,
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      BackendClient client() => BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: HttpOverrides.runWithHttpOverrides(
          () => IOClient(HttpClient()),
          RealNetwork(),
        ),
      );
      final api = client(), other = client();
      const login = 'synthetic-account-form@example.test',
          oldPassword = 'SYNTHETIC current password',
          newPassword = 'SYNTHETIC changed password';
      await tester.runAsync(() async {
        await api.request(
          'POST',
          ['v1', 'auth', 'register'],
          authenticated: false,
          body: {
            'login': login,
            'name': 'SYNTHETIC ACCOUNT',
            'password': oldPassword,
          },
        );
        await IdentityRepository(api).login(login, oldPassword);
        await IdentityRepository(other).login(login, oldPassword);
      });
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => AccountDialog(api: api),
                  );
                },
                child: const Text('Открыть аккаунт'),
              ),
            ),
          ),
        ),
      );
      Future<void> click(String text) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(text));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        await tester.enterText(find.widgetWithText(TextField, label), value);
        await tester.pump();
      }

      await click('Открыть аккаунт');
      await fill('Текущий пароль', 'incorrect current password');
      await fill('Новый пароль', newPassword);
      await fill('Повторите новый пароль', newPassword);
      await click('Сменить пароль');
      expect(find.text('Текущий пароль указан неверно.'), findsOneWidget);
      expect(api.authenticated, isTrue);
      await tester.runAsync(() async {
        expect(
          jsonObject(await api.request('GET', ['v1', 'auth', 'me']))['login'],
          login,
        );
      });
      await fill('Текущий пароль', oldPassword);
      await click('Сменить пароль');
      expect(result, 'changed');
      await tester.runAsync(() async {
        await expectLater(
          api.request('GET', ['v1', 'auth', 'me']),
          throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 401),
          ),
        );
        await expectLater(
          other.request('GET', ['v1', 'auth', 'me']),
          throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 401),
          ),
        );
        await IdentityRepository(api).login(login, newPassword);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
      other.close();
    },
  );
}
