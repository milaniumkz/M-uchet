import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/product_catalog_support.dart';

void main() {
  group('product_catalog_support', () {
    test('normalizes warehouse contour labels', () {
      expect(isOfficialWarehouseLabel('Официальные товары'), isTrue);
      expect(isOfficialWarehouseLabel('Белый склад'), isTrue);
      expect(isOfficialWarehouseLabel('Неофициальные товары'), isFalse);
      expect(isOfficialWarehouseLabel('Серый склад'), isFalse);
    });

    test('calculates markup with VAT removal for official warehouse', () {
      final official = markupCoeffFromPrices(
        '100',
        '224',
        warehouse: 'Официальные товары',
      );
      final unofficial = markupCoeffFromPrices(
        '100',
        '224',
        warehouse: 'Неофициальные товары',
      );

      expect(official, closeTo(224 / 1.16 / 100, 0.0001));
      expect(unofficial, closeTo(2.24, 0.0001));
    });

    test('formats product source labels consistently', () {
      expect(
        productSourceShort({'source_type': sourceTypeManual}),
        '*',
      );
      expect(
        productSourceFull({'source_type': sourceTypeManual}),
        '* Ручной ввод',
      );
      expect(
        productSourceShort({'source_type': sourceTypeExcel}),
        'Импорт Excel',
      );
      expect(
        productSourceShort({'source_type': sourceTypeOneC}),
        'Импорт из 1С',
      );
    });
  });
}
