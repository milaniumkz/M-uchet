import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/goods_workspace.dart';
import 'package:uchet_s_d/workspace/goods_pdf.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real goods UI reserves, ships, pays to wallet and corrects dated sale with stock and printable evidence',
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
      late String companyId, walletId;
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
                  {'name': 'SYNTHETIC GOODS UI', 'currency': 'KZT'},
                ))['id']
                as String;
        final base = ['v1', 'companies', companyId];
        await api.request(
          'PUT',
          [...base, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC GOODS FIRM',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
        await post(
          [...base, 'resources', 'clients'],
          {
            'data': {'name': 'SYNTHETIC GOODS CLIENT'},
          },
        );
        final product = await post(
              [...base, 'resources', 'nomenklatura'],
              {
                'data': {'name': 'SYNTHETIC GOODS PRODUCT'},
              },
            ),
            warehouse = await post(
              [...base, 'resources', 'warehouses'],
              {
                'data': {'name': 'SYNTHETIC GOODS STOCK'},
              },
            );
        walletId =
            (await post(
                  [...base, 'wallets'],
                  {'name': 'SYNTHETIC GOODS BANK'},
                ))['id']
                as String;
        await post(
          [...base, 'inventory', 'receipts'],
          {
            'productId': product['id'],
            'warehouseId': warehouse['id'],
            'quantity': 10,
            'unitCost': 100,
            'businessDate': '2026-01-01',
          },
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoodsWorkspace(
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
      Future<void> click(Finder f) async {
        await tester.ensureVisible(f);
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      await click(find.text('Новая товарная продажа'));
      await fill('Дата продажи YYYY-MM-DD', '2026-01-10');
      await click(
        find.widgetWithText(DropdownButtonFormField<String>, 'Клиент'),
      );
      await click(find.text('SYNTHETIC GOODS CLIENT').last);
      await fill('Количество базовых единиц', '4');
      await fill('Цена без НДС, KZT', '2.00');
      await click(find.text('Проверить сумму'));
      expect(find.textContaining('Итого: 8,00 ₸'), findsOneWidget);
      await click(find.text('Сохранить продажу'));
      await click(find.text('Зарезервировать'));
      await click(find.text('Отменить резерв и продажу'));
      await click(find.text('Восстановить черновик'));
      await click(find.text('Зарезервировать'));
      await click(find.text('Отгрузить товары'));
      await click(find.text('Добавить оплату товара'));
      await fill('Дата оплаты YYYY-MM-DD', '2026-01-05');
      await click(find.text('Зачислить оплату'));
      expect(find.textContaining('Оплачено 8,00 ₸'), findsOneWidget);
      await click(find.text('Изменить продажу'));
      await fill('Дата продажи YYYY-MM-DD', '2026-01-20');
      await fill('Количество базовых единиц', '3');
      await fill('Причина исправления', 'SYNTHETIC GOODS EDIT');
      await click(find.text('Проверить сумму'));
      await click(find.text('Сохранить продажу'));
      expect(find.text('Аванс покупателя: 2,00 ₸'), findsOneWidget);
      await tester.runAsync(() async {
        final base = ['v1', 'companies', companyId],
            orders = jsonObject(await api.request('GET', [...base, 'orders']));
        final order = jsonObject((orders['items'] as List).single);
        expect(order['customerCredit'], 200);
        final pdf = await goodsPdf(order, 'KZT');
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
        expect(pdf.length, greaterThan(10000));
        final wallets = jsonObject(
          await api.request('GET', [...base, 'wallets']),
        );
        expect(jsonObject((wallets['items'] as List).single)['id'], walletId);
        expect(jsonObject((wallets['items'] as List).single)['balance'], 800);
        final stock = jsonObject(
          await api.request('GET', [...base, 'inventory']),
        );
        expect(jsonObject((stock['items'] as List).single)['quantity'], 7);
      });
      await click(find.text('Исправить оплату товара'));
      await fill('Сумма оплаты, KZT', '7.00');
      await fill('Дата оплаты YYYY-MM-DD', '2026-01-25');
      await fill(
        'Причина исправления оплаты',
        'SYNTHETIC PAYMENT UI CORRECTION',
      );
      await click(find.text('Сохранить оплату товара'));
      expect(find.text('Аванс покупателя: 1,00 ₸'), findsOneWidget);
      await click(find.text('Отменить запись оплаты'));
      expect(find.text('Запись оплаты отменена'), findsOneWidget);
      await click(find.text('Восстановить запись оплаты'));
      expect(find.text('Аванс покупателя: 1,00 ₸'), findsOneWidget);
      await click(find.text('История оплаты'));
      expect(
        find.textContaining('SYNTHETIC PAYMENT UI CORRECTION'),
        findsOneWidget,
      );
      await click(find.text('Закрыть историю оплаты'));
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'wallets']),
        );
        expect(jsonObject((wallets['items'] as List).single)['balance'], 700);
      });
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await click(find.text('Закрыть продажу'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
