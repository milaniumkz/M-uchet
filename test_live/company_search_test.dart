import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/main_server.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real company search opens an employee, numbered service document, product and project on desktop and mobile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      late String companyId, number, projectId;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        companyId = (await IdentityRepository(api).companies()).first.id;
        final base = ['v1', 'companies', companyId];
        Future<Map<String, dynamic>> post(
          List<String> rest,
          Map<String, dynamic> body,
        ) async => jsonObject(
          await api.request(
            'POST',
            [...base, ...rest],
            body: body,
            operation: OperationKey(),
          ),
        );
        await api.request(
          'PUT',
          [...base, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC SEARCH FIRM',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
        final project = await post(['projects'], {'name': 'SEARCH PROJECT'});
        projectId = project['id'] as String;
        await post(
          ['resources', 'nomenklatura'],
          {
            'data': {'name': 'SEARCH COPPER', 'priceMinor': 12345},
          },
        );
        final client = await post(
          ['resources', 'clients'],
          {
            'data': {'name': 'SEARCH CLIENT'},
          },
        );
        await post(
          ['employees'],
          {
            'name': 'SEARCH EMPLOYEE',
            'identifier': '111111111111',
            'jobTitle': 'SEARCH JOB',
            'hireDate': '2026-01-01',
            'grossBase': 100000,
            'status': 'ACTIVE',
            'resident': true,
            'citizenship': 'KZ',
            'standardDeductionDeclaration': false,
          },
        );
        final document = await post(
          ['commercial-documents'],
          {
            'kind': 'SALE_ACT',
            'counterpartyId': client['id'],
            'projectId': projectId,
            'businessDate': '2026-01-01',
            'items': [
              {
                'description': 'SEARCH SERVICE',
                'quantity': '1.000',
                'unitPrice': 10000,
              },
            ],
          },
        );
        number = document['number'] as String;
        await IdentityRepository(api).logout();
      });
      Future<void> wait() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 700)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await wait();
        await wait();
      }

      Future<void> search(String query) async {
        await click(find.byTooltip('Поиск по фирме'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Документы, люди и товары'),
          query,
        );
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
      await search('SEARCH EMPLOYEE');
      await click(find.widgetWithText(ListTile, 'SEARCH EMPLOYEE'));
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'ФИО'))
            .controller!
            .text,
        'SEARCH EMPLOYEE',
      );
      await click(find.text('Отмена'));
      await search(number);
      await click(find.widgetWithText(ListTile, number));
      expect(find.textContaining('№ $number'), findsOneWidget);
      await click(find.byTooltip('Закрыть'));
      await search('SEARCH COPPER');
      await click(find.widgetWithText(ListTile, 'SEARCH COPPER'));
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Название'),
            )
            .initialValue,
        'SEARCH COPPER',
      );
      await click(find.text('Отмена'));
      await search('SEARCH PROJECT');
      await click(find.widgetWithText(ListTile, 'SEARCH PROJECT'));
      expect(find.text('Бизнес под контролем'), findsOneWidget);
      await tester.runAsync(() async {
        final data = jsonObject(
          await api.request(
            'GET',
            ['v1', 'companies', companyId, 'reports', 'projects'],
            query: {'projectId': projectId},
          ),
        );
        expect(data['items'][0]['projectId'], projectId);
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await search('SEARCH COPPER');
      expect(find.widgetWithText(ListTile, 'SEARCH COPPER'), findsOneWidget);
      await click(find.byTooltip('Очистить поиск'));
      expect(find.widgetWithText(ListTile, 'SEARCH COPPER'), findsNothing);
      await click(find.text('Закрыть'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
