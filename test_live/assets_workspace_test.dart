import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/assets_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real asset UI creates, activates, depreciates, edits and writes off a fixed asset',
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
            body: {'name': 'SYNTHETIC ASSET UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
        await CatalogRepository(
          api,
          companyId,
        ).create('suppliers', {'name': 'SYNTHETIC ASSET SUPPLIER'});
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssetsWorkspace(
              api: api,
              companyId: companyId,
              currency: 'KZT',
              projects: const [],
              onChanged: () async {},
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

      await click(find.text('Добавить актив'));
      await fill('Название актива', 'SYNTHETIC UI LAPTOP');
      await fill('Инвентарный номер', 'SYNTH-UI-001');
      await fill('Первоначальная стоимость, KZT', '100.01');
      await fill('Остаточная стоимость, KZT', '10.00');
      await fill('Срок полезного использования, месяцев', '3');
      await fill('Дата приобретения YYYY-MM-DD', '2026-01-15');
      await fill('Месяц начала амортизации YYYY-MM', '2026-02');
      await click(find.byType(CheckboxListTile));
      await click(find.text('Сохранить актив'));
      await click(find.text('SYNTHETIC UI LAPTOP · SYNTH-UI-001'));
      await click(find.text('Ввести в эксплуатацию'));
      await click(find.text('Начислить амортизацию'));
      await fill('По месяц включительно YYYY-MM', '2026-04');
      await click(find.text('Начислить'));
      expect(find.text('Амортизация: 90,01 ₸'), findsOneWidget);
      await click(find.text('Изменить актив'));
      await fill('Первоначальная стоимость, KZT', '160.00');
      await click(find.text('Сохранить актив'));
      expect(find.text('Амортизация: 150,00 ₸'), findsOneWidget);
      await click(find.text('Списать актив'));
      await fill('Дата YYYY-MM-DD', '2026-03-15');
      await fill('Причина списания', 'SYNTHETIC UI WRITE OFF');
      await click(find.text('Списать'));
      expect(find.text('Балансовая стоимость: 0,00 ₸'), findsOneWidget);
      expect(find.text('Амортизация: 50,00 ₸'), findsOneWidget);
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
        expect(report['expenses'], 16000);
      });
      await click(find.text('Восстановить актив'));
      expect(find.text('Амортизация: 150,00 ₸'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(find.text('Закрыть'));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
