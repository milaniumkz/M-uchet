import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/personal_money_entry_filter.dart';

void main() {
  group('personal money entry filter', () {
    test('keeps only manual personal money records', () {
      final entries = [
        {
          'id': 'manual-expense',
          'source': 'manual',
          'scope': 'personal',
          'entry_type': 'expense',
        },
        {
          'id': 'company-expense',
          'source': 'company_expense',
          'scope': 'personal',
          'entry_type': 'expense',
        },
        {
          'id': 'owner-opening',
          'source': 'personal_investment',
          'scope': 'personal',
          'entry_type': 'expense',
        },
        {
          'id': 'linked-manual-company-record',
          'source': 'manual',
          'scope': 'personal',
          'tranzaction_id': 'tx-1',
        },
      ];

      final visibleIds = filterPersonalMoneyEntries(entries)
          .map((entry) => entry['id'])
          .toList();

      expect(visibleIds, ['manual-expense']);
    });

    test('keeps new section marker even when source is missing', () {
      expect(
        isPersonalMoneyEntry(const {
          'section': personalMoneySection,
          'entry_scope': personalMoneySection,
        }),
        isTrue,
      );
    });
  });
}
