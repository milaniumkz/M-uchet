import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';

void main() {
  test(
      'Dart repositories use real API and PostgreSQL for a sale and later edit',
      () async {
    final fixturePath = Platform.environment['MUCHET_TEST_FIXTURE'];
    if (fixturePath == null) {
      fail('Run make test-client-e2e; no mock fallback is provided.');
    }
    final fixture =
        jsonObject(jsonDecode(await File(fixturePath).readAsString()));
    final client =
        BackendClient(origin: Uri.parse(fixture['origin'] as String));
    addTearDown(client.close);
    final identity = IdentityRepository(client);
    await identity.login(
        fixture['login'] as String, fixture['password'] as String);
    final company = (await identity.companies()).single;
    final catalog = CatalogRepository(client, company.id);
    final product = await catalog
        .create('nomenklatura', {'name': 'SYNTHETIC DART PRODUCT'});
    final warehouse = await catalog
        .create('warehouses', {'name': 'SYNTHETIC DART WAREHOUSE'});
    expect((await catalog.list('nomenklatura')).single.id, product.id);
    final updated = await catalog
        .save('nomenklatura', product, {'name': 'EDITED SYNTHETIC PRODUCT'});
    expect(updated.version, 2);
    await expectLater(
        catalog.save('nomenklatura', product, {'name': 'Stale'}),
        throwsA(isA<BackendException>()
            .having((error) => error.status, 'status', 409)));
    final prefix = ['v1', 'companies', company.id];
    final item = {'productId': product.id, 'warehouseId': warehouse.id};
    Future<Map<String, dynamic>> command(List<String> path,
            {Map<String, dynamic>? body}) async =>
        jsonObject(await client.request('POST', [...prefix, ...path],
            body: body, operation: OperationKey()));
    await command(['inventory', 'receipts'],
        body: {...item, 'quantity': 10, 'unitCost': 100});
    final order = await command([
      'orders'
    ], body: {
      'items': [
        {...item, 'quantity': 4, 'unitPrice': 200}
      ]
    });
    final id = order['id'] as String;
    await command(['orders', id, 'reserve']);
    await command(['orders', id, 'ship']);
    await command(['orders', id, 'payments'], body: {'amount': 800});
    final edited = await DealRepository(client, company.id).edit(
        id,
        {
          'items': [
            {...item, 'quantity': 3, 'unitPrice': 200}
          ]
        },
        operation: OperationKey());
    expect(edited['status'], 'CLOSED');
    expect(edited['customerCredit'], 200);
    final stock =
        jsonObject(await client.request('GET', [...prefix, 'inventory']));
    expect(jsonObject((stock['items'] as List).single)['quantity'], 7);
    await identity.logout();
    expect(client.authenticated, isFalse);
  });
}
