import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_costing_method.dart';

void main() {
  test('resolveInventoryCostingMethod defaults to FIFO', () {
    expect(
      resolveInventoryCostingMethod(),
      InventoryCostingMethod.fifo,
    );
  });

  test('resolveInventoryCostingMethod reads product override', () {
    expect(
      resolveInventoryCostingMethod(
        productData: const {'inventory_costing_method': 'WEIGHTED_AVERAGE'},
      ),
      InventoryCostingMethod.weightedAverage,
    );
  });
}
