class CountryProfile {
  const CountryProfile({
    required this.countryCode,
    required this.countryTitle,
    required this.baseCurrency,
    required this.currencySymbol,
    required this.identifierLabel,
    required this.activityLabel,
    required this.vatLabel,
    required this.profitTaxLabel,
  });

  final String countryCode;
  final String countryTitle;
  final String baseCurrency;
  final String currencySymbol;
  final String identifierLabel;
  final String activityLabel;
  final String vatLabel;
  final String profitTaxLabel;

  Map<String, dynamic> toMap() => {
        'country_code': countryCode,
        'country': countryTitle,
        'base_currency': baseCurrency,
        'currency_symbol': currencySymbol,
        'identifier_label': identifierLabel,
        'activity_label': activityLabel,
        'vat_label': vatLabel,
        'profit_tax_label': profitTaxLabel,
      };
}

const CountryProfile kazakhstanCountryProfile = CountryProfile(
  countryCode: 'KZ',
  countryTitle: 'Казахстан',
  baseCurrency: 'KZT',
  currencySymbol: '₸',
  identifierLabel: 'БИН',
  activityLabel: 'ОКЭД',
  vatLabel: 'НДС',
  profitTaxLabel: 'КПН',
);

const CountryProfile tajikistanCountryProfile = CountryProfile(
  countryCode: 'TJ',
  countryTitle: 'Таджикистан',
  baseCurrency: 'TJS',
  currencySymbol: 'TJS',
  identifierLabel: 'ИНН',
  activityLabel: 'ОКЭД',
  vatLabel: 'НДС',
  profitTaxLabel: 'Налог на доходы юрлиц',
);

CountryProfile countryProfileForCode(String? code) {
  final normalized = (code ?? '').trim().toUpperCase();
  if (normalized == 'TJ' || normalized == 'TAJIKISTAN') {
    return tajikistanCountryProfile;
  }
  return kazakhstanCountryProfile;
}

CountryProfile countryProfileFromData(Map<String, dynamic>? data) {
  final map = data ?? const <String, dynamic>{};
  final explicit = (map['country_code'] ?? map['countryCode'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  if (explicit.isNotEmpty) return countryProfileForCode(explicit);
  final country = (map['country'] ?? map['countryTitle'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (country.contains('тадж') || country.contains('tajik')) {
    return tajikistanCountryProfile;
  }
  return kazakhstanCountryProfile;
}

String normalizeCurrencyCode(String? value, {String fallback = 'KZT'}) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return fallback;
  final upper = raw.toUpperCase();
  if (upper == '₸' || upper.contains('ТЕНГЕ')) return 'KZT';
  if (upper == 'SM' || upper.contains('СОМОНИ') || upper.contains('SOMONI')) {
    return 'TJS';
  }
  if (upper.contains('KZT')) return 'KZT';
  if (upper.contains('TJS')) return 'TJS';
  if (upper.contains('USD')) return 'USD';
  if (upper.contains('EUR')) return 'EUR';
  if (upper.contains('RUB')) return 'RUB';
  return upper;
}

String currencySymbolForCode(String? code) {
  switch (normalizeCurrencyCode(code)) {
    case 'KZT':
      return '₸';
    case 'TJS':
      return 'TJS';
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'RUB':
      return '₽';
    default:
      return normalizeCurrencyCode(code);
  }
}
