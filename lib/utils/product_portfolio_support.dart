import '/utils/domain_entry_adapters.dart';

class ProductDiscountSummary {
  const ProductDiscountSummary({
    required this.discountedCount,
    required this.noSalesCount,
    required this.riskyCount,
    required this.avgTurnover,
    required this.totalStaleCost,
    required this.discountedSalesAmount,
    required this.abcA,
    required this.abcB,
    required this.abcC,
  });

  final int discountedCount;
  final int noSalesCount;
  final int riskyCount;
  final double avgTurnover;
  final double totalStaleCost;
  final double discountedSalesAmount;
  final int abcA;
  final int abcB;
  final int abcC;
}

int productStockAgingDays(InventoryEntryView entry, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final basis = entry.lastSaleAt ?? entry.updatedAt ?? entry.createdAt;
  if (basis == null) return 0;
  return current.difference(basis).inDays;
}

String productAgingZoneLabel(int days) {
  if (days > 180) return '>180 дн';
  if (days > 90) return '90+ дн';
  if (days >= 30) return '30-90 дн';
  return '<30 дн';
}

bool productNeedsPurchaseRequest(InventoryEntryView entry) {
  return entry.stock <= entry.minStock;
}

double productTurnoverDays(InventoryEntryView entry) {
  if (entry.stock <= 0) return 0;
  if (entry.salesCount <= 0) return 999;
  return (entry.stock / entry.salesCount) * 30.0;
}

int productAbcWeight(InventoryEntryView entry) {
  switch (entry.abc) {
    case 'A':
      return 0;
    case 'B':
      return 1;
    default:
      return 2;
  }
}

int productRecommendedDiscountPercent(
  InventoryEntryView entry, {
  DateTime? now,
}) {
  final aging = productStockAgingDays(entry, now: now);
  final turnover = productTurnoverDays(entry);

  var percent = 0;
  if (aging > 180 || turnover >= 120) {
    percent = 20;
  } else if (aging > 90 || turnover >= 90) {
    percent = 15;
  } else if (aging >= 30 || turnover >= 45) {
    percent = 10;
  }

  if (entry.abc == 'A') return (percent - 5).clamp(0, 15);
  if (entry.abc == 'B') return (percent - 2).clamp(0, 18);
  return percent;
}

int productDaysWithoutSales(InventoryEntryView entry, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final basis = entry.lastSaleAt ?? entry.createdAt ?? entry.updatedAt;
  if (basis == null) return 0;
  return current.difference(basis).inDays;
}

String productTurnoverLabel(InventoryEntryView entry, {DateTime? now}) {
  final days = productTurnoverDays(entry);
  if (days >= 999) {
    return 'нет продаж ${productDaysWithoutSales(entry, now: now)} дн';
  }
  return '${days.toStringAsFixed(0)} дн';
}

String productDiscountReason(InventoryEntryView entry, {DateTime? now}) {
  final aging = productStockAgingDays(entry, now: now);
  final turnover = productTurnoverDays(entry);
  final turnoverText =
      turnover >= 999 ? 'нет продаж' : '${turnover.toStringAsFixed(0)} дн';
  return 'ABC:${entry.abc}, залежалость $aging дн, оборачиваемость $turnoverText';
}

int productDiscountDays(InventoryEntryView entry, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final started = entry.discountStartedAt ?? entry.discountUpdatedAt;
  if (started == null) return 0;
  return current.difference(started).inDays.clamp(0, 99999);
}

int productDiscountSalesCount(InventoryEntryView entry) {
  if (entry.discountSalesCount > 0) return entry.discountSalesCount.toInt();
  return entry.salesCount.toInt();
}

double productDiscountSalesAmount(InventoryEntryView entry) {
  if (entry.discountSalesSum > 0) return entry.discountSalesSum;
  return entry.revenue;
}

double productStaleCost(InventoryEntryView entry) {
  final purchase =
      entry.purchasePrice > 0 ? entry.purchasePrice : entry.costPrice;
  return entry.stock * purchase;
}

ProductDiscountSummary buildProductDiscountSummary(
  Iterable<InventoryEntryView> source, {
  DateTime? now,
}) {
  final items = source.toList();
  final discounted = items.where((entry) => entry.discountPercent > 0).toList();
  final noSalesCount =
      discounted.where((entry) => productDiscountSalesCount(entry) <= 0).length;
  final riskyCount = items
      .where((entry) =>
          productStockAgingDays(entry, now: now) > 90 ||
          productTurnoverDays(entry) >= 90)
      .length;
  final turnoverValues = items
      .map(productTurnoverDays)
      .where((days) => days > 0 && days < 999)
      .toList();
  final avgTurnover = turnoverValues.isEmpty
      ? 0.0
      : turnoverValues.reduce((a, b) => a + b) / turnoverValues.length;

  return ProductDiscountSummary(
    discountedCount: discounted.length,
    noSalesCount: noSalesCount,
    riskyCount: riskyCount,
    avgTurnover: avgTurnover,
    totalStaleCost: discounted.fold<double>(
        0.0, (sum, entry) => sum + productStaleCost(entry)),
    discountedSalesAmount: discounted.fold<double>(
        0.0, (sum, entry) => sum + productDiscountSalesAmount(entry)),
    abcA: items.where((entry) => entry.abc == 'A').length,
    abcB: items.where((entry) => entry.abc == 'B').length,
    abcC: items.where((entry) => entry.abc == 'C').length,
  );
}
