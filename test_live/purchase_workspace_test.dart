import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/commercial_workspace.dart';
import 'package:uchet_s_d/workspace/commercial_detail.dart';
import 'package:uchet_s_d/workspace/company_access.dart';
import 'package:uchet_s_d/workspace/inventory_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'goods purchase UI posts rounded stock, pays, corrects, refunds and opens warehouse source on mobile',
    (tester) async {
      final fatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = fatal);
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
      late CompanyDto company;
      late List<String> prefix;
      late String warehouseId, productId, walletId;
      late List<Map<String, dynamic>> projects;
      Future<Map<String, dynamic>> command(
        String method,
        List<String> path,
        Map<String, dynamic> body,
      ) async => jsonObject(
        await api.request(method, path, operation: OperationKey(), body: body),
      );
      await tester.runAsync(() async {
        final identity = IdentityRepository(api);
        await identity.login(
          fixture['login'] as String,
          fixture['password'] as String,
        );
        company = (await identity.companies()).single;
        prefix = ['v1', 'companies', company.id];
        await command(
          'PUT',
          [...prefix, 'settings'],
          {
            'version': 0,
            'legalName': 'SYNTHETIC PURCHASE COMPANY',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
        );
        final catalog = CatalogRepository(api, company.id);
        await catalog.create('suppliers', {'name': 'SYNTHETIC GOODS SUPPLIER'});
        productId = (await catalog.create('nomenklatura', {
          'name': 'SYNTHETIC GOODS PRODUCT',
          'unit': 'шт.',
        })).id;
        warehouseId = (await catalog.create('warehouses', {
          'name': 'SYNTHETIC PURCHASE WAREHOUSE',
        })).id;
        walletId =
            (await command(
                  'POST',
                  [...prefix, 'wallets'],
                  {'name': 'SYNTHETIC PURCHASE BANK'},
                ))['id']
                as String;
        await command(
          'POST',
          [...prefix, 'wallets', walletId, 'transactions'],
          {
            'type': 'CAPITAL',
            'amount': 10000,
            'description': 'SYNTHETIC FUNDING',
          },
        );
        projects = [
          await command(
            'POST',
            [...prefix, 'projects'],
            {'name': 'SYNTHETIC DYNAMIC PROJECT'},
          ),
        ];
      });
      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommercialWorkspace(
              api: api,
              companyId: company.id,
              currency: 'KZT',
              direction: 'purchases',
              projectId: projects.single['id'] as String,
              projects: projects,
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      await click(find.text('Новый документ'));
      await click(
        find.ancestor(
          of: find.text('Тип документа'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await click(find.text('Поступление товаров').last);
      await click(
        find.ancestor(
          of: find.text('Поставщик'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await click(find.text('SYNTHETIC GOODS SUPPLIER').last);
      await click(
        find.ancestor(
          of: find.text('Товар'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await click(find.text('SYNTHETIC GOODS PRODUCT').last);
      await click(
        find.ancestor(
          of: find.text('Склад'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await click(find.text('SYNTHETIC PURCHASE WAREHOUSE').last);
      await fill('Количество', '3');
      await fill('Цена без НДС, KZT', '0,02');
      await click(
        find.ancestor(
          of: find.text('НДС по документу'),
          matching: find.byType(DropdownButtonFormField<int>),
        ),
      );
      await click(find.text('16% — основная ставка 2026').last);
      await click(find.text('Сохранить черновик'));
      await click(find.text('Предоплата поставщику'));
      await fill('Сумма, KZT', '0,07');
      await click(find.text('Сохранить оплату'));
      await click(find.text('Провести'));
      expect(find.text('Склад: SYNTHETIC PURCHASE WAREHOUSE'), findsOneWidget);
      await click(find.text('Склад поступления'));
      expect(find.textContaining('Цена слоя:'), findsNWidgets(2));

      await click(find.text('Изменить'));
      await fill('Цена без НДС, KZT', '0,03');
      await click(find.text('Сохранить изменения'));
      await click(find.text('Возврат от поставщика'));
      await fill('Сумма, KZT', '0,02');
      await click(find.text('Сохранить возврат'));
      await click(find.text('Отменить документ'));
      await click(find.text('Провести'));
      late Map<String, dynamic> doc;
      await tester.runAsync(() async {
        final list = jsonObject(
          await api.request(
            'GET',
            [...prefix, 'commercial-documents'],
            query: {'kind': 'PURCHASE_GOODS'},
          ),
        );
        doc = jsonObject((list['items'] as List).single);
        expect(doc['paid'], 5);
        expect(doc['outstanding'], 5);
        expect(doc['project_id'], projects.single['id']);
        final stock = jsonObject(
          await api.request('GET', [...prefix, 'inventory', 'balances']),
        );
        expect(stock['summary']['value'], 10);
        expect((stock['items'] as List).single['quantity'], 3);
        final profit = jsonObject(
          await api.request('GET', [...prefix, 'reports', 'profit-loss']),
        );
        expect(profit['expenses'], 0);
        final order = await command(
          'POST',
          [...prefix, 'orders'],
          {
            'items': [
              {
                'productId': productId,
                'warehouseId': warehouseId,
                'quantity': 1,
                'unitPrice': 100,
              },
            ],
          },
        );
        await command('POST', [
          ...prefix,
          'orders',
          order['id'] as String,
          'reserve',
        ], {});
        await command('POST', [
          ...prefix,
          'orders',
          order['id'] as String,
          'ship',
        ], {});
      });
      await click(find.byTooltip('Закрыть'));
      await click(find.text('Услуги'));
      expect(
        find.text('Документов пока нет. Создайте первый документ.'),
        findsOneWidget,
      );
      await click(find.text('Товары'));
      expect(
        find.text('Документов пока нет. Создайте первый документ.'),
        findsNothing,
      );
      await click(find.textContaining(doc['number'] as String));
      expect(find.byType(CommercialDetail), findsOneWidget);
      await click(find.byTooltip('Закрыть'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryWorkspace(
              api: api,
              companyId: company.id,
              currency: 'KZT',
              projects: projects,
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      await click(find.text('Партии'));
      await click(find.text('Открыть поступление').first);
      expect(find.byType(CommercialDetail), findsOneWidget);
      await click(find.text('Склад поступления'));
      expect(find.textContaining('Цена слоя:'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => CompanyAccess(
            company: CompanyDto(
              company.id,
              company.name,
              company.currency,
              role: 'member',
              permissions: const ['documents.read', 'inventory.read'],
            ),
            child: child!,
          ),
          home: Scaffold(
            body: CommercialDetail(
              api: api,
              companyId: company.id,
              currency: 'KZT',
              document: doc,
              projects: projects,
              onChanged: () async {},
            ),
          ),
        ),
      );
      final edit = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Изменить'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      expect(edit.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
