import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/country_profile.dart';
import 'package:uchet_s_d/utils/country_tax_profile.dart';
import 'package:uchet_s_d/utils/money_amount.dart';

void main() {
  test('legacy empty country falls back to Kazakhstan', () {
    final profile = countryProfileFromData(const {});

    expect(profile.countryCode, 'KZ');
    expect(profile.baseCurrency, 'KZT');
    expect(profile.identifierLabel, 'БИН');
  });

  test('Tajikistan profile uses local labels and currency', () {
    final profile = countryProfileForCode('TJ');

    expect(profile.countryCode, 'TJ');
    expect(profile.baseCurrency, 'TJS');
    expect(profile.currencySymbol, 'TJS');
    expect(profile.identifierLabel, 'ИНН');
    expect(profile.profitTaxLabel, 'Налог на доходы юрлиц');
  });

  test('tax profile keeps KZ rates and switches TJ VAT by date', () {
    final kz = taxProfileForCountry(countryCode: 'KZ', date: DateTime(2026));
    final tj2026 =
        taxProfileForCountry(countryCode: 'TJ', date: DateTime(2026, 6, 1));
    final tj2027 =
        taxProfileForCountry(countryCode: 'TJ', date: DateTime(2027, 1, 1));

    expect(kz.vatRate, 0.16);
    expect(kz.profitTaxRate, 0.20);
    expect(tj2026.vatRate, 0.14);
    expect(tj2026.profitTaxRate, 0.18);
    expect(tj2027.vatRate, 0.13);
  });

  test('money amount stores original and company-currency amount', () {
    final amount = buildCompanyMoneyAmount(
      amountOriginal: 100,
      currencyOriginal: 'USD',
      companyCurrency: 'TJS',
      exchangeRateToCompany: 10.5,
      exchangeRateDate: DateTime(2026, 5, 1),
    );

    expect(amount.amountOriginal, 100);
    expect(amount.currencyOriginal, 'USD');
    expect(amount.companyCurrency, 'TJS');
    expect(amount.amountCompany, 1050);
    expect(amount.exchangeRateToCompany, 10.5);
  });

  test('same currency always uses exchange rate one', () {
    final amount = buildCompanyMoneyAmount(
      amountOriginal: 250,
      currencyOriginal: 'kzt',
      companyCurrency: 'KZT',
      exchangeRateToCompany: 500,
    );

    expect(amount.amountCompany, 250);
    expect(amount.exchangeRateToCompany, 1);
    expect(amount.exchangeRateSource, 'same_currency');
  });
}
