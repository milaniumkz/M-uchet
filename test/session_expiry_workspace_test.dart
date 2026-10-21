import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/main_server.dart';

void main() {
  testWidgets(
    'an expired session in a nested workspace returns to login immediately',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = BackendClient(
        origin: Uri.parse('https://api.example.test'),
        transport: MockClient((request) async {
          Object value;
          switch ('${request.method} ${request.url.path}') {
            case 'POST /v1/auth/login':
              value = {
                'token': 'a' * 43,
                'user': {'id': 'owner', 'name': 'SYNTHETIC OWNER'},
              };
            case 'GET /v1/companies':
              value = [
                {
                  'id': 'one',
                  'name': 'SYNTHETIC FIRM',
                  'currency': 'KZT',
                  'role': 'owner',
                },
              ];
            case 'GET /v1/companies/one/dashboard':
              value = {
                'money': {'cash': 0, 'receivables': 0, 'payables': 0},
                'chart': [],
                'tasks': [],
                'recentDocuments': [],
                'userName': 'SYNTHETIC OWNER',
              };
            case 'GET /v1/companies/one/projects':
              value = {'items': []};
            case 'GET /v1/companies/one/reports/projects':
              value = {
                'items': [],
                'total': {
                  'revenue': 0,
                  'expenses': 0,
                  'cogs': 0,
                  'netProfit': 0,
                },
              };
            case 'GET /v1/companies/one/members':
              return http.Response(
                '{"error":"invalid_session"}',
                401,
                headers: {'content-type': 'application/json'},
              );
            default:
              throw StateError(
                'Unexpected request: ${request.method} ${request.url.path}',
              );
          }
          return http.Response(
            jsonEncode(value),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(AccountingWorkspace(client: api));
      await tester.enterText(
        find.byType(TextField).at(0),
        'synthetic@example.test',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'SYNTHETIC PASSWORD',
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Бизнес под контролем'), findsOneWidget);
      await tester.tap(find.text('Проекты'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Доступ'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Доступ').last);
      await tester.pumpAndSettle();
      expect(api.authenticated, isFalse);
      expect(find.text('Войти'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Бизнес под контролем'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
