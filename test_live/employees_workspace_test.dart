import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/employees_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real employee UI creates, searches and corrects salary with private history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture =
          jsonDecode(
                File(
                  Platform.environment['MUCHET_TEST_FIXTURE']!,
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final transport = HttpOverrides.runWithHttpOverrides(
        () => IOClient(HttpClient()),
        RealNetwork(),
      );
      final api = BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: transport,
      );
      late String companyId;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        final company = jsonObject(
          await api.request(
            'POST',
            ['v1', 'companies'],
            body: {'name': 'SYNTHETIC EMPLOYEE UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeesWorkspace(
              api: api,
              companyId: companyId,
              currency: 'KZT',
              projects: const [],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 450)),
      );
      await tester.pumpAndSettle();
      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pump();
      }

      await click(find.text('Добавить сотрудника'));
      await fill('ФИО', 'SYNTHETIC UI EMPLOYEE');
      await fill('ИИН, 12 цифр', '000000000001');
      await fill('Должность', 'SYNTHETIC DEVELOPER');
      await fill('Дата приёма YYYY-MM-DD', '2026-01-01');
      await fill('Дата рождения YYYY-MM-DD', '1990-01-01');
      await fill('Оклад до удержаний, KZT', '345678.90');
      await click(find.text('Сохранить сотрудника'));
      expect(find.text('SYNTHETIC UI EMPLOYEE'), findsOneWidget);
      await click(find.text('SYNTHETIC UI EMPLOYEE'));
      await fill('Оклад до удержаний, KZT', '350000.00');
      await click(find.text('Сохранить сотрудника'));
      await click(find.text('SYNTHETIC UI EMPLOYEE'));
      expect(find.text('История изменений: 1'), findsOneWidget);
      await click(find.text('Отмена'));
      await tester.runAsync(() async {
        final data = jsonObject(
          await api.request(
            'GET',
            ['v1', 'companies', companyId, 'employees'],
            query: {'q': 'DEVELOPER'},
          ),
        );
        final employee = jsonObject((data['items'] as List).single);
        expect(employee['gross_base'], 35000000);
        expect(employee['version'], 2);
      });
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
