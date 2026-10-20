import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/workspace/journal_editor.dart';

void main() {
  for (final oldProject in <String?>[null, 'retained-project']) {
    testWidgets(
      'editing journal retains its own project $oldProject without assigning the workspace filter',
      (tester) async {
        Map<String, dynamic>? saved;
        final api = BackendClient(
          origin: Uri.parse('https://api.example.test'),
          transport: MockClient((request) async {
            if (request.method == 'PUT') {
              saved = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                '{"id":"journal"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '{"items":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        )..acceptSession('a' * 43);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => JournalEditor(
                      api: api,
                      companyId: 'firm',
                      projects: const [],
                      projectId: 'workspace-filter',
                      entry: {
                        'id': 'journal',
                        'revision': 0,
                        'description': 'SYNTHETIC JOURNAL',
                        'business_date': '2026-01-10',
                        'scope': 'ACCOUNTING',
                        'project_id': oldProject,
                        'lines': [
                          {'account': 'cash', 'debit': 100, 'credit': 0},
                          {'account': 'capital', 'debit': 0, 'credit': 100},
                        ],
                      },
                    ),
                  ),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Открыть'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (oldProject != null) {
          expect(find.text('Сохранённый проект'), findsOneWidget);
        }
        final reason = find.widgetWithText(TextField, 'Причина исправления');
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'SYNTHETIC correction');
        await tester.tap(find.text('Сохранить запись'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);
        expect(saved!['projectId'], oldProject);
        expect(saved!['businessDate'], '2026-01-10');
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
}
