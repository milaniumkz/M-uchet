import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/access_workspace.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real access UI invites a private reader, accepts code and revokes membership immediately',
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
      BackendClient client() => BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: HttpOverrides.runWithHttpOverrides(
          () => IOClient(HttpClient()),
          RealNetwork(),
        ),
      );
      final owner = client(), worker = client();
      late String companyId;
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.runAsync(() async {
        await IdentityRepository(
          owner,
        ).login(fixture['login'] as String, fixture['password'] as String);
        final company = jsonObject(
          await owner.request(
            'POST',
            ['v1', 'companies'],
            body: {'name': 'SYNTHETIC ACCESS UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        companyId = company['id'] as String;
      });
      Future<void> pumpOwner() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccessWorkspace(
                key: UniqueKey(),
                api: owner,
                companyId: companyId,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 450)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pumpAndSettle();
      }

      await pumpOwner();
      await click(find.text('Пригласить пользователя'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Имя пользователя'),
        'SYNTHETIC UI READER',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Электронная почта'),
        'synthetic-access-ui@example.test',
      );
      await click(find.widgetWithText(DropdownButtonFormField<String>,'Набор полномочий'));
      await click(find.text('Наблюдатель без кадровых данных').last);
      await click(find.text('Создать приглашение'));
      final code =
          tester
                  .widget<InvitationCodeDialog>(
                    find.byType(InvitationCodeDialog),
                  )
                  .invitation['token']
              as String;
      await click(find.text('Скопировать код'));
      expect(copied, code);
      await click(find.text('Готово'));
      Map<String, dynamic>? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  accepted = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => InvitationAcceptanceDialog(
                      api: worker,
                      initialToken: code,
                    ),
                  );
                },
                child: const Text('Ввести код'),
              ),
            ),
          ),
        ),
      );
      await click(find.text('Ввести код'));
      await click(find.text('Проверить приглашение'));
      expect(find.text('Фирма: SYNTHETIC ACCESS UI FIRM'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Создайте пароль, от 12 символов'),
        'SYNTHETIC UI MEMBER PASSWORD',
      );
      await click(find.text('Принять приглашение').last);
      expect(accepted?['companyId'], companyId);
      await tester.runAsync(() async {
        await IdentityRepository(
          worker,
        ).login(accepted!['login'] as String, accepted!['password'] as String);
        expect(
          (await IdentityRepository(worker).companies()).single.role,
          'member',
        );
        await worker.request('GET', [
          'v1',
          'companies',
          companyId,
          'reports',
          'projects',
        ]);
        await expectLater(
          worker.request('GET', ['v1', 'companies', companyId, 'employees']),
          throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 403),
          ),
        );
      });
      await pumpOwner();
      await click(find.byTooltip('Отозвать доступ'));
      await click(find.widgetWithText(FilledButton, 'Отозвать доступ'));
      await tester.runAsync(() async {
        expect(await IdentityRepository(worker).companies(), isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      owner.close();
      worker.close();
    },
  );
}
