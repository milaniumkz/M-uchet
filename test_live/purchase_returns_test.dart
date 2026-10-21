import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/commercial_detail.dart';
import 'package:uchet_s_d/workspace/company_access.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'supplier physical return UI updates stock and debt, edits, cancels, restores and shows mobile history',
    (tester) async {
      final fatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = fatal);
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      tester.view.physicalSize = const Size(1440, 1000);
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
      late Map<String, dynamic> doc;
      late List<String> prefix;
      late String batchId;
      Future<Map<String, dynamic>> command(
        String method,
        List<String> path,
        Map<String, dynamic> body,
      ) async => jsonObject(
        await api.request(method, path, body: body, operation: OperationKey()),
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
            'legalName': 'SYNTHETIC RETURNS COMPANY',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
        );
        final catalog = CatalogRepository(api, company.id),
            supplier = await catalog.create('suppliers', {
              'name': 'SYNTHETIC RETURN SUPPLIER',
            }),
            product = await catalog.create('nomenklatura', {
              'name': 'SYNTHETIC RETURN PRODUCT',
            }),
            warehouse = await catalog.create('warehouses', {
              'name': 'SYNTHETIC RETURN WAREHOUSE',
            });
        doc = await command(
          'POST',
          [...prefix, 'commercial-documents'],
          {
            'kind': 'PURCHASE_GOODS',
            'counterpartyId': supplier.id,
            'businessDate': '2026-10-20',
            'items': [
              {
                'productId': product.id,
                'warehouseId': warehouse.id,
                'quantity': '10',
                'unitPrice': 100,
              },
            ],
          },
        );
        doc = await command('POST', [
          ...prefix,
          'commercial-documents',
          doc['id'] as String,
          'post',
        ], {});
        batchId =
            (jsonObject(
                          await api.request('GET', [
                            ...prefix,
                            'commercial-documents',
                            doc['id'] as String,
                            'returns',
                          ]),
                        )['batches']
                        as List)
                    .single['batch_id']
                as String;
      });
      Future<void> click(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      Future<Map<String, dynamic>> current() async => jsonObject(
        await api.request('GET', [
          ...prefix,
          'commercial-documents',
          doc['id'] as String,
        ]),
      );
      Future<void> assertState(int outstanding, int stock) async {
        await tester.runAsync(() async {
          expect((await current())['outstanding'], outstanding);
          final balances = jsonObject(
            await api.request('GET', [...prefix, 'inventory', 'balances']),
          );
          expect(jsonObject(balances['summary'])['value'], stock);
        });
      }

      CompanyDto access = company;
      Uint8List? exported;
      const printing = MethodChannel('net.nfet.printing');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(printing, (
        call,
      ) async {
        if (call.method == 'sharePdf') {
          exported = (call.arguments as Map)['doc'] as Uint8List;
          return true;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          printing,
          null,
        ),
      );
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                CompanyAccess(company: access, child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CommercialDetail(
                      api: api,
                      companyId: company.id,
                      currency: 'KZT',
                      document: doc,
                      projects: const [],
                      onChanged: () async {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      await click(find.text('Open'));
      await click(find.text('Товарные возвраты'));
      await click(find.text('Вернуть товар поставщику'));
      await fill('Дата возврата (ГГГГ-ММ-ДД)', '2026-10-23');
      await fill('Основание возврата', 'SYNTHETIC damaged goods');
      await tester.enterText(
        find.byKey(ValueKey('return-quantity-$batchId')),
        '4',
      );
      await click(find.text('Сохранить товарный возврат'));
      await assertState(600, 600);
      expect(find.textContaining('SYNTHETIC damaged goods'), findsOneWidget);
      await click(find.text('Исправить возврат'));
      await tester.enterText(
        find.byKey(ValueKey('return-quantity-$batchId')),
        '2',
      );
      await click(find.text('Сохранить товарный возврат'));
      await assertState(800, 800);
      await click(find.text('Отменить возврат'));
      await assertState(1000, 1000);
      await click(find.text('Исправить возврат'));
      await tester.enterText(
        find.byKey(ValueKey('return-quantity-$batchId')),
        '3',
      );
      await click(find.text('Сохранить товарный возврат'));
      await assertState(1000, 1000);
      await click(find.text('Восстановить возврат'));
      await assertState(700, 700);
      await click(find.text('PDF возврата'));
      expect(exported, isNotNull);
      expect(ascii.decode(exported!.take(5).toList()), '%PDF-');
      expect(exported!.length, greaterThan(10000));
      await tester.binding.setSurfaceSize(const Size(430, 932));
      tester.view.physicalSize = const Size(430, 932);
      await tester.pumpAndSettle();
      await click(find.text('История возврата'));
      expect(find.textContaining('Версия'), findsWidgets);
      expect(tester.takeException(), isNull);
      await click(find.text('Закрыть'));
      await click(find.byTooltip('Закрыть'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        doc = await current();
      });
      access = CompanyDto(
        company.id,
        company.name,
        company.currency,
        role: 'member',
        permissions: const ['documents.read', 'inventory.read'],
      );
      await mount();
      await click(find.text('Open'));
      await click(find.text('Товарные возвраты'));
      for (final label in [
        'Исправить возврат',
        'Отменить возврат',
        'PDF возврата',
      ]) {
        final finder = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        );
        expect(tester.widget<TextButton>(finder).onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
