import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/accounting_entry_service.dart';
import 'package:uchet_s_d/utils/kz_tax_defaults.dart';
import 'package:uchet_s_d/utils/transaction_sync.dart';

void main() {
  test('Kazakhstan tax defaults use 2026 rates', () {
    expect(kzDefaultNdsRatePercent, 16);
    expect(kzDefaultKpnRatePercent, 20);
    expect(kzDefaultNdsRate, 0.16);
    expect(kzDefaultKpnRate, 0.20);
  });

  test('transaction and accounting defaults share the same VAT rate', () {
    expect(defaultTransactionNdsRate, kzDefaultNdsRate);
    expect(TransactionSync.defaultNdsRate, kzDefaultNdsRate);
    expect(TransactionSync.defaultKpnRate, kzDefaultKpnRate);
  });
}
