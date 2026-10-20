import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/ledger_scope.dart';
import '/utils/service_accounting_support.dart';
import '/utils/country_profile.dart';

Map<String, dynamic> buildServicePayload({
  required String companyId,
  required String userId,
  required String name,
  required String code,
  required String description,
  required double price,
  required String category,
  required int vat,
  required bool isCreate,
  bool isActive = true,
  LedgerScope ledgerScope = LedgerScope.accounting,
  ServiceCostingType costingType = ServiceCostingType.fixed,
  double fixedCost = 0,
  double variableCost = 0,
  double defaultUnitCost = 0,
  String currency = 'KZT',
  String notes = '',
}) {
  return {
    'name': name.trim(),
    'code': code.trim(),
    'description': description.trim(),
    'price': price,
    'base_price': price,
    'category': category.trim(),
    'vat': vat,
    'is_active': isActive,
    'costing_type': costingType.storageValue,
    'service_costing_type': costingType.storageValue,
    'fixed_cost': fixedCost,
    'variable_cost': variableCost,
    'default_unit_cost': defaultUnitCost,
    'currency': normalizeCurrencyCode(currency),
    'notes': notes.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'user_id': userId,
    'idCompany': companyId.trim(),
    'updated_at': FieldValue.serverTimestamp(),
    if (isCreate) 'created_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildSupplierPayload({
  required String companyId,
  required String userId,
  required String name,
  required String legalName,
  required String bin,
  required String category,
  required String contact,
  required String phone,
  required String email,
  required String city,
  required String note,
  required bool isCreate,
  String status = 'Активный',
  double rating = 4.5,
}) {
  return {
    'name': name.trim(),
    'legal_name': legalName.trim(),
    'bin': bin.trim(),
    'category': category.trim(),
    'contact': contact.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'city': city.trim(),
    'note': note.trim(),
    'status': status,
    'rating': rating,
    'user_id': userId,
    'idCompany': companyId.trim(),
    'updated_at': FieldValue.serverTimestamp(),
    if (isCreate) 'created_at': FieldValue.serverTimestamp(),
  };
}
