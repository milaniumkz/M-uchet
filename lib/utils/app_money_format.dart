import '/utils/country_profile.dart';

String companyCurrencyFromProfileData(
  Map<String, dynamic>? data, {
  String fallback = 'KZT',
}) {
  final map = data ?? const <String, dynamic>{};
  final countryProfile = countryProfileFromData(map);
  return normalizeCurrencyCode(
    (map['base_currency'] ??
            map['company_currency'] ??
            map['companyCurrency'] ??
            map['valuta'] ??
            map['currency'])
        ?.toString(),
    fallback: countryProfile.baseCurrency.isEmpty
        ? normalizeCurrencyCode(fallback)
        : countryProfile.baseCurrency,
  );
}

String moneySymbolFromProfileData(
  Map<String, dynamic>? data, {
  String fallback = 'KZT',
}) {
  final map = data ?? const <String, dynamic>{};
  final explicit = (map['currency_symbol'] ??
          map['currencySymbol'] ??
          map['simvol'] ??
          map['znak'])
      ?.toString()
      .trim();
  if (explicit != null && explicit.isNotEmpty) {
    final normalizedExplicit = normalizeCurrencyCode(explicit, fallback: '');
    if (normalizedExplicit == 'TJS') return currencySymbolForCode('TJS');
    if (normalizedExplicit == 'KZT') return currencySymbolForCode('KZT');
    return explicit;
  }
  return currencySymbolForCode(
    companyCurrencyFromProfileData(map, fallback: fallback),
  );
}

String moneySymbolForCurrency(String? currencyCode) {
  return currencySymbolForCode(currencyCode);
}

String formatMoneyWithCurrency(
  num? value, {
  String? currencyCode,
  String? symbol,
  bool signed = false,
  int fractionDigits = 0,
}) {
  final amount = (value ?? 0).toDouble();
  final sign = signed && amount > 0
      ? '+'
      : amount < 0
          ? '-'
          : '';
  final fixed = amount.abs().toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ' ',
  );
  final decimals = parts.length > 1 && fractionDigits > 0 ? '.${parts[1]}' : '';
  final rawSymbol = symbol?.trim();
  final safeSymbol = (rawSymbol?.isNotEmpty ?? false)
      ? currencySymbolForCode(normalizeCurrencyCode(rawSymbol, fallback: ''))
      : currencySymbolForCode(currencyCode);
  return '$sign$safeSymbol $whole$decimals';
}
