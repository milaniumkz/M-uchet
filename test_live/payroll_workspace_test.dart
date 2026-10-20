import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/payroll_workspace.dart';
import 'package:uchet_s_d/workspace/payroll_pdf.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real payroll UI posts, pays and corrects payroll with dated salary payments, history and a payslip',
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
      final api = BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: HttpOverrides.runWithHttpOverrides(
          () => IOClient(HttpClient()),
          RealNetwork(),
        ),
      );
      late String companyId;
      late List<Map<String, dynamic>> projects;
      Future<Map<String, dynamic>> post(
        List<String> path,
        Map<String, dynamic> body,
      ) async => jsonObject(
        await api.request('POST', path, body: body, operation: OperationKey()),
      );
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        companyId =
            (await post(
                  ['v1', 'companies'],
                  {'name': 'SYNTHETIC PAYROLL UI FIRM', 'currency': 'KZT'},
                ))['id']
                as String;
        final base = ['v1', 'companies', companyId];
        await api.request(
          'PUT',
          [...base, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC PAYROLL FIRM',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
        projects = [
          await post([...base, 'projects'], {'name': 'SYNTHETIC PAYROLL A'}),
          await post([...base, 'projects'], {'name': 'SYNTHETIC PAYROLL B'}),
        ];
        await post(
          [...base, 'employees'],
          {
            'name': 'SYNTHETIC SALARY EMPLOYEE',
            'identifier': '000000000001',
            'jobTitle': 'SYNTHETIC JOB',
            'hireDate': '2025-01-01',
            'birthDate': '1990-01-01',
            'grossBase': 30000000,
            'projectId': projects[0]['id'],
            'status': 'ACTIVE',
            'resident': true,
            'citizenship': 'KZ',
            'sex': 'M',
            'standardDeductionDeclaration': true,
          },
        );
        final wallet = await post(
          [...base, 'wallets'],
          {'name': 'SYNTHETIC SALARY BANK'},
        );
        await post(
          [...base, 'wallets', wallet['id'] as String, 'transactions'],
          {
            'type': 'CAPITAL',
            'amount': 100000000,
            'description': 'SYNTHETIC SALARY FUNDS',
          },
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PayrollWorkspace(
              api: api,
              companyId: companyId,
              currency: 'KZT',
              projects: projects,
              onChanged: () async {},
              onEmployees: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 650)),
      );
      await tester.pumpAndSettle();
      Future<void> click(Finder f) async {
        await tester.ensureVisible(f);
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 650));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      await fill('Месяц YYYY-MM', '2026-01');
      await click(find.text('Показать месяц'));
      await click(find.text('Табель и начисления проверены'));
      await click(find.text('Рассчитать'));
      await click(find.text('Проверены обычная зарплата и один работодатель'));
      await click(find.text('Зафиксировать политику точности расчёта'));
      await click(find.text('Рассчитать и проверить'));
      expect(find.text('К выплате: 250 575,00 ₸'), findsOneWidget);
      await click(find.text('Сохранить черновик зарплаты'));
      await click(find.text('Провести зарплату'));
      await click(find.text('Внести выплату зарплаты'));
      await fill('Дата выплаты YYYY-MM-DD', '2026-02-05');
      await click(find.text('Учесть выплату зарплаты'));
      await click(find.text('Изменить начисление'));
      await fill('Начислено до удержаний, KZT', '200000.00');
      await fill(
        'Причина изменения зарплаты',
        'SYNTHETIC PAYROLL UI CORRECTION',
      );
      await click(
        find.widgetWithText(DropdownButtonFormField<String>, 'Проект расходов'),
      );
      await click(find.text('SYNTHETIC PAYROLL B').last);
      await click(find.text('Рассчитать и проверить'));
      await click(find.text('Сохранить изменение зарплаты'));
      expect(
        find.textContaining('Аванс сотруднику: 79 200,00 ₸'),
        findsOneWidget,
      );
      await click(find.text('Исправить выплату'));
      await fill('Сумма выплаты, KZT', '170000.00');
      await fill(
        'Причина исправления выплаты',
        'SYNTHETIC PAYOUT UI CORRECTION',
      );
      await click(find.text('Сохранить выплату зарплаты'));
      await click(find.text('Отменить запись выплаты'));
      expect(find.text('Запись выплаты отменена'), findsOneWidget);
      await click(find.text('Восстановить запись выплаты'));
      await click(find.text('История выплаты'));
      expect(
        find.textContaining('SYNTHETIC PAYOUT UI CORRECTION'),
        findsOneWidget,
      );
      await click(find.text('Закрыть историю выплаты'));
      await click(find.text('Отменить начисление'));
      expect(
        find.textContaining('Аванс сотруднику: 170 000,00 ₸'),
        findsOneWidget,
      );
      await click(find.text('Восстановить начисление'));
      await tester.runAsync(() async {
        final base = ['v1', 'companies', companyId],
            data = jsonObject(
              await api.request(
                'GET',
                [...base, 'payroll'],
                query: {'month': '2026-01'},
              ),
            ),
            row = jsonObject((data['items'] as List).single);
        expect(jsonObject(row['data'])['calculation']['net'], 17137500);
        expect(row['paid'], 17000000);
        expect(row['outstanding'], 137500);
        final wallets = jsonObject(
          await api.request('GET', [...base, 'wallets']),
        );
        expect(
          jsonObject((wallets['items'] as List).single)['balance'],
          83000000,
        );
        final pdf = await payrollPdf(row, 'KZT');
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
        expect(pdf.length, greaterThan(10000));
        final report = jsonObject(
          await api.request('GET', [...base, 'reports', 'projects']),
        );
        expect(
          (report['items'] as List)
              .map(jsonObject)
              .firstWhere(
                (r) => r['projectId'] == projects[1]['id'],
              )['expenses'],
          23256000,
        );
      });
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await click(find.text('Закрыть начисление'));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1440, 960);
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await post(
          ['v1', 'companies', companyId, 'employees'],
          {
            'name': 'SYNTHETIC OPENING EMPLOYEE',
            'identifier': '000000000002',
            'jobTitle': 'SYNTHETIC JOB',
            'hireDate': '2025-01-01',
            'birthDate': '1990-01-01',
            'grossBase': 30000000,
            'status': 'ACTIVE',
            'resident': true,
            'citizenship': 'KZ',
            'sex': 'M',
            'standardDeductionDeclaration': true,
          },
        );
      });
      await fill('Месяц YYYY-MM', '2026-10');
      await click(find.text('Показать месяц'));
      await click(find.text('Табель и начисления проверены'));
      await click(find.text('Подготовить начисление'));
      await click(
        find.widgetWithText(DropdownButtonFormField<String>, 'Сотрудник'),
      );
      await click(find.text('SYNTHETIC OPENING EMPLOYEE').last);
      await click(find.text('Проверены обычная зарплата и один работодатель'));
      await click(find.text('Зафиксировать политику точности расчёта'));
      await click(find.text('Рассчитать и проверить'));
      expect(
        find.textContaining('Не хватает подтверждённых данных'),
        findsOneWidget,
      );
      await click(find.text('Начальные данные дохода и удержаний'));
      await fill('Последний включённый месяц YYYY-MM', '2026-09');
      await fill('Облагаемый доход ИПН с начала года, KZT', '1208250.00');
      await fill('Исчисленный ИПН с начала года, KZT', '120825.00');
      await fill('Применённый базовый вычет с начала года, KZT', '1167750.00');
      await fill('Неиспользованный базовый вычет, KZT', '0.00');
      await fill('Доход для исчисления ОПВ с начала года, KZT', '2700000.00');
      await fill(
        'Источник начальных данных',
        'SYNTHETIC SAME EMPLOYER JANUARY THROUGH SEPTEMBER',
      );
      await click(find.text('Подтверждены период, суммы и этот работодатель'));
      await click(find.text('Сохранить начальные данные'));
      await click(find.text('Рассчитать и проверить'));
      expect(find.text('К выплате: 250 575,00 ₸'), findsOneWidget);
      await click(find.text('Сохранить черновик зарплаты'));
      await click(find.text('Удалить черновик зарплаты'));
      await tester.runAsync(() async {
        final rows = jsonObject(
          await api.request(
            'GET',
            ['v1', 'companies', companyId, 'payroll'],
            query: {'month': '2026-10'},
          ),
        );
        expect(rows['items'], isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
