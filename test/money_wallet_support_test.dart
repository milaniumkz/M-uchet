import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/backend/schema/tranzaction_record.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/money_wallet_support.dart';
import 'package:uchet_s_d/utils/money_wallet_types.dart';
import 'package:uchet_s_d/utils/wallet_balance_service.dart';

void main() {
  group('money wallet mapping', () {
    test('creates wallet payload for legacy account', () {
      final payload = buildMoneyWalletDataFromAccountMap(
        accountId: 'account-1',
        accountData: const {
          'title': 'Kaspi Bank',
          'tip': 'bank',
          'idCompany': 'c1',
          'summa': 1200.0,
          'opening_balance': 1000.0,
          'ledger_scope': 'ACCOUNTING',
        },
      );

      expect(payload['linked_legacy_account_id'], 'account-1');
      expect(payload['type'], WalletType.bankAccount.storageValue);
      expect(payload['current_balance'], 1200.0);
    });

    test('maps card account to card wallet type', () {
      final payload = buildMoneyWalletDataFromAccountMap(
        accountId: 'account-card',
        accountData: const {
          'title': 'Halyk Card',
          'tip': 'card',
          'idCompany': 'c1',
          'summa': 100.0,
          'ledger_scope': 'ACCOUNTING',
        },
      );

      expect(payload['type'], WalletType.card.storageValue);
      expect(payload['linked_legacy_card_id'], 'account-card');
    });

    test('creates wallet payload for cash register', () {
      final payload = buildMoneyWalletDataFromCashRegister(
        walletId: 'cashbox_c1_main_management',
        registerData: const {
          'id': 'shift-1',
          'idCompany': 'c1',
          'cash_register_name': 'Main Cash',
          'ledger_scope': 'MANAGEMENT',
          'opening_cash': 500.0,
          'ending_cash': 900.0,
        },
      );

      expect(payload['linked_legacy_cashbox_id'], 'shift-1');
      expect(payload['type'], WalletType.cashbox.storageValue);
      expect(payload['current_balance'], 900.0);
    });

    test('legacy Bu and Up1 map to accounting and management wallets', () {
      expect(
        ledgerScopeFromLegacyValue('Bu'),
        LedgerScope.accounting,
      );
      expect(
        ledgerScopeFromLegacyValue('Up1'),
        LedgerScope.management,
      );
      expect(
        ledgerScopeFromLegacyValue('Up'),
        LedgerScope.both,
      );
    });

    test('transfer fields keep from/to wallets', () {
      final payload = transferWalletFields(
        fromWalletId: 'w1',
        fromWalletName: 'Касса',
        toWalletId: 'w2',
        toWalletName: 'Банк',
      );

      expect(payload['from_wallet_id'], 'w1');
      expect(payload['to_wallet_id'], 'w2');
    });

    test('wallet balance snapshot uses linked account balance', () {
      final snapshot = computeWalletBalanceSnapshot(
        walletData: const {
          'id': 'wallet-1',
          'ledger_scope': 'ACCOUNTING',
        },
        accountData: const {
          'summa': 880.0,
          'opening_balance': 300.0,
        },
      );

      expect(snapshot.currentBalance, 880.0);
      expect(snapshot.openingBalance, 300.0);
    });

    test('legacy transaction without walletId can derive wallet from account', () {
      final walletId = legacyWalletIdFromTransactionData(const {
        'schet_id': 'account-55',
      });

      expect(walletId, walletDocIdForLegacyAccount('account-55'));
    });

    test('new transaction payload supports wallet id', () {
      final payload = createTranzactionRecordData(
        type: 'income',
        typeUchet: 'Bu',
        idCompany: 'c1',
        walletId: 'wallet-1',
        walletName: 'Kaspi',
        walletType: WalletType.bankAccount.storageValue,
        fromWalletId: 'wallet-2',
        toWalletId: 'wallet-1',
      );

      expect(payload['wallet_id'], 'wallet-1');
      expect(payload['from_wallet_id'], 'wallet-2');
      expect(payload['to_wallet_id'], 'wallet-1');
    });

    test('wallet filters by type and ledger scope', () {
      final bankWallet = {
        'type': WalletType.bankAccount.storageValue,
        'ledger_scope': LedgerScope.accounting.storageValue,
      };
      final cashWallet = {
        'type': WalletType.cashbox.storageValue,
        'ledger_scope': LedgerScope.management.storageValue,
      };

      expect(
        walletMatchesFilters(
          walletData: bankWallet,
          type: WalletType.bankAccount,
          ledgerScope: LedgerScope.accounting,
        ),
        isTrue,
      );
      expect(
        walletMatchesFilters(
          walletData: cashWallet,
          type: WalletType.bankAccount,
          ledgerScope: LedgerScope.accounting,
        ),
        isFalse,
      );
    });
  });
}
