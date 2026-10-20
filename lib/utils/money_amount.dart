import '/utils/country_profile.dart';

class CompanyMoneyAmount {
  const CompanyMoneyAmount({
    required this.amountOriginal,
    required this.currencyOriginal,
    required this.exchangeRateToCompany,
    required this.amountCompany,
    required this.companyCurrency,
    required this.exchangeRateSource,
    this.exchangeRateDate,
  });

  final double amountOriginal;
  final String currencyOriginal;
  final double exchangeRateToCompany;
  final double amountCompany;
  final String companyCurrency;
  final String exchangeRateSource;
  final DateTime? exchangeRateDate;

  Map<String, dynamic> toMap() => {
        'amount_original': amountOriginal,
        'amountOriginal': amountOriginal,
        'currency_original': currencyOriginal,
        'currencyOriginal': currencyOriginal,
        'exchange_rate_to_company': exchangeRateToCompany,
        'exchangeRateToCompany': exchangeRateToCompany,
        'amount_company': amountCompany,
        'amountCompany': amountCompany,
        'company_currency': companyCurrency,
        'companyCurrency': companyCurrency,
        'exchange_rate_date': exchangeRateDate,
        'exchangeRateDate': exchangeRateDate,
        'exchange_rate_source': exchangeRateSource,
        'exchangeRateSource': exchangeRateSource,
      };
}

CompanyMoneyAmount buildCompanyMoneyAmount({
  required double amountOriginal,
  required String currencyOriginal,
  required String companyCurrency,
  double? exchangeRateToCompany,
  DateTime? exchangeRateDate,
  String exchangeRateSource = 'manual',
}) {
  final originalCurrency = normalizeCurrencyCode(currencyOriginal);
  final baseCurrency = normalizeCurrencyCode(companyCurrency);
  final rate = originalCurrency == baseCurrency
      ? 1.0
      : (exchangeRateToCompany == null || exchangeRateToCompany <= 0
          ? 1.0
          : exchangeRateToCompany);
  return CompanyMoneyAmount(
    amountOriginal: amountOriginal,
    currencyOriginal: originalCurrency,
    exchangeRateToCompany: rate,
    amountCompany: amountOriginal * rate,
    companyCurrency: baseCurrency,
    exchangeRateDate: exchangeRateDate,
    exchangeRateSource:
        originalCurrency == baseCurrency ? 'same_currency' : exchangeRateSource,
  );
}

CompanyMoneyAmount buildCompanyMoneyAmountForAccountData({
  required double amountOriginal,
  required Map<String, dynamic>? accountData,
  double? exchangeRateToCompany,
  DateTime? exchangeRateDate,
  String exchangeRateSource = 'account_default',
}) {
  final data = accountData ?? const <String, dynamic>{};
  final companyCurrency = companyCurrencyFromData(
    data,
    fallback: normalizeCurrencyCode(
      (data['account_currency'] ??
              data['accountCurrency'] ??
              data['currency'] ??
              data['company_currency'] ??
              data['companyCurrency'])
          ?.toString(),
    ),
  );
  final originalCurrency = originalCurrencyFromData(
    data,
    fallback: companyCurrency,
  );
  return buildCompanyMoneyAmount(
    amountOriginal: amountOriginal,
    currencyOriginal: originalCurrency,
    companyCurrency: companyCurrency,
    exchangeRateToCompany: exchangeRateToCompany,
    exchangeRateDate: exchangeRateDate,
    exchangeRateSource: exchangeRateSource,
  );
}

Map<String, dynamic> transactionMoneyFieldsForAccountData({
  required double amountOriginal,
  required Map<String, dynamic>? accountData,
  double? exchangeRateToCompany,
  DateTime? exchangeRateDate,
  String exchangeRateSource = 'account_default',
}) {
  final money = buildCompanyMoneyAmountForAccountData(
    amountOriginal: amountOriginal,
    accountData: accountData,
    exchangeRateToCompany: exchangeRateToCompany,
    exchangeRateDate: exchangeRateDate,
    exchangeRateSource: exchangeRateSource,
  );
  return {
    'summa': money.amountCompany,
    'amount': money.amountCompany,
    ...money.toMap(),
  };
}

double companyAmountFromData(Map<String, dynamic> data) {
  final amountCompany = _num(data['amount_company'] ?? data['amountCompany']);
  if (amountCompany > 0) return amountCompany;
  final amount = _num(data['amount'] ?? data['summa']);
  return amount;
}

double originalAmountFromData(Map<String, dynamic> data) {
  final amountOriginal =
      _num(data['amount_original'] ?? data['amountOriginal']);
  if (amountOriginal > 0) return amountOriginal;
  return companyAmountFromData(data);
}

String originalCurrencyFromData(
  Map<String, dynamic> data, {
  String fallback = 'KZT',
}) {
  return normalizeCurrencyCode(
    (data['currency_original'] ??
            data['currencyOriginal'] ??
            data['account_currency'] ??
            data['accountCurrency'] ??
            data['currency'])
        ?.toString(),
    fallback: fallback,
  );
}

String companyCurrencyFromData(
  Map<String, dynamic> data, {
  String fallback = 'KZT',
}) {
  return normalizeCurrencyCode(
    (data['company_currency'] ?? data['companyCurrency'])?.toString(),
    fallback: fallback,
  );
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}
