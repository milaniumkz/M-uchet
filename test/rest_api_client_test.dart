import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';

void main() {
  test(
      'session is accepted only from a valid server login and sent as a header',
      () async {
    final token = List.filled(43, 'A').join();
    final api = BackendClient(
        origin: Uri.parse('https://example.test'),
        transport: MockClient((request) async {
          if (request.url.path == '/v1/auth/login') {
            expect(request.headers.containsKey('Authorization'), isFalse);
            return http.Response(
                jsonEncode({
                  'token': token,
                  'user': {'id': 'user'}
                }),
                200);
          }
          expect(request.headers['Authorization'], 'Bearer $token');
          expect(request.url.query.contains(token), isFalse);
          return http.Response(
              '[{"id":"company","name":"Synthetic","currency":"KZT"}]', 200);
        }));
    addTearDown(api.close);
    final identity = IdentityRepository(api);
    await identity.login('synthetic', 'test-only-password');
    expect((await identity.companies()).single.id, 'company');
  });

  test('401 clears the in-memory session; errors remain visible to the caller',
      () async {
    final api = BackendClient(
        origin: Uri.parse('https://example.test'),
        transport: MockClient(
            (_) async => http.Response('{"error":"invalid_session"}', 401)));
    addTearDown(api.close);
    api.acceptSession(List.filled(43, 'A').join());
    await expectLater(
        api.request('GET', ['v1', 'companies']),
        throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 401)));
    expect(api.authenticated, isFalse);
  });

  test(
      'catalog save sends version and retains conflict instead of overwriting silently',
      () async {
    final api = BackendClient(
        origin: Uri.parse('https://example.test'),
        transport: MockClient((request) async {
          expect(jsonDecode(request.body)['version'], 3);
          return http.Response('{"error":"version_conflict"}', 409);
        }));
    addTearDown(api.close);
    api.acceptSession(List.filled(43, 'A').join());
    await expectLater(
        CatalogRepository(api, 'company')
            .save('clients', ResourceDto('id', {}, 3), {'name': 'Changed'}),
        throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 409)));
  });

  test(
      'deal retries retain the same operation key and never put credentials in URL',
      () async {
    final keys = <String?>[];
    final api = BackendClient(
        origin: Uri.parse('http://127.0.0.1:8080'),
        transport: MockClient((request) async {
          keys.add(request.headers['Idempotency-Key']);
          return http.Response('{"id":"order"}', 200);
        }));
    addTearDown(api.close);
    api.acceptSession(List.filled(43, 'A').join());
    final operation = OperationKey(),
        repository = DealRepository(api, 'company');
    await repository.edit('order', {}, operation: operation);
    await repository.edit('order', {}, operation: operation);
    expect(keys, [operation.value, operation.value]);
    expect(() => BackendClient(origin: Uri.parse('http://public.example')),
        throwsArgumentError);
  });
}
