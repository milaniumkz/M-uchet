import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/catalog_workspace.dart';
import 'package:uchet_s_d/workspace/counterparty_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'counterparty card reconciles an invoice advance and act and opens its document on desktop and mobile',
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
      late String companyId;
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
                  {'name': 'SYNTHETIC PARTY UI FIRM', 'currency': 'KZT'},
                ))['id']
                as String;
        final base = ['v1', 'companies', companyId];
        await api.request(
          'PUT',
          [...base, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC FIRM',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
        final party = await post(
          [...base, 'resources', 'clients'],
          {
            'data': {
              'name': 'SYNTHETIC CLIENT CARD',
              'identifier': '000000000001',
            },
          },
        );
        final wallet = await post(
          [...base, 'wallets'],
          {'name': 'SYNTHETIC PARTY BANK'},
        );
        final invoice = await post(
          [...base, 'commercial-documents'],
          {
            'kind': 'SALE_INVOICE',
            'counterpartyId': party['id'],
            'businessDate': '2026-10-20',
            'items': [
              {
                'description': 'SYNTHETIC SERVICE',
                'quantity': '1.000',
                'unitPrice': 10000,
              },
            ],
          },
        );
        await post([
          ...base,
          'commercial-documents',
          invoice['id'] as String,
          'post',
        ], {});
        await post(
          [
            ...base,
            'commercial-documents',
            invoice['id'] as String,
            'payments',
          ],
          {
            'walletId': wallet['id'],
            'amount': 4000,
            'businessDate': '2026-10-19',
          },
        );
        final act = await post([
          ...base,
          'commercial-documents',
          invoice['id'] as String,
          'act',
        ], {});
        await post([
          ...base,
          'commercial-documents',
          act['id'] as String,
          'post',
        ], {});
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogWorkspace(
              api: api,
              companyId: companyId,
              mode: 'counterparties',
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

      await click(find.text('SYNTHETIC CLIENT CARD'));
      expect(find.text('Расчёты по услугам'), findsOneWidget);
      expect(find.text('60,00 ₸'), findsOneWidget);
      await click(find.text('Открыть документ-основание').first);
      expect(find.text('Расчёты по услугам'), findsNothing);
      await click(find.byTooltip('Закрыть'));
      expect(find.byType(CounterpartyWorkspace), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Документы · 2'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Документы · 2'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Расчёты по услугам'),
        -500,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
