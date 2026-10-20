import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/domain_entry_adapters.dart';
import '/utils/product_portfolio_support.dart';

Map<String, dynamic> buildProductDiscountSetPayload(
  InventoryEntryView entry,
  int percent,
) {
  return <String, dynamic>{
    'discount_percent': percent,
    'discount_reason': productDiscountReason(entry),
    'discount_updated_at': FieldValue.serverTimestamp(),
    'discount_started_at':
        entry.discountStartedAt ?? FieldValue.serverTimestamp(),
    'category_at_discount': entry.category,
    'category_before_discount':
        entry.categoryBeforeDiscount.isNotEmpty
            ? entry.categoryBeforeDiscount
            : entry.category,
  };
}

Map<String, dynamic> buildProductDiscountClearPayload() {
  return <String, dynamic>{
    'discount_percent': FieldValue.delete(),
    'discount_reason': FieldValue.delete(),
    'discount_updated_at': FieldValue.serverTimestamp(),
    'discount_started_at': FieldValue.delete(),
  };
}

Map<String, dynamic> buildProductDiscountLocalPatch(
  InventoryEntryView entry,
  int percent,
) {
  return <String, dynamic>{
    'discount_percent': percent,
    'discount_started_at': entry.discountStartedAt ?? DateTime.now(),
    'category_before_discount':
        entry.categoryBeforeDiscount.isNotEmpty
            ? entry.categoryBeforeDiscount
            : entry.category,
  };
}

Map<String, dynamic> buildProductDiscountClearLocalPatch() {
  return <String, dynamic>{
    'discount_percent': null,
    'discount_started_at': null,
  };
}
