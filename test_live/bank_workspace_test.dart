import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/bank_workspace.dart';

class RealNetwork extends HttpOverrides {}

class SyntheticPicker extends FilePicker {
  SyntheticPicker({
    this.csv =
        'date;reference;debit;credit;description;counterparty\n2026-10-20;SYNTHETIC-UI-BANK-1;0;123.45;ТЕСТОВЫЙ ДОХОД;ТЕСТ',
  });
  final String csv;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    return FilePickerResult([
      PlatformFile(
        name: 'synthetic-bank.csv',
        size: bytes.length,
        bytes: bytes,
      ),
    ]);
  }
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real bank UI previews CSV, reviews, posts once and opens the editable ledger source',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FilePicker? previous;
      try {
        previous = FilePicker.platform;
      } catch (_) {}
      FilePicker.platform = SyntheticPicker();
      addTearDown(() {
        if (previous != null) {
          FilePicker.platform = previous;
        }
      });
      final fixture =
          jsonDecode(
                File(
                  Platform.environment['MUCHET_TEST_FIXTURE']!,
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final transport = HttpOverrides.runWithHttpOverrides(
        () => IOClient(HttpClient()),
        RealNetwork(),
      );
      final api = BackendClient(
        origin: Uri.parse(fixture['origin'] as String),
        transport: transport,
      );
      late Map<String, dynamic> company;
      Map<String, dynamic>? edited;
      await tester.runAsync(() async {
        await IdentityRepository(
          api,
        ).login(fixture['login'] as String, fixture['password'] as String);
        company = jsonObject(
          await api.request(
            'POST',
            ['v1', 'companies'],
            body: {'name': 'SYNTHETIC BANK UI FIRM', 'currency': 'KZT'},
            operation: OperationKey(),
          ),
        );
        await api.request(
          'POST',
          ['v1', 'companies', company['id'] as String, 'wallets'],
          body: {'name': 'SYNTHETIC BANK'},
          operation: OperationKey(),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BankWorkspace(
              api: api,
              companyId: company['id'] as String,
              currency: 'KZT',
              projects: const [],
              onChanged: () async {},
              onEditMoney: (entry) async {
                edited = entry;
              },
            ),
          ),
        ),
      );
      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pumpAndSettle();
      }

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      await click(find.text('Загрузить выписку'));
      await click(find.text('Выбрать CSV'));
      await click(find.text('Проверить файл'));
      expect(find.textContaining('1 строк'), findsOneWidget);
      await click(find.text('Загрузить для сопоставления'));
      expect(find.text('Требует сопоставления'), findsOneWidget);
      await click(find.text('Сопоставить'));
      await click(find.text('Вид операции'));
      await click(find.text('Доход').last);
      await click(find.text('Сохранить сопоставление'));
      await click(find.text('Провести'));
      expect(find.text('Проведено'), findsOneWidget);
      expect(find.text('123,45 ₸'), findsNWidgets(2));
      await click(find.text('Открыть и исправить'));
      expect(edited?['amount'], 12345);
      expect(edited?['kind'], 'INCOME');
      await click(find.text('Загрузить выписку'));
      await click(find.text('Выбрать CSV'));
      await click(find.text('Проверить файл'));
      expect(find.textContaining('1 дублей'), findsOneWidget);
      await click(find.text('Загрузить для сопоставления'));
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            company['id'] as String,
            'wallets',
          ]),
        );
        expect(jsonObject((wallets['items'] as List).single)['balance'], 12345);
      });
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            company['id'] as String,
            'wallets',
          ]),
        );
        final wallet = jsonObject((wallets['items'] as List).single);
        await api.request(
          'POST',
          [
            'v1',
            'companies',
            company['id'] as String,
            'wallets',
            wallet['id'] as String,
            'transactions',
          ],
          body: {
            'type': 'INCOME',
            'amount': 789,
            'description': 'SYNTHETIC ALREADY ENTERED',
            'businessDate': '2026-10-20',
          },
          operation: OperationKey(),
        );
      });
      FilePicker.platform = SyntheticPicker(
        csv:
            'date;reference;debit;credit;description;counterparty\n2026-10-20;SYNTHETIC-UI-EXISTING;0;7.89;Existing receipt;ТЕСТ',
      );
      await click(find.text('Загрузить выписку'));
      await click(find.text('Выбрать CSV'));
      await click(find.text('Проверить файл'));
      await click(find.text('Загрузить для сопоставления'));
      await click(find.text('Сопоставить'));
      await click(find.text('Вид операции'));
      await click(find.text('Уже учтённая операция').last);
      await click(find.text('SYNTHETIC ALREADY ENTERED'));
      await click(find.text('Сохранить сопоставление'));
      await click(find.text('Провести'));
      expect(find.text('Проведено'), findsOneWidget);
      await click(find.text('Открыть и исправить'));
      expect(edited?['amount'], 789);
      await tester.runAsync(() async {
        final wallets = jsonObject(
          await api.request('GET', [
            'v1',
            'companies',
            company['id'] as String,
            'wallets',
          ]),
        );
        expect(jsonObject((wallets['items'] as List).single)['balance'], 13134);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
