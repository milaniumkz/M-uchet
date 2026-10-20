import '/utils/ledger_scope.dart';
import '/utils/country_profile.dart';

enum WalletType {
  bankAccount,
  cashbox,
  card,
  eWallet,
  other,
}

extension WalletTypeX on WalletType {
  String get storageValue {
    switch (this) {
      case WalletType.bankAccount:
        return 'BANK_ACCOUNT';
      case WalletType.cashbox:
        return 'CASHBOX';
      case WalletType.card:
        return 'CARD';
      case WalletType.eWallet:
        return 'E_WALLET';
      case WalletType.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case WalletType.bankAccount:
        return 'Банковский счет';
      case WalletType.cashbox:
        return 'Касса';
      case WalletType.card:
        return 'Карта';
      case WalletType.eWallet:
        return 'Электронный кошелек';
      case WalletType.other:
        return 'Другое';
    }
  }
}

WalletType walletTypeFromValue(
  String? raw, {
  String? legacyTip,
  String? ownerKind,
}) {
  final normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'bank_account':
    case 'bank':
      return WalletType.bankAccount;
    case 'cashbox':
    case 'cash':
    case 'nal':
      return WalletType.cashbox;
    case 'card':
      return WalletType.card;
    case 'e_wallet':
    case 'ewallet':
    case 'wallet':
      return WalletType.eWallet;
    case 'other':
      return WalletType.other;
  }

  final tip = (legacyTip ?? '').trim().toLowerCase();
  switch (tip) {
    case 'bank':
      return WalletType.bankAccount;
    case 'nal':
    case 'cash':
      return WalletType.cashbox;
    case 'card':
      return WalletType.card;
    case 'my':
      final owner = (ownerKind ?? '').trim().toLowerCase();
      if (owner == 'card') return WalletType.card;
      if (owner == 'cash') return WalletType.cashbox;
      return WalletType.other;
    default:
      return WalletType.other;
  }
}

String normalizeWalletCurrency(String? raw) {
  return normalizeCurrencyCode(raw);
}

Map<String, dynamic> walletLedgerFields(LedgerScope ledgerScope) {
  return <String, dynamic>{
    'ledger_scope': ledgerScope.storageValue,
    'ledgerScope': ledgerScope.storageValue,
    'typeUchet': ledgerScope.legacyTypeUchet,
  };
}
