import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/debts_workspace.dart';
import 'package:uchet_s_d/workspace/debts_repository.dart';
import 'package:uchet_s_d/workspace/debts_pdf.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'opening debt UI preserves cash through corrections, cancellation, restoration and mobile layout',
    (tester) async {
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
      late String companyId;
      Future<Map<String, dynamic>> post(
        List<String> tail,
        Map<String, dynamic> data,
      ) async => jsonObject(
        await api.request(
          'POST',
          ['v1', 'companies', companyId, ...tail],
          body: data,
          operation: OperationKey(),
        ),
      );
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        companyId =
            jsonObject(
                  await api.request(
                    'POST',
                    ['v1', 'companies'],
                    body: {'name': 'SYNTHETIC DEBTS', 'currency': 'KZT'},
                    operation: OperationKey(),
                  ),
                )['id']
                as String;
        await post(
          ['resources', 'clients'],
          {
            'data': {'name': 'SYNTHETIC CLIENT'},
          },
        );
        await post(['wallets'], {'name': 'SYNTHETIC CASH'});
      });
      Future<void> wait() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(String text) async {
        final f = find.text(text).first;
        await tester.ensureVisible(f);
        await tester.tap(f);
        await wait();
      }

      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebtsWorkspace(
              api: api,
              companyId: companyId,
              currency: 'KZT',
              projects: const [],
              onChanged: () async {},
            ),
          ),
        ),
      );
      await wait();
      await click('Добавить начальный долг');
      await fill('Сумма начального долга, KZT', '5.00');
      await fill('Дата остатка YYYY-MM-DD', '2026-01-10');
      await click('Сохранить долг');
      expect(find.text('Внести оплату долга'), findsOneWidget);
      await click('Внести оплату долга');
      await fill('Сумма оплаты, KZT', '3.00');
      await fill('Дата оплаты YYYY-MM-DD', '2026-01-05');
      await click('Сохранить оплату');
      final repo = DebtsRepository(api, companyId);
      late Map<String, dynamic> record;
      Future<void> refresh() async {
        await tester.runAsync(() async {
          final list = await repo.list({'scope': 'ACCOUNTING'});
          record = await repo.get(
            jsonObject((list['items'] as List).first)['id'] as String,
          );
        });
      }

      await refresh();
      expect(record['paid'], 300);
      expect(record['remaining'], 200);
      await tester.runAsync(
        () => post(
          ['periods', '2026-01', 'close'],
          {'reason': 'SYNTHETIC REVIEW'},
        ),
      );
      await click('Изменить долг');
      await fill('Сумма начального долга, KZT', '2.00');
      await fill('Дата остатка YYYY-MM-DD', '2026-02-10');
      await click('Сохранить долг');
      await refresh();
      expect(record['advance'], 100);
      expect(record['remaining'], 0);
      await click('Изменить оплату долга');
      await fill('Сумма оплаты, KZT', '1.50');
      await click('Сохранить оплату');
      await refresh();
      expect(record['paid'], 150);
      expect(record['remaining'], 50);
      await click('Отменить оплату долга');
      await click('Подтвердить');
      await refresh();
      expect(record['paid'], 0);
      expect(record['remaining'], 200);
      await click('Изменить оплату долга');
      await fill('Сумма оплаты, KZT', '6.00');
      await click('Сохранить оплату');
      await refresh();
      expect(record['paid'], 0);
      await click('Восстановить оплату долга');
      await click('Подтвердить');
      await refresh();
      expect(record['advance'], 400);
      await click('Отменить начальный остаток');
      await click('Подтвердить');
      await refresh();
      expect(record['status'], 'CANCELLED');
      expect(record['advance'], 600);
      await click('Восстановить начальный остаток');
      await click('Подтвердить');
      await refresh();
      expect(record['advance'], 400);
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'wallets']),
        );
        expect(jsonObject((wallets['items'] as List).first)['balance'], 600);
      });
      final pdf = await tester.runAsync(() => debtPdf(record, 'KZT'));
      expect(pdf!.length, greaterThan(1000));
      expect(utf8.decode(pdf.take(5).toList()), '%PDF-');
      await click('Проводки долга');
      expect(tester.takeException(), isNull);
      await click('История долга');
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await click('Изменить долг');
      expect(tester.takeException(), isNull);
      await click('Отмена');
      await click('Оплаты долга');
      await click('Изменить оплату долга');
      expect(tester.takeException(), isNull);
      await click('Отмена');
      await tester.tap(find.byTooltip('Закрыть долг'));
      await wait();
      expect(find.text('Добавить начальный долг'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
