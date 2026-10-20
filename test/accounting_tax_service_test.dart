import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/accounting_tax_service.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('computes nds payable and kpn from legacy transactions', () {
    final sources = [
      {
        'type': 'income',
        'summa': 1000.0,
        'summaNds': 120.0,
        'nds': true,
        'typeUchet': 'Bu',
        'ledger_scope': 'accounting',
        'idCompany': 'c1',
      },
      {
        'type': 'decome',
        'summa': 500.0,
        'summaNds': 60.0,
        'nds': true,
        'typeUchet': 'Bu',
        'ledger_scope': 'accounting',
        'idCompany': 'c1',
      },
    ];

    final snapshot = computeTaxSnapshot(
      sources: sources,
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 120);
    expect(snapshot.ndsPayable, 120);
    expect(snapshot.kpnAccrued, 100);
    expect(snapshot.kpnPayable, 100);
  });

  test('legacy expense VAT credit requires explicit vat_input flag', () {
    final snapshot = computeTaxSnapshot(
      sources: [
        {
          'type': 'income',
          'summa': 1000.0,
          'summaNds': 120.0,
          'nds': true,
          'typeUchet': 'Bu',
        },
        {
          'type': 'decome',
          'summa': 500.0,
          'summaNds': 60.0,
          'tax_kind': 'vat_input',
          'vat_deductible': true,
          'typeUchet': 'Bu',
        },
      ],
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 120);
    expect(snapshot.ndsPayable, 60);
  });

  test('computes nds payable from accounting entries tax metadata', () {
    final sources = [
      {
        'source_type': 'transaction',
        'amount': 1000.0,
        'ledger_scope': 'accounting',
        'tax_kind': 'vat_output',
        'tax_amount': 120.0,
      },
      {
        'source_type': 'transaction',
        'amount': 500.0,
        'ledger_scope': 'accounting',
        'tax_kind': 'vat_input',
        'tax_amount': 60.0,
      },
    ];

    final snapshot = computeTaxSnapshot(
      sources: sources,
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 120);
    expect(snapshot.ndsPayable, 60);
  });

  test('typed ledger scope tax snapshot matches legacy filter behavior', () {
    final sources = [
      {
        'source_type': 'transaction',
        'amount': 1000.0,
        'ledger_scope': LedgerScope.accounting.storageValue,
        'tax_kind': 'vat_output',
        'tax_amount': 120.0,
      },
      {
        'source_type': 'transaction',
        'amount': 500.0,
        'ledger_scope': LedgerScope.accounting.storageValue,
        'tax_kind': 'vat_input',
        'tax_amount': 60.0,
      },
    ];

    final typed = computeTaxSnapshotForScope(
      sources: sources,
      ledgerScope: LedgerScope.accounting,
      income: 1000,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );
    final legacy = computeTaxSnapshot(
      sources: sources,
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(typed.ndsAccrued, legacy.ndsAccrued);
    expect(typed.ndsPayable, legacy.ndsPayable);
    expect(typed.kpnAccrued, legacy.kpnAccrued);
  });

  test('accepts tax rates stored as percent or decimal fraction', () {
    final sources = [
      {
        'type': 'income',
        'summa': 1000.0,
        'nds': true,
        'typeUchet': 'Bu',
      },
      {
        'type': 'decome',
        'summa': 400.0,
        'deductible': true,
        'typeUchet': 'Bu',
      },
    ];

    final percent = computeTaxSnapshot(
      sources: sources,
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 400,
      ndsRate: 12,
      kpnRate: 20,
    );
    final fraction = computeTaxSnapshot(
      sources: sources,
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 400,
      ndsRate: 0.12,
      kpnRate: 0.20,
    );

    expect(fraction.ndsAccrued, percent.ndsAccrued);
    expect(fraction.ndsPayable, percent.ndsPayable);
    expect(fraction.kpnAccrued, percent.kpnAccrued);
    expect(fraction.kpnPayable, percent.kpnPayable);
  });

  test('expense deduction reduces kpn base without creating input vat', () {
    final snapshot = computeTaxSnapshot(
      sources: [
        {
          'type': 'income',
          'summa': 1000.0,
          'nds': true,
          'typeUchet': 'Bu',
        },
        {
          'type': 'decome',
          'summa': 400.0,
          'deductible': true,
          'tax_deductible': true,
          'nds': false,
          'summaNds': 0.0,
          'typeUchet': 'Bu',
        },
      ],
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 400,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 120);
    expect(snapshot.ndsPayable, 120);
    expect(snapshot.kpnAccrued, 120);
  });

  test('taxable income and deductible expense flags define kpn base', () {
    final snapshot = computeTaxSnapshot(
      sources: [
        {
          'type': 'income',
          'summa': 1000.0,
          'taxable': true,
          'nds': false,
          'typeUchet': 'Bu',
        },
        {
          'type': 'income',
          'summa': 700.0,
          'taxable': false,
          'nds': false,
          'typeUchet': 'Bu',
        },
        {
          'type': 'decome',
          'summa': 300.0,
          'deductible': true,
          'nds': false,
          'typeUchet': 'Bu',
        },
        {
          'type': 'decome',
          'summa': 200.0,
          'deductible': false,
          'nds': false,
          'typeUchet': 'Bu',
        },
      ],
      ledgerFilter: 'Bu',
      income: 1700,
      expense: 500,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 0);
    expect(snapshot.ndsPayable, 0);
    expect(snapshot.kpnAccrued, 140);
  });

  test('taxable income does not create vat without explicit nds flag', () {
    final snapshot = computeTaxSnapshot(
      sources: [
        {
          'type': 'income',
          'summa': 1000.0,
          'taxable': true,
          'nds': false,
          'typeUchet': 'Bu',
        },
      ],
      ledgerFilter: 'Bu',
      income: 1000,
      expense: 0,
      ndsRate: 16,
      kpnRate: 20,
    );

    expect(snapshot.ndsAccrued, 0);
    expect(snapshot.ndsPayable, 0);
    expect(snapshot.kpnAccrued, 200);
  });

  test('tax refund is excluded from taxable income even if flagged taxable',
      () {
    final snapshot = computeTaxSnapshot(
      sources: [
        {
          'type': 'income',
          'summa': 10512.0,
          'kat': 'Возврат налога',
          'taxable': true,
          'nds': false,
          'typeUchet': 'Bu',
        },
        {
          'type': 'income',
          'summa': 1000.0,
          'taxable': true,
          'nds': false,
          'typeUchet': 'Bu',
        },
      ],
      ledgerFilter: 'Bu',
      income: 11512,
      expense: 0,
      ndsRate: 12,
      kpnRate: 20,
    );

    expect(snapshot.kpnAccrued, 200);
  });
}
