import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/main_server.dart';
import 'package:uchet_s_d/workspace/home_workspace.dart';
import 'package:uchet_s_d/workspace/commercial_editor.dart';
import 'package:uchet_s_d/workspace/commercial_detail.dart';
import 'package:uchet_s_d/workspace/tax_calendar_workspace.dart';
import 'package:uchet_s_d/workspace/bank_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'home uses real money, chart, documents and task actions across scopes projects and mobile',
    (tester) async {
      final previousHitTestPolicy =
          WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal =
            previousHitTestPolicy,
      );
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = jsonObject(
        jsonDecode(
          File(Platform.environment['MUCHET_TEST_FIXTURE']!).readAsStringSync(),
        ),
      );
      final api = BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: HttpOverrides.runWithHttpOverrides(
          () => IOClient(HttpClient()),
          RealNetwork(),
        ),
      );
      late String companyId, day, number;
      const projectName = 'SYNTHETIC DYNAMIC HOME PROJECT WITH A LONG NAME';
      Future<Map<String, dynamic>> post(
        List<String> tail,
        Map<String, dynamic> body,
      ) async => jsonObject(
        await api.request(
          'POST',
          ['v1', 'companies', companyId, ...tail],
          body: body,
          operation: OperationKey(),
        ),
      );
      await tester.runAsync(() async {
        final identity = IdentityRepository(api);
        await identity.login(
          fixture['login'] as String,
          fixture['password'] as String,
        );
        companyId = (await identity.companies()).first.id;
        await api.request(
          'PUT',
          ['v1', 'companies', companyId, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC HOME COMPANY',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
        day =
            jsonObject(
                  await api.request('GET', [
                    'v1',
                    'companies',
                    companyId,
                    'dashboard',
                  ]),
                )['companyBusinessDate']
                as String;
        final project = await post(['projects'], {'name': projectName});
        final client = await post(
          ['resources', 'clients'],
          {
            'data': {'name': 'SYNTHETIC HOME CLIENT'},
          },
        );
        for (var i = 0; i < 51; i++) {
          await post(
            ['resources', 'clients'],
            {
              'data': {'name': 'SYNTHETIC EXTRA CLIENT $i'},
            },
          );
        }
        final wallet = await post(['wallets'], {'name': 'SYNTHETIC HOME BANK'});
        await post(
          ['wallets', wallet['id'] as String, 'transactions'],
          {
            'type': 'CAPITAL',
            'amount': 100000,
            'businessDate': day,
            'description': 'SYNTHETIC HOME FUNDS',
          },
        );
        await post(
          ['wallets', wallet['id'] as String, 'transactions'],
          {
            'type': 'EXPENSE',
            'amount': 10000,
            'businessDate': day,
            'projectId': project['id'],
            'description': 'SYNTHETIC PROJECT COST',
          },
        );
        final draft = await post(
          ['commercial-documents'],
          {
            'kind': 'SALE_INVOICE',
            'counterpartyId': client['id'],
            'projectId': project['id'],
            'businessDate': '1999-12-31',
            'items': [
              {
                'description': 'SYNTHETIC HOME SERVICE',
                'quantity': '1',
                'unitPrice': 12345,
              },
            ],
          },
        );
        number = draft['number'] as String;
        await post(
          ['bank-imports'],
          {
            'walletId': wallet['id'],
            'csv':
                'date;reference;debit;credit;description\n$day;home-pending;0;1.00;SYNTHETIC HOME PENDING',
          },
        );
        await post(
          ['tax-calendar'],
          {
            'title': 'SYNTHETIC HOME TAX TASK',
            'dueDate': day,
            'status': 'OPEN',
            'category': 'TAX',
            'dueDateConfirmed': true,
            'source': 'SYNTHETIC CHECKED SOURCE',
          },
        );
      });
      Future<void> wait() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(Finder f) async {
        await tester.ensureVisible(f.first);
        await tester.pumpAndSettle();
        await tester.tap(f.first);
        await wait();
      }

      await tester.pumpWidget(AccountingWorkspace(client: api));
      await tester.enterText(
        find.byType(TextField).at(0),
        fixture['login'] as String,
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        fixture['password'] as String,
      );
      await click(find.text('Войти'));
      expect(find.byType(HomeWorkspace), findsOneWidget);
      expect(find.text('900 ₸'), findsOneWidget);
      expect(find.text('Проверить операции: 1'), findsOneWidget);
      expect(find.text('SYNTHETIC HOME TAX TASK'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(DataTable),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await click(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.textContaining(number),
        ),
      );
      expect(find.byType(CommercialDetail), findsOneWidget);
      await click(find.text('Изменить'));
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Дата документа'))
            .controller!
            .text,
        '1999-12-31',
      );
      await click(find.widgetWithText(TextField, 'Дата документа'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Отмена'),
        ),
      );
      await click(
        find.descendant(
          of: find.byType(CommercialEditor),
          matching: find.byTooltip('Закрыть'),
        ),
      );
      await click(
        find.descendant(
          of: find.byType(CommercialDetail),
          matching: find.byTooltip('Закрыть'),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Создать документ'),
        -400,
        scrollable: find.byType(Scrollable).last,
      );
      await click(find.text('Создать документ'));
      await click(find.text('Счёт или акт услуг'));
      expect(find.byType(CommercialEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Дата документа'))
            .controller!
            .text,
        day,
      );
      await click(
        find.descendant(
          of: find.byType(CommercialEditor),
          matching: find.byTooltip('Закрыть'),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Что сделать дальше'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Последние документы'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await click(find.text('Ещё'));
      await click(find.widgetWithText(ListTile, 'Проекты'));
      expect(find.byType(HomeWorkspace), findsNothing);
      await click(find.byTooltip('Разделы'));
      await click(find.widgetWithText(ListTile, 'Главная'));
      expect(find.byType(HomeWorkspace), findsOneWidget);
      await click(find.text('Документы'));
      expect(find.text('Документы продаж'), findsOneWidget);
      await click(find.byTooltip('Разделы'));
      await click(find.widgetWithText(ListTile, 'Главная'));
      expect(find.byType(HomeWorkspace), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      tester.view.physicalSize = const Size(1440, 960);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('SYNTHETIC HOME TAX TASK'),
        -350,
        scrollable: find.byType(Scrollable).last,
      );
      await click(find.text('SYNTHETIC HOME TAX TASK'));
      expect(find.byType(TaxTaskEditor), findsOneWidget);
      await click(
        find.widgetWithText(DropdownButtonFormField<String>, 'Статус задачи'),
      );
      await click(find.text('Выполнена').last);
      await click(find.text('Сохранить задачу'));
      expect(find.byType(TaxTaskEditor), findsNothing);
      expect(find.text('SYNTHETIC HOME TAX TASK'), findsNothing);
      await click(find.text('Проверить операции: 1'));
      expect(find.byType(BankWorkspace), findsOneWidget);
      await click(find.text('Главная'));
      await click(find.byTooltip('Вид учёта главной'));
      await click(find.text('Управленческий учёт'));
      expect(find.textContaining('УПРАВЛЕНЧЕСКИЙ УЧЁТ'), findsOneWidget);
      await click(find.text('Создать документ'));
      await click(find.text('Счёт или акт услуг'));
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.widgetWithText(DropdownButtonFormField<String>, 'Вид учёта'),
            )
            .initialValue,
        'MANAGEMENT',
      );
      final party = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Клиент',
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: party,
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .items!
            .length,
        52,
      );
      await click(party);
      final homeClient = find.widgetWithText(
        DropdownMenuItem<String>,
        'SYNTHETIC HOME CLIENT',
      );
      await tester.scrollUntilVisible(
        homeClient,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await click(
        find.descendant(
          of: homeClient,
          matching: find.text('SYNTHETIC HOME CLIENT'),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Наименование услуги'),
        'SYNTHETIC MANAGEMENT SERVICE',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Цена без НДС, KZT'),
        '1.25',
      );
      await click(find.text('Сохранить черновик'));
      expect(find.byType(CommercialDetail), findsOneWidget);
      await click(
        find.descendant(
          of: find.byType(CommercialDetail),
          matching: find.byTooltip('Закрыть'),
        ),
      );
      await tester.runAsync(() async {
        final list = jsonObject(
          await api.request(
            'GET',
            ['v1', 'companies', companyId, 'commercial-documents'],
            query: {'scope': 'MANAGEMENT'},
          ),
        );
        expect((list['items'] as List).length, 1);
        final saved = jsonObject((list['items'] as List).single);
        expect(saved['scope'], 'MANAGEMENT');
        expect(saved['business_date'], day);
        expect(jsonObject(saved['data'])['total'], 125);
      });

      expect(find.text('900 ₸'), findsNothing);
      await click(find.byTooltip('Вид учёта главной'));
      await click(find.text('Бухгалтерский учёт'));
      expect(find.text('900 ₸'), findsOneWidget);
      await click(find.text('Вся фирма'));
      await click(find.text(projectName).last);
      expect(find.text('Чистое движение денег'), findsOneWidget);
      expect(find.text('-100 ₸'), findsOneWidget);
      expect(find.text('900 ₸'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
