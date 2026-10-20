import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/transaction_sync.dart';

void main() {
  group('shouldAttemptLegacyEntryRebuild', () {
    test('returns true for legacy transaction without entries metadata', () {
      final shouldRebuild = shouldAttemptLegacyEntryRebuild(
        transactionData: const {
          'type': 'income',
          'summa': 1000.0,
        },
        transactionId: 'tx-legacy',
        existingTransactionIds: const {},
      );

      expect(shouldRebuild, isTrue);
    });

    test('returns false when persisted entries already exist', () {
      final shouldRebuild = shouldAttemptLegacyEntryRebuild(
        transactionData: const {
          'type': 'income',
          'summa': 1000.0,
        },
        transactionId: 'tx-existing',
        existingTransactionIds: const {'tx-existing'},
      );

      expect(shouldRebuild, isFalse);
    });

    test('returns false when transaction already stores entry ids', () {
      final shouldRebuild = shouldAttemptLegacyEntryRebuild(
        transactionData: const {
          'entry_ids': ['entry-1'],
        },
        transactionId: 'tx-with-entry-ids',
        existingTransactionIds: const {},
      );

      expect(shouldRebuild, isFalse);
    });

    test('returns false when entries were already generated before', () {
      final shouldRebuild = shouldAttemptLegacyEntryRebuild(
        transactionData: {
          'entries_generated_at': DateTime(2025, 1, 1),
        },
        transactionId: 'tx-generated',
        existingTransactionIds: const {},
      );

      expect(shouldRebuild, isFalse);
    });
  });
}
