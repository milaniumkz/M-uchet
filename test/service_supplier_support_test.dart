import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/service_supplier_support.dart';

void main() {
  test('buildServicePayload trims and includes create timestamp on create', () {
    final payload = buildServicePayload(
      companyId: ' c1 ',
      userId: 'u1',
      name: ' Repair ',
      code: ' SRV1 ',
      description: ' Desc ',
      price: 1200,
      category: ' Auto ',
      vat: 12,
      isCreate: true,
    );

    expect(payload['name'], 'Repair');
    expect(payload['code'], 'SRV1');
    expect(payload['category'], 'Auto');
    expect(payload['idCompany'], 'c1');
    expect(payload.containsKey('created_at'), isTrue);
  });

  test('buildSupplierPayload trims and keeps default status', () {
    final payload = buildSupplierPayload(
      companyId: 'c1',
      userId: 'u1',
      name: ' Mega ',
      legalName: ' Mega LLP ',
      bin: ' 123 ',
      category: ' Food ',
      contact: ' Ali ',
      phone: ' 777 ',
      email: ' a@b.c ',
      city: ' Almaty ',
      note: ' Note ',
      isCreate: false,
    );

    expect(payload['name'], 'Mega');
    expect(payload['legal_name'], 'Mega LLP');
    expect(payload['status'], 'Активный');
    expect(payload.containsKey('created_at'), isFalse);
  });
}
