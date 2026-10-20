import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/inventory_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real stock UI receives, moves and writes off exact FIFO stock on desktop and mobile',
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
            body: {'name': 'SYNTHETIC STOCK UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
        final catalog = CatalogRepository(api, companyId);
        await catalog.create('nomenklatura', {'name': 'SYNTHETIC PRODUCT'});
        await catalog.create('warehouses', {'name': 'SYNTHETIC WAREHOUSE A'});
        await catalog.create('warehouses', {'name': 'SYNTHETIC WAREHOUSE B'});
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryWorkspace(
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
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
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

      await click(find.text('Поступление'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Количество базовых единиц'),
        '5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Стоимость единицы, KZT'),
        '10.00',
      );
      await click(find.text('Провести'));
      expect(find.text('Всего: 5'), findsOneWidget);
      await click(find.text('Перемещение'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Количество базовых единиц'),
        '2',
      );
      await click(find.text('Провести'));
      expect(find.text('Всего: 3'), findsOneWidget);
      expect(find.text('Всего: 2'), findsOneWidget);
      await click(find.text('Списание'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Количество базовых единиц'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Причина списания'),
        'SYNTHETIC WRITE OFF',
      );
      await click(find.text('Провести'));
      expect(find.text('Всего: 2'), findsNWidgets(2));
      await tester.runAsync(() async {
        final data = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'inventory']),
        );
        expect(
          (data['items'] as List)
              .map(jsonObject)
              .fold<num>(0, (sum, b) => sum + (b['quantity'] as num)),
          4,
        );
        final pl = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            companyId,
            'reports',
            'profit-loss',
          ]),
        );
        expect(pl['expenses'], 1000);
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
