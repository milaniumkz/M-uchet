import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/main_server.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'real workspace login creates a dynamic project and switches its report',
      (tester) async {
    final fixture = jsonDecode(
        File(Platform.environment['MUCHET_TEST_FIXTURE']!)
            .readAsStringSync()) as Map<String, dynamic>;
    final transport = HttpOverrides.runWithHttpOverrides(
        () => IOClient(HttpClient()), RealNetwork());
    final client = BackendClient(
        origin: Uri.parse(fixture['origin'] as String), transport: transport);
    await tester.pumpWidget(AccountingWorkspace(client: client));
    await tester.enterText(
        find.byType(TextField).at(0), fixture['login'] as String);
    await tester.enterText(
        find.byType(TextField).at(1), fixture['password'] as String);
    await tester.runAsync(() async {
      await tester.tap(find.text('Войти'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pumpAndSettle();
    expect(find.text('Бизнес под контролем'), findsOneWidget);
    await tester.tap(find.byTooltip('Создать проект'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Свой новый проект');
    await tester.runAsync(() async {
      await tester.tap(find.text('Создать'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вся фирма'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Свой новый проект').last);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('Общие операции фирмы'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Доход / расход'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('Добавьте денежный счёт'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Счёт проекта');
    await tester.runAsync(() async {
      await tester.tap(find.text('Создать'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('Денежная операция'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '1000,25');
    await tester.enterText(
        find.byType(TextField).at(1), 'Доход собственного проекта');
    await tester.runAsync(() async {
      await tester.tap(find.text('Сохранить'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('1000.25 KZT'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
