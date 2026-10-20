import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/domain_entry_adapters.dart';
import 'package:uchet_s_d/utils/product_portfolio_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

InventoryEntryView _entry({
  double stock = 10,
  double salesCount = 2,
  String abc = 'C',
  double discountPercent = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastSaleAt,
  DateTime? discountStartedAt,
  double purchasePrice = 100,
  double costPrice = 100,
  double revenue = 1000,
  double discountSalesCount = 0,
  double discountSalesSum = 0,
  double minStock = 3,
}) {
  return InventoryEntryView(
    id: 'i1',
    companyId: 'c1',
    name: 'Item',
    article: 'A1',
    category: 'Main',
    categoryBeforeDiscount: '',
    categoryAtDiscount: '',
    warehouse: 'Официальные товары',
    warehouseType: WarehouseType.official,
    stock: stock,
    revenue: revenue,
    profit: 200,
    abc: abc,
    discountPercent: discountPercent,
    createdAt: createdAt,
    updatedAt: updatedAt,
    lastSaleAt: lastSaleAt,
    discountStartedAt: discountStartedAt,
    discountUpdatedAt: null,
    minStock: minStock,
    purchasePrice: purchasePrice,
    costPrice: costPrice,
    salePrice: 150,
    salesCount: salesCount,
    discountSalesCount: discountSalesCount,
    discountSalesSum: discountSalesSum,
  );
}

void main() {
  test('recommended discount grows with aging and turnover', () {
    final entry = _entry(
      stock: 30,
      salesCount: 2,
      abc: 'C',
      lastSaleAt: DateTime.now().subtract(const Duration(days: 120)),
    );

    expect(productRecommendedDiscountPercent(entry), greaterThanOrEqualTo(15));
  });

  test('abc A reduces recommended discount', () {
    final entry = _entry(
      stock: 30,
      salesCount: 2,
      abc: 'A',
      lastSaleAt: DateTime.now().subtract(const Duration(days: 120)),
    );

    expect(productRecommendedDiscountPercent(entry), lessThanOrEqualTo(15));
  });

  test('purchase request uses min stock', () {
    expect(productNeedsPurchaseRequest(_entry(stock: 2, minStock: 3)), isTrue);
    expect(productNeedsPurchaseRequest(_entry(stock: 5, minStock: 3)), isFalse);
  });

  test('discount summary aggregates source entries', () {
    final summary = buildProductDiscountSummary([
      _entry(
        discountPercent: 10,
        abc: 'A',
        stock: 10,
        purchasePrice: 50,
        discountSalesCount: 1,
        discountSalesSum: 500,
        lastSaleAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
      _entry(
        discountPercent: 0,
        abc: 'B',
        stock: 4,
        salesCount: 4,
        lastSaleAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      _entry(
        discountPercent: 5,
        abc: 'C',
        stock: 8,
        salesCount: 0,
        purchasePrice: 20,
        lastSaleAt: DateTime.now().subtract(const Duration(days: 190)),
      ),
    ]);

    expect(summary.discountedCount, 2);
    expect(summary.noSalesCount, 1);
    expect(summary.abcA, 1);
    expect(summary.abcB, 1);
    expect(summary.abcC, 1);
    expect(summary.discountedSalesAmount, greaterThan(0));
    expect(summary.totalStaleCost, greaterThan(0));
  });
}
