import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/cash_workspace.dart';
import 'package:uchet_s_d/workspace/money_transaction_dialog.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real cash UI counts a shift, corrects it, edits a transfer and reconciles a wallet',
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
      late String companyId, aId, bId;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        final company = jsonObject(
          await api.request(
            'POST',
            ['v1', 'companies'],
            body: {'name': 'SYNTHETIC CASH UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
        final a = jsonObject(
              await api.request(
                'POST',
                ['v1', 'companies', companyId, 'wallets'],
                body: {'name': 'SYNTHETIC CASH A'},
                operation: OperationKey(),
              ),
            ),
            b = jsonObject(
              await api.request(
                'POST',
                ['v1', 'companies', companyId, 'wallets'],
                body: {'name': 'SYNTHETIC CASH B'},
                operation: OperationKey(),
              ),
            );
        aId = a['id'] as String;
        bId = b['id'] as String;
        await api.request(
          'POST',
          ['v1', 'companies', companyId, 'wallets', aId, 'transactions'],
          body: {
            'type': 'CAPITAL',
            'amount': 10000,
            'description': 'SYNTHETIC CASH CAPITAL',
          },
          operation: OperationKey(),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CashWorkspace(
                api: api,
                companyId: companyId,
                currency: 'KZT',
                projects: const [],
                onChanged: () async {},
                onTransaction: (entry) async {
                  final data = jsonObject(
                    await api.request('GET', [
                      'v1',
                      'companies',
                      companyId,
                      'wallets',
                    ]),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => MoneyTransactionDialog(
                      api: api,
                      companyId: companyId,
                      currency: 'KZT',
                      wallets: (data['items'] as List).map(jsonObject).toList(),
                      projects: const [],
                      today: data['businessDate'] as String,
                      entry: entry,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pump();
      }

      await click(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Счёт для операций и смен',
        ),
      );
      await click(find.text('SYNTHETIC CASH A').last);
      await click(find.text('Открыть смену'));
      expect(find.text('Смена открыта'), findsOneWidget);
      await click(find.text('Закрыть смену'));
      await fill('Фактически в кассе, KZT', '90.00');
      await click(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Закрыть смену'),
        ),
      );
      expect(find.text('Разница: -10,00 ₸'), findsOneWidget);
      await click(find.text('Исправить пересчёт'));
      await fill('Фактически в кассе, KZT', '95.00');
      await fill('Причина исправления', 'SYNTHETIC COUNT CORRECTION');
      await click(find.text('Сохранить пересчёт'));
      expect(find.text('Разница: -5,00 ₸'), findsOneWidget);
      await click(find.text('Поступление / расход'));
      await fill('Сумма, KZT', '5.00');
      await fill('Основание операции', 'SYNTHETIC CASH INCOME');
      await fill('Дата операции YYYY-MM-DD', '2026-01-10');
      await click(find.widgetWithText(DropdownButtonFormField<String>, 'Счёт'));
      await click(find.text('SYNTHETIC CASH A').last);
      await click(find.text('Сохранить'));
      await click(find.text('Перевести между счетами'));
      await fill('Сумма перевода, KZT', '20.00');
      await fill('Дата перевода YYYY-MM-DD', '2026-01-12');
      await fill('Назначение перевода', 'SYNTHETIC UI TRANSFER');
      await click(find.text('Перевести'));
      await click(find.byTooltip('Открыть перевод'));
      await fill('Сумма перевода, KZT', '15.00');
      await fill('Причина исправления', 'SYNTHETIC TRANSFER CORRECTION');
      await click(find.text('Сохранить перевод'));
      final card = find
          .ancestor(
            of: find.text('SYNTHETIC CASH A'),
            matching: find.byType(Card),
          )
          .first;
      await click(
        find.descendant(of: card, matching: find.text('Изменить счёт')),
      );
      await fill('Название счёта', 'SYNTHETIC RENAMED CASH A');
      await click(find.byType(CheckboxListTile));
      await fill('Текущий остаток после исправления, KZT', '110.00');
      await fill('Дата проводки YYYY-MM-DD', '2026-01-31');
      await fill('Причина корректировки', 'SYNTHETIC WALLET CORRECTION');
      await click(find.text('Сохранить счёт'));
      await tester.runAsync(() async {
        final data = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'wallets']),
        );
        final wallets = (data['items'] as List).map(jsonObject).toList();
        expect(wallets.singleWhere((w) => w['id'] == aId)['balance'], 11000);
        expect(wallets.singleWhere((w) => w['id'] == bId)['balance'], 1500);
        final report = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            companyId,
            'reports',
            'profit-loss',
          ]),
        );
        expect(report['netProfit'], 500);
        final shifts = jsonObject(
          await api.request('GET', ['v1', 'companies', companyId, 'shifts']),
        );
        expect(
          jsonObject((shifts['items'] as List).single)['difference'],
          -500,
        );
      });
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
