import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/inventory_workspace.dart';
import 'package:uchet_s_d/workspace/company_access.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'stock count UI saves, posts, edits historical loss, cancels and exposes private history on mobile',
    (tester) async {
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
      );
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      addTearDown(api.close);
      late String companyId;
      await tester.runAsync(() async {
        final identity = IdentityRepository(api);
        await identity.login(
          fixture['login'] as String,
          fixture['password'] as String,
        );
        companyId = (await identity.companies()).single.id;
        final catalog = CatalogRepository(api, companyId);
        final product = await catalog.create('nomenklatura', {
          'name': 'SYNTHETIC COUNT PRODUCT',
          'unit': 'шт.',
          'minimumStock': 4,
        });
        final warehouse = await catalog.create('warehouses', {
          'name': 'SYNTHETIC COUNT WAREHOUSE',
        });
        await api.request(
          'POST',
          ['v1', 'companies', companyId, 'inventory', 'receipts'],
          operation: OperationKey(),
          body: {
            'productId': product.id,
            'warehouseId': warehouse.id,
            'quantity': 5,
            'unitCost': 1000,
          },
        );
      });
      Widget workspace({
        bool readOnly = false,
        Future<void> Function()? onChanged,
      }) => MaterialApp(
        builder: (context, child) => CompanyAccess(
          company: CompanyDto(
            companyId,
            'SYNTHETIC',
            'KZT',
            role: readOnly ? 'member' : 'owner',
            permissions: const ['inventory.read'],
          ),
          child: child!,
        ),
        home: Scaffold(
          body: InventoryWorkspace(
            api: api,
            companyId: companyId,
            currency: 'KZT',
            projects: const [],
            onChanged: onChanged ?? () async {},
          ),
        ),
      );
      await tester.pumpWidget(workspace());
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 450)),
        );
        await tester.pumpAndSettle();
      }

      await settle();
      Future<void> click(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextField, label);
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.enterText(f, value);
        await tester.pumpAndSettle();
      }

      await click(find.text('Начать инвентаризацию'));
      await fill('Основание пересчёта', 'SYNTHETIC ACTUAL COUNT');
      await fill('Фактический остаток', '3');
      await click(find.text('Сохранить пересчёт'));
      expect(find.text('Статус: Черновик'), findsOneWidget);
      expect(find.textContaining('Учтено при сохранении: 5'), findsOneWidget);
      await click(find.text('Провести пересчёт'));
      expect(find.text('Статус: Проведено'), findsOneWidget);
      Future<Map<String, dynamic>> read(String endpoint) async => jsonObject(
        await api.request('GET', [
          'v1',
          'companies',
          companyId,
          ...endpoint.split('/'),
        ]),
      );
      await tester.runAsync(() async {
        expect((await read('reports/profit-loss'))['expenses'], 2000);
        expect(
          jsonObject(
            ((await read('inventory/balances'))['items'] as List).single,
          )['quantity'],
          3,
        );
      });
      await fill('Фактический остаток', '4');
      await fill('Дата пересчёта', '1999-12-31');
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Отменить проведение'),
            )
            .onPressed,
        isNull,
      );
      await click(find.text('Сохранить изменения пересчёта'));
      await tester.runAsync(() async {
        expect((await read('reports/profit-loss'))['expenses'], 1000);
        expect(
          jsonObject(
            ((await read('inventory/balances'))['items'] as List).single,
          )['quantity'],
          4,
        );
      });
      await click(find.text('Отменить проведение'));
      expect(find.text('Статус: Отменено'), findsOneWidget);
      await tester.runAsync(() async {
        expect((await read('reports/profit-loss'))['expenses'], 0);
        expect(
          jsonObject(
            ((await read('inventory/balances'))['items'] as List).single,
          )['quantity'],
          5,
        );
      });
      await click(find.text('История пересчёта'));
      expect(find.textContaining('версия 1'), findsOneWidget);
      await click(find.text('Закрыть историю'));
      await click(find.text('Закрыть пересчёт'));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await click(find.textContaining('Отменено · 1999-12-31'));
      await click(find.text('История пересчёта'));
      await click(find.text('Закрыть историю'));
      await click(find.text('Закрыть пересчёт'));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final refreshing = Completer<void>();
      await tester.pumpWidget(
        workspace(readOnly: true, onChanged: () => refreshing.future),
      );
      await settle();
      await click(find.text('Инвентаризации'));
      await click(find.textContaining('Отменено · 1999-12-31'));
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Фактический остаток'),
            )
            .enabled,
        isFalse,
      );
      expect(find.text('Сохранить изменения пересчёта'), findsNothing);
      await click(find.text('Закрыть пересчёт'));
      await tester.pumpWidget(const SizedBox());
      refreshing.complete();
      await settle();
      expect(tester.takeException(), isNull);
    },
  );
}
