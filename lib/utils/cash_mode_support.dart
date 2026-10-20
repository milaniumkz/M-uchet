import '/utils/domain_entry_adapters.dart';
import '/utils/sale_flow_support.dart';

class CashSaleUiStatePatch {
  const CashSaleUiStatePatch({
    required this.productDocs,
    required this.shiftDoc,
    required this.collectionsToInvalidate,
  });

  final List<Map<String, dynamic>> productDocs;
  final Map<String, dynamic> shiftDoc;
  final List<String> collectionsToInvalidate;
}

String requiredAccountingModeForCatalogEntry(CatalogEntryView entry) {
  return entry.isOfficial ? 'Bu' : 'Up1';
}

String? cartAccountingModeFromEntries(List<CartEntryView> cart) {
  for (final item in cart) {
    if (item.isProduct) {
      return item.isOfficial ? 'Bu' : 'Up1';
    }
  }
  return null;
}

bool productCompatibleWithCart(
  CatalogEntryView product,
  List<CartEntryView> cart,
) {
  final cartMode = cartAccountingModeFromEntries(cart);
  if (cartMode == null) return true;
  return cartMode == requiredAccountingModeForCatalogEntry(product);
}

Map<String, dynamic> buildLocalShiftSalesPatch({
  required Map<String, dynamic>? shiftDoc,
  required double cashSales,
  required double cardSales,
  required double transactions,
}) {
  return {
    ...?shiftDoc,
    'cash_sales': cashSales,
    'card_sales': cardSales,
    'transactions': transactions,
  };
}

List<Map<String, dynamic>> applySoldItemsToProductDocs({
  required List<Map<String, dynamic>> productDocs,
  required List<Map<String, dynamic>> soldCartDocs,
}) {
  final nextDocs = productDocs
      .map((doc) => Map<String, dynamic>.from(doc))
      .toList(growable: false);
  for (final sold in soldCartDocs) {
    final kind = (sold['item_kind'] ?? 'product').toString();
    if (kind != 'product') continue;
    final soldId = (sold['id'] ?? '').toString();
    final soldQty =
        num.tryParse((sold['qty'] ?? 0).toString())?.toDouble() ?? 0;
    for (final product in nextDocs) {
      if ((product['id'] ?? '').toString() != soldId) continue;
      final currentStock =
          num.tryParse((product['stock'] ?? 0).toString())?.toDouble() ?? 0;
      final purchasePrice = num.tryParse(
            (product['purchase_price'] ?? 0).toString(),
          )?.toDouble() ??
          0;
      final nextStock = (currentStock - soldQty).clamp(0, double.infinity);
      product['stock'] = nextStock;
      product['stock_value'] = nextStock * purchasePrice;
      break;
    }
  }
  return nextDocs;
}

List<Map<String, dynamic>> applyStockWritesToProductDocs({
  required List<Map<String, dynamic>> productDocs,
  required List<SaleFlowDocWrite> stockWrites,
}) {
  final nextDocs = productDocs
      .map((doc) => Map<String, dynamic>.from(doc))
      .toList(growable: false);
  for (final write in stockWrites) {
    final productId = write.reference.id;
    for (final product in nextDocs) {
      if ((product['id'] ?? '').toString() != productId) continue;
      product.addAll(write.data);
      break;
    }
  }
  return nextDocs;
}

CashSaleUiStatePatch buildCashSaleUiStatePatch({
  required List<Map<String, dynamic>> productDocs,
  required List<Map<String, dynamic>> soldCartDocs,
  List<SaleFlowDocWrite> stockWrites = const <SaleFlowDocWrite>[],
  required Map<String, dynamic>? shiftDoc,
  required double cashSales,
  required double cardSales,
  required double transactions,
}) {
  return CashSaleUiStatePatch(
    productDocs: stockWrites.isNotEmpty
        ? applyStockWritesToProductDocs(
            productDocs: productDocs,
            stockWrites: stockWrites,
          )
        : applySoldItemsToProductDocs(
            productDocs: productDocs,
            soldCartDocs: soldCartDocs,
          ),
    shiftDoc: buildLocalShiftSalesPatch(
      shiftDoc: shiftDoc,
      cashSales: cashSales,
      cardSales: cardSales,
      transactions: transactions,
    ),
    collectionsToInvalidate: const [
      'sales',
      'sales_items',
      'cogs_register',
      'sale_item_cogs',
      'batch_consumptions',
      'customer_orders',
      'customer_order_items',
      'shipments',
      'order_payments',
      'business_events',
      'inventory_batches',
      'cash_registers',
      'nomenklatura',
    ],
  );
}
