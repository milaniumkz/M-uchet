import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/commercial_detail.dart';
import 'package:uchet_s_d/workspace/bank_workspace.dart';
import 'package:uchet_s_d/workspace/company_access.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'supplier refund UI changes real wallet and debt, supports mobile history and readonly access',
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
      late Map<String, dynamic> doc;
      late List<String> prefix;
      late String walletId;
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
            'legalName': 'SYNTHETIC REFUND COMPANY',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
        );
        final supplier = await CatalogRepository(
          api,
          company.id,
        ).create('suppliers', {'name': 'SYNTHETIC REFUND SUPPLIER'});
        final wallet = await command(
          'POST',
          [...prefix, 'wallets'],
          {'name': 'SYNTHETIC REFUND BANK'},
        );
        walletId = wallet['id'] as String;
        await command(
          'POST',
          [...prefix, 'wallets', walletId, 'transactions'],
          {
            'type': 'CAPITAL',
            'amount': 20000,
            'description': 'SYNTHETIC FUNDING',
            'businessDate': '2026-10-01',
          },
        );
        doc = await command(
          'POST',
          [...prefix, 'commercial-documents'],
          {
            'kind': 'PURCHASE_ACT',
            'counterpartyId': supplier.id,
            'items': [
              {
                'description': 'SYNTHETIC SERVICE',
                'quantity': '1',
                'unitPrice': 10000,
              },
            ],
            'businessDate': '2026-10-20',
          },
        );
        doc = await command('POST', [
          ...prefix,
          'commercial-documents',
          doc['id'] as String,
          'post',
        ], {});
        final payment = await command(
          'POST',
          [...prefix, 'commercial-documents', doc['id'] as String, 'payments'],
          {'walletId': walletId, 'amount': 10000, 'businessDate': '2026-10-21'},
        );
        doc = jsonObject(payment['document']);
      });
      Future<void> mount(CompanyDto access) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                CompanyAccess(company: access, child: child!),
            home: Scaffold(
              body: CommercialDetail(
                api: api,
                companyId: company.id,
                currency: 'KZT',
                document: doc,
                projects: const [],
                onChanged: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final finder = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        await tester.pump();
      }

      await mount(company);
      await click(find.text('Возврат от поставщика'));
      await fill('Сумма, KZT', '25');
      await fill('Дата оплаты: ГГГГ-ММ-ДД', '2026-10-22');
      await click(find.text('Сохранить возврат'));
      expect(find.text('Осталось: 25,00 ₸'), findsOneWidget);
      await click(find.text('Оплаты'));
      expect(find.byTooltip('Изменить возврат'), findsOneWidget);
      await click(find.byTooltip('Изменить возврат'));
      await fill('Сумма, KZT', '30');
      await click(find.text('Сохранить возврат'));
      await click(find.text('Документ'));
      expect(find.text('Осталось: 30,00 ₸'), findsOneWidget);
      await click(find.text('Оплаты'));
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', [...prefix, 'wallets']),
        );
        expect(
          (wallets['items'] as List)
              .map(jsonObject)
              .singleWhere((w) => w['id'] == walletId)['balance'],
          13000,
        );
        doc = jsonObject(
          await api.request('GET', [
            ...prefix,
            'commercial-documents',
            doc['id'] as String,
          ]),
        );
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await mount(company);
      await click(find.text('Оплаты'));
      final refundCard = find.ancestor(
        of: find.byTooltip('Изменить возврат'),
        matching: find.byType(Card),
      );
      await click(
        find.descendant(
          of: refundCard,
          matching: find.byTooltip('История операции'),
        ),
      );
      expect(find.text('История денежной операции'), findsOneWidget);
      expect(find.textContaining('До исправления:'), findsOneWidget);
      await click(find.text('Закрыть историю'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(
        CompanyDto(
          company.id,
          company.name,
          company.currency,
          role: 'member',
          permissions: const ['documents.read'],
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Возврат от поставщика'),
          matching: find.byWidgetPredicate(
            (widget) => widget is OutlinedButton,
          ),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      tester.view.physicalSize = const Size(1440, 960);
      await tester.runAsync(() async {
        await command(
          'POST',
          [...prefix, 'bank-imports'],
          {
            'name': 'SYNTHETIC SUPPLIER REFUND STATEMENT',
            'walletId': walletId,
            'csv':
                'date;reference;debit;credit;description\n2026-10-23;supplier-refund-ui;0;10.00;SYNTHETIC SUPPLIER REFUND',
          },
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BankWorkspace(
              api: api,
              companyId: company.id,
              currency: 'KZT',
              projects: const [],
              onChanged: () async {},
              onEditMoney: (_) async {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      await click(find.text('SYNTHETIC SUPPLIER REFUND STATEMENT'));
      await click(find.text('Сопоставить'));
      await click(find.text('Вид операции'));
      await click(find.text('Возврат денег по документу').last);
      await click(find.textContaining(doc['number'] as String));
      await click(find.text('Сохранить сопоставление'));
      await click(find.text('Провести'));
      expect(find.text('Проведено'), findsOneWidget);
      await tester.runAsync(() async {
        final updated = jsonObject(
          await api.request('GET', [
            ...prefix,
            'commercial-documents',
            doc['id'] as String,
          ]),
        );
        expect(updated['paid'], 6000);
        expect(updated['outstanding'], 4000);
        final wallets = jsonObject(
          await api.request('GET', [...prefix, 'wallets']),
        );
        expect(
          (wallets['items'] as List)
              .map(jsonObject)
              .singleWhere((w) => w['id'] == walletId)['balance'],
          14000,
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
