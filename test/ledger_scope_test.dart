import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  group('ledgerScopeFromLegacyValue', () {
    test('maps Bu to ACCOUNTING', () {
      expect(ledgerScopeFromLegacyValue('Bu'), LedgerScope.accounting);
      expect(
        ledgerScopeFromLegacyValue('ACCOUNTING').storageValue,
        'ACCOUNTING',
      );
    });

    test('maps Up1 to MANAGEMENT', () {
      expect(ledgerScopeFromLegacyValue('Up1'), LedgerScope.management);
      expect(
        ledgerScopeFromLegacyValue('MANAGEMENT').storageValue,
        'MANAGEMENT',
      );
    });

    test('maps mixed and aggregate values to BOTH', () {
      expect(ledgerScopeFromLegacyValue('Up'), LedgerScope.both);
      expect(ledgerScopeFromLegacyValue('BOTH'), LedgerScope.both);
      expect(ledgerScopeFromLegacyValue('all'), LedgerScope.both);
    });
  });

  group('ledgerScopeFields', () {
    test('keeps legacy typeUchet and writes ledger_scope', () {
      final fields = ledgerScopeFields(ledgerScope: LedgerScope.accounting);

      expect(fields['ledger_scope'], 'ACCOUNTING');
      expect(fields['ledgerScope'], 'ACCOUNTING');
      expect(fields['typeUchet'], 'Bu');
    });

    test('allows explicit legacy typeUchet override', () {
      final fields = ledgerScopeFields(
        ledgerScope: LedgerScope.management,
        legacyTypeUchet: 'Up1',
      );

      expect(fields['ledger_scope'], 'MANAGEMENT');
      expect(fields['typeUchet'], 'Up1');
    });
  });

  group('ledgerScopeFromData', () {
    test('prefers explicit ledger_scope field', () {
      expect(
        ledgerScopeFromData({'ledger_scope': 'MANAGEMENT'}),
        LedgerScope.management,
      );
      expect(
        ledgerScopeFromData({'ledgerScope': 'ACCOUNTING'}),
        LedgerScope.accounting,
      );
    });

    test('falls back to legacy typeUchet field', () {
      expect(
        ledgerScopeFromData({'typeUchet': 'Bu'}),
        LedgerScope.accounting,
      );
      expect(
        ledgerScopeFromData({'accounting_mode': 'Up1'}),
        LedgerScope.management,
      );
    });
  });

  group('ledgerScopeMatchesFilter', () {
    test('combined filter matches both ledgers', () {
      expect(
        ledgerScopeMatchesFilter(rawValue: 'Bu', rawFilter: 'Up'),
        isTrue,
      );
      expect(
        ledgerScopeMatchesFilter(rawValue: 'Up1', rawFilter: 'Up'),
        isTrue,
      );
    });

    test('single filter matches only same ledger', () {
      expect(
        ledgerScopeMatchesFilter(rawValue: 'Bu', rawFilter: 'Bu'),
        isTrue,
      );
      expect(
        ledgerScopeMatchesFilter(rawValue: 'Up1', rawFilter: 'Bu'),
        isFalse,
      );
    });
  });

  group('warehouseTypeFromData', () {
    test('uses explicit isOfficial field when present', () {
      expect(
        warehouseTypeFromData({'isOfficial': true}),
        WarehouseType.official,
      );
      expect(
        warehouseTypeFromData({'is_official': false}),
        WarehouseType.unofficial,
      );
    });

    test('uses explicit warehouseType field when present', () {
      expect(
        warehouseTypeFromData({'warehouseType': 'OFFICIAL'}),
        WarehouseType.official,
      );
      expect(
        warehouseTypeFromData({'warehouse_type': 'UNOFFICIAL'}),
        WarehouseType.unofficial,
      );
    });

    test('maps legacy warehouse labels compatibly', () {
      expect(
        warehouseTypeFromData({'warehouse': 'Официальные товары'}),
        WarehouseType.official,
      );
      expect(
        warehouseTypeFromData({'warehouse': 'Неофициальные товары'}),
        WarehouseType.unofficial,
      );
      expect(
        warehouseTypeFromData({'parentWarehouse': 'Серый склад'}),
        WarehouseType.unofficial,
      );
    });
  });
}
