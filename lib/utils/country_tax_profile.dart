import '/utils/country_profile.dart';

class CountryTaxProfile {
  const CountryTaxProfile({
    required this.countryCode,
    required this.vatRate,
    required this.profitTaxRate,
    required this.version,
  });

  final String countryCode;
  final double vatRate;
  final double profitTaxRate;
  final String version;

  double get vatRatePercent => vatRate * 100;
  double get profitTaxRatePercent => profitTaxRate * 100;
}

const double kzDefaultNdsRatePercent = 16;
const double kzDefaultKpnRatePercent = 20;
const double kzDefaultNdsRate = kzDefaultNdsRatePercent / 100;
const double kzDefaultKpnRate = kzDefaultKpnRatePercent / 100;

CountryTaxProfile taxProfileForCountry({
  required String? countryCode,
  DateTime? date,
}) {
  final normalizedCountry = countryProfileForCode(countryCode).countryCode;
  final effectiveDate = date ?? DateTime.now();
  if (normalizedCountry == 'TJ') {
    final vat = effectiveDate.isBefore(DateTime(2027, 1, 1)) ? 0.14 : 0.13;
    final version =
        effectiveDate.isBefore(DateTime(2027, 1, 1)) ? 'tj_2026' : 'tj_2027';
    return CountryTaxProfile(
      countryCode: 'TJ',
      vatRate: vat,
      profitTaxRate: 0.18,
      version: version,
    );
  }
  return const CountryTaxProfile(
    countryCode: 'KZ',
    vatRate: kzDefaultNdsRate,
    profitTaxRate: kzDefaultKpnRate,
    version: 'kz_2026',
  );
}

CountryTaxProfile taxProfileFromData(
  Map<String, dynamic>? data, {
  DateTime? date,
}) {
  final map = data ?? const <String, dynamic>{};
  return taxProfileForCountry(
    countryCode: (map['country_code'] ??
            map['countryCode'] ??
            map['tax_profile_country'] ??
            map['taxProfileCountry'])
        ?.toString(),
    date: date,
  );
}

double normalizeTaxRate(dynamic value, double fallback) {
  if (value == null) return fallback;
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString().replaceAll(',', '.'));
  if (parsed == null || parsed < 0) return fallback;
  return parsed >= 1.0 ? parsed / 100 : parsed;
}
