import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/main_server.dart';

void main() {
  testWidgets('first login with no firms creates a firm and opens its real empty report', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final api = BackendClient(origin: Uri.parse('https://api.example.test'), transport: MockClient((request) async {
      requests.add(request);
      Object result;
      switch ('${request.method} ${request.url.path}') {
        case 'POST /v1/auth/login':
          result = {'token': 'a' * 43, 'user': {'id': 'owner', 'name': 'SYNTHETIC OWNER'}};
        case 'GET /v1/companies': result = [];
        case 'POST /v1/companies':
          expect(jsonDecode(request.body), {'name': 'Моя фирма', 'currency': 'KZT'});
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          result = {'id': 'new-firm', 'name': 'Моя фирма', 'currency': 'KZT'};
        case 'GET /v1/companies/new-firm/projects': result = {'items': []};
        case 'GET /v1/companies/new-firm/reports/projects':
          result = {'items': [], 'total': {'income': 0, 'expense': 0, 'profit': 0}, 'unassigned': {'income': 0, 'expense': 0, 'profit': 0}};
        default: throw StateError('Unexpected request: ${request.method} ${request.url}');
      }
      return http.Response(jsonEncode(result), 200, headers: {'content-type': 'application/json'});
    }));
    await tester.pumpWidget(AccountingWorkspace(client: api));
    await tester.enterText(find.byType(TextField).at(0), 'owner@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'synthetic-password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Создать фирму'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'Моя фирма');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать фирму'));
    await tester.pumpAndSettle();
    expect(find.text('Бизнес под контролем'), findsOneWidget);
    expect(find.text('Создать фирму'), findsNothing);
    expect(requests.where((r) => r.method == 'POST' && r.url.path == '/v1/companies').length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
