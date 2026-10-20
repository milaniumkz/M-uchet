import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/retriable_command.dart';
import 'package:uchet_s_d/workspace/commercial_repository.dart';
import 'package:uchet_s_d/workspace/document_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'unknown network outcome retries the original intent and key even if form data changes',
      () async {
    final requests = <http.Request>[];
    final api = BackendClient(
        origin: Uri.parse('https://api.example.test'),
        transport: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            throw http.ClientException('SYNTHETIC LOST RESPONSE');
          }
          return http.Response('{"id":"saved"}', 200,
              headers: {'content-type': 'application/json'});
        }));
    api.acceptSession('a' * 43);
    addTearDown(api.close);
    final body = <String, dynamic>{
      'amount': 12345,
      'nested': {'name': 'original'}
    };
    final intent = RetriableCommand(
        'POST', ['v1', 'companies', 'one', 'commercial-documents'], body);
    await expectLater(
        intent.execute(api),
        throwsA(isA<BackendException>()
            .having((e) => e.code, 'code', 'network_error')));
    body['amount'] = 99999;
    (body['nested'] as Map<String, dynamic>)['name'] = 'changed';
    expect((await intent.execute(api))['id'], 'saved');
    expect(requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key']);
    expect(requests[0].body, requests[1].body);
    expect(jsonDecode(requests[1].body), {
      'amount': 12345,
      'nested': {'name': 'original'}
    });
  });
  test(
      'money input preserves minor units and rejects ambiguous/excess precision',
      () {
    expect(parseMoney('12 345,67'), 1234567);
    expect(parseMoney('0.01'), 1);
    expect(() => parseMoney('1.001'), throwsFormatException);
    expect(() => parseMoney('1e5'), throwsFormatException);
    expect(moneyText(-1234567, 'KZT'), '-12 345,67 ₸');
  });
  test(
      'printable PDF embeds Cyrillic fonts and renders a multi-line service document',
      () async {
    final items = List.generate(
        45,
        (i) => {
              'description':
                  'ТЕСТ: разработка и сопровождение программного обеспечения № ${i + 1}',
              'unit': 'услуга',
              'quantity': '1.000',
              'unitPrice': 10000,
              'net': 10000,
              'vat': 1600,
              'total': 11600
            });
    final bytes = await documentPdf({
      'kind': 'SALE_ACT',
      'number': 'ТЕСТ-2026-000001',
      'business_date': '2026-10-20',
      'status': 'DRAFT',
      'data': {
        'issuer': {
          'legal_name': 'СИНТЕТИЧЕСКАЯ ФИРМА — ТЕСТ',
          'identifier': '000000000000'
        },
        'counterparty': {
          'name': 'ТЕСТОВЫЙ КЛИЕНТ',
          'identifier': '000000000001'
        },
        'externalNumber': '',
        'vatReason': '',
        'note': 'Только синтетические данные для проверки печатной формы.',
        'items': items,
        'net': 450000,
        'vat': 72000,
        'total': 522000
      }
    }, 'KZT');
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
    final capture = Platform.environment['MUCHET_PDF_CAPTURE'];
    if (capture != null) await File(capture).writeAsBytes(bytes);
  });
}
