import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/main_server.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/commercial_repository.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'real sales UI issues invoice, applies advance, posts and corrects paid service act',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = jsonDecode(
        File(Platform.environment['MUCHET_TEST_FIXTURE']!)
            .readAsStringSync()) as Map<String, dynamic>;
    final transport = HttpOverrides.runWithHttpOverrides(
        () => IOClient(HttpClient()), RealNetwork());
    final client = BackendClient(
        origin: Uri.parse(fixture['origin'] as String), transport: transport);
    final identity = IdentityRepository(client);
    await tester.runAsync(() async {
      await identity.login(
          fixture['login'] as String, fixture['password'] as String);
      final company = (await identity.companies()).single;
      final prefix = ['v1', 'companies', company.id];
      final settings =
          jsonObject(await client.request('GET', [...prefix, 'settings']));
      await client.request('PUT', [...prefix, 'settings'],
          operation: OperationKey(),
          body: {
            'version': settings['version'],
            'legalName': 'SYNTHETIC UI COMPANY',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false
          });
      await CatalogRepository(client, company.id).create('clients',
          {'name': 'SYNTHETIC UI CLIENT', 'identifier': '000000000001'});
      await client.request('POST', [...prefix, 'wallets'],
          operation: OperationKey(), body: {'name': 'SYNTHETIC UI BANK'});
    });
    await tester.pumpWidget(AccountingWorkspace(client: client));
    await tester.pumpAndSettle();
    Future<void> click(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
    }

    Future<void> fill(String label, String value) async {
      final finder = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
      await tester.pump();
    }

    await tester.enterText(
        find.byType(TextField).at(0), fixture['login'] as String);
    await tester.enterText(
        find.byType(TextField).at(1), fixture['password'] as String);
    await click(find.text('Войти'));
    for (var i = 0;
        i < 30 && find.text('Бизнес под контролем').evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.text('Бизнес под контролем'), findsOneWidget);
    await click(find.text('Продажи'));
    expect(find.text('Документы продаж'), findsOneWidget);
    await click(find.text('Новый документ'));
    await click(find.byType(DropdownButtonFormField<String>).at(1));
    await click(find.text('SYNTHETIC UI CLIENT').last);
    await fill('Наименование услуги', 'Разработка приложения');
    await fill('Цена без НДС, KZT', '100,00');
    await click(find.text('Сохранить черновик'));
    expect(find.text('Выставить счёт'), findsOneWidget);
    await click(find.text('Выставить счёт'));
    await click(find.text('Связать оплату'));
    await click(find.byType(DropdownButtonFormField<String>));
    await click(find.text('SYNTHETIC UI BANK').last);
    await fill('Сумма, KZT', '40');
    await click(find.text('Сохранить оплату'));
    await click(find.text('Создать акт'));
    await click(find.text('Провести'));
    await click(find.text('Связать оплату'));
    await click(find.byType(DropdownButtonFormField<String>));
    await click(find.text('SYNTHETIC UI BANK').last);
    await fill('Сумма, KZT', '60');
    await click(find.text('Сохранить оплату'));
    expect(find.text('Осталось: 0,00 ₸'), findsOneWidget);
    await click(find.text('Изменить'));
    await fill('Цена без НДС, KZT', '50');
    await click(find.text('Сохранить изменения'));
    expect(find.text('Аванс / переплата: 50,00 ₸'), findsOneWidget);
    await click(find.text('Оплаты'));
    expect(find.byTooltip('Изменить оплату'), findsNWidgets(2));
    await click(find.byTooltip('Изменить оплату').first);
    await fill('Сумма, KZT', '30');
    await click(find.text('Сохранить оплату'));
    expect(find.text('Отменить запись'), findsNWidgets(2));
    await click(find.text('Отменить запись').first);
    expect(find.text('Восстановить запись'), findsOneWidget);
    await click(find.text('Восстановить запись'));
    expect(find.text('Восстановить запись'), findsNothing);
    await tester.runAsync(() async {
      final company = (await identity.companies()).single;
      final repository = CommercialRepository(client, company.id);
      final all = await repository.list(direction: 'sales');
      final act = (all['items'] as List)
          .map(jsonObject)
          .singleWhere((d) => d['kind'] == 'SALE_ACT');
      final file = await client.uploadFile(
          company.id, utf8.encode('SYNTHETIC UI SOURCE'), 'ui-source.txt');
      await repository.action(
          act['id'] as String, 'files', {'fileId': file['id']}).execute(client);
      expect(
          utf8.decode(
              await client.downloadFile(company.id, file['id'] as String)),
          'SYNTHETIC UI SOURCE');
    });
    await click(find.text('Вложения'));
    expect(find.text('ui-source.txt'), findsOneWidget);
    await click(find.byTooltip('Закрыть'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
