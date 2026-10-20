import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/ledger_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real reports drill into journal, close month and still edit posted amounts with history',
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
      late String companyId, entryId;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        final company = jsonObject(
          await api.request(
            'POST',
            ['v1', 'companies'],
            body: {'name': 'SYNTHETIC LEDGER UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
        final entry = jsonObject(
          await api.request(
            'POST',
            ['v1', 'companies', companyId, 'accounting', 'journal'],
            body: {
              'description': 'SYNTHETIC LEDGER UI',
              'businessDate': '2026-10-20',
              'lines': [
                {'account': 'cash', 'debit': 10000},
                {'account': 'revenue', 'credit': 10000},
              ],
            },
            operation: OperationKey(),
          ),
        );
        entryId = entry['id'] as String;
      });
      Future<void> pumpMode(String mode) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LedgerWorkspace(
                key: ValueKey(mode),
                api: api,
                companyId: companyId,
                currency: 'KZT',
                mode: mode,
                projects: const [],
                from: '2026-10-01',
                to: '2026-10-31',
                onChanged: () async {},
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 450)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pumpAndSettle();
      }

      await pumpMode('periods');
      await click(find.text('Изменить состояние месяца'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Комментарий'),
        'SYNTHETIC UI CLOSE',
      );
      await click(find.text('Закрыть'));
      expect(find.text('Закрыт, редактирование доступно'), findsOneWidget);
      await pumpMode('reports');
      expect(find.text('Прибыль'), findsOneWidget);
      await click(find.text('Доходы').last);
      await click(find.text('Manual: SYNTHETIC LEDGER UI'));
      expect(find.text('Изменить бухгалтерскую запись'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Дебет').first,
        '75.00',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Кредит').last,
        '75.00',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Причина исправления'),
        'SYNTHETIC AFTER CLOSE',
      );
      await click(find.text('Сохранить запись'));
      await tester.runAsync(() async {
        final report = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            companyId,
            'reports',
            'profit-loss',
          ]),
        );
        expect(report['netProfit'], 7500);
        final history = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            companyId,
            'accounting',
            'journal',
            entryId,
            'history',
          ]),
        );
        expect((history['items'] as List).length, 1);
        final periods = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'periods']),
        );
        expect(
          jsonObject((periods['items'] as List).single)['status'],
          'CLOSED',
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
