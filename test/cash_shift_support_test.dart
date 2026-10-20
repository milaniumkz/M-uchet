import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/cash_shift_support.dart';
import 'package:uchet_s_d/utils/domain_entry_adapters.dart';

void main() {
  final cashier = CashierEntryView.fromMap({
    'id': 'cashier-1',
    'idCompany': 'c1',
    'name': 'Aruzhan',
    'shop_id': 'shop-1',
    'shop_name': 'Mega Store',
    'status': 'active',
  });

  test('buildCashShiftOpenPayload writes cashier and register fields', () {
    final payload = buildCashShiftOpenPayload(
      companyId: 'c1',
      userId: 'u1',
      openedByUserName: 'Owner',
      cashier: cashier,
      cashRegisterName: 'Касса 1',
      startingCash: 1500,
      openGeo: const {'status': 'ok'},
    );

    expect(payload['cashier_id'], 'cashier-1');
    expect(payload['shop_name'], 'Mega Store');
    expect(payload['cash_register_name'], 'Касса 1');
    expect(payload['starting_cash'], 1500);
    expect(payload['status'], 'open');
  });

  test('buildCashShiftClosePatch writes close totals', () {
    final patch = buildCashShiftClosePatch(
      endingCash: 5000,
      closeGeo: const {'status': 'ok'},
      workedMinutes: 180,
      workedHours: 3,
    );

    expect(patch['ending_cash'], 5000);
    expect(patch['worked_minutes'], 180);
    expect(patch['worked_hours'], 3);
    expect(patch['status'], 'closed');
  });
}
