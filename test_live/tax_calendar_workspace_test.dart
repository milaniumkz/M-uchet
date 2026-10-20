import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/tax_calendar_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'company tax UI persists preparation, confirmed tasks, corrections, history and calendar on desktop and mobile',
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
      late String companyId;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        companyId =
            jsonObject(
                  await api.request(
                    'POST',
                    ['v1', 'companies'],
                    body: {'name': 'SYNTHETIC TAX CALENDAR', 'currency': 'KZT'},
                    operation: OperationKey(),
                  ),
                )['id']
                as String;
        await api.request(
          'PUT',
          ['v1', 'companies', companyId, 'settings'],
          body: {
            'version': 0,
            'legalName': 'SYNTHETIC TAX CALENDAR',
            'identifier': '000000000000',
            'legalForm': 'TOO',
            'taxRegime': 'GENERAL',
            'vatRegistered': false,
          },
          operation: OperationKey(),
        );
      });
      Future<void> wait() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await wait();
      }

      Future<void> fill(String label, String value) async {
        final finder = find.widgetWithText(TextField, label);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        await tester.pump();
      }

      var profileOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaxCalendarWorkspace(
              api: api,
              companyId: companyId,
              onProfile: () => profileOpened = true,
            ),
          ),
        ),
      );
      await wait();
      await fill('Месяц YYYY-MM', '2026-01');
      await click('Показать месяц');
      await click('Профиль компании');
      expect(profileOpened, isTrue);
      await click('Проверить профиль компании');
      await click('Собрать документы за период');
      await click('Проверить контрольные соотношения');
      await click('Сохранить подготовку');
      expect(
        find.text('Проверки сохранены. Официальный отчёт ещё не сформирован.'),
        findsOneWidget,
      );
      await click('Добавить задачу');
      await fill('Название задачи', 'SYNTHETIC TAX DEADLINE');
      await fill('Срок YYYY-MM-DD', '2026-01-25');
      await fill(
        'Основание / ссылка на источник',
        'SYNTHETIC checked actual deadline',
      );
      await click('Сохранить задачу');
      expect(
        find.text(
          'Укажите название, дату YYYY-MM-DD и подтвердите проверку срока.',
        ),
        findsOneWidget,
      );
      await click('Дата и применимость срока проверены мной');
      await click('Сохранить задачу');
      await click('SYNTHETIC TAX DEADLINE');
      await fill('Название задачи', 'SYNTHETIC CORRECTED TAX');
      await fill('Срок YYYY-MM-DD', '2026-01-26');
      final status = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Статус задачи',
      );
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выполнена').last);
      await tester.pumpAndSettle();
      await click('Дата и применимость срока проверены мной');
      await click('Сохранить задачу');
      await tester.ensureVisible(find.byTooltip('История задачи'));
      await tester.tap(find.byTooltip('История задачи'));
      await wait();
      expect(find.text('SYNTHETIC TAX DEADLINE'), findsOneWidget);
      await click('Закрыть');
      await click('Календарь');
      await click('26');
      expect(find.text('Задачи на 2026-01-26'), findsOneWidget);
      expect(find.text('SYNTHETIC CORRECTED TAX'), findsOneWidget);
      await tester.runAsync(() async {
        final base = ['v1', 'companies', companyId];
        final tasks = jsonObject(
          await api.request(
            'GET',
            [...base, 'tax-calendar'],
            query: {'from': '2026-01-01', 'to': '2026-01-31'},
          ),
        );
        expect(tasks['counts']['done'], 1);
        expect(tasks['items'][0]['version'], 2);
        expect(tasks['items'][0]['due_date'], '2026-01-26');
        expect(tasks['automaticOfficialDeadlines'], false);
        final prep = jsonObject(
          await api.request('GET', [
            ...base,
            'tax-calendar',
            'preparation',
            '2026-01',
          ]),
        );
        expect(prep['ready'], true);
        expect(prep['officialReportGenerated'], false);
        expect(
          jsonObject(
            await api.request('GET', [...base, 'accounting', 'journal']),
          )['items'],
          isEmpty,
        );
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await click('Задачи');
      await click('Сохранить подготовку');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
