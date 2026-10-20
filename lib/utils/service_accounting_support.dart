import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/ledger_scope.dart';
import '/utils/country_profile.dart';

double serviceNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String serviceString(dynamic value) => value?.toString().trim() ?? '';

DateTime? serviceDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

enum ServiceCostingType {
  fixed,
  variable,
  mixed,
  manual,
}

extension ServiceCostingTypeX on ServiceCostingType {
  String get storageValue {
    switch (this) {
      case ServiceCostingType.fixed:
        return 'FIXED';
      case ServiceCostingType.variable:
        return 'VARIABLE';
      case ServiceCostingType.mixed:
        return 'MIXED';
      case ServiceCostingType.manual:
        return 'MANUAL';
    }
  }

  String get label {
    switch (this) {
      case ServiceCostingType.fixed:
        return 'Фиксированная';
      case ServiceCostingType.variable:
        return 'Переменная';
      case ServiceCostingType.mixed:
        return 'Смешанная';
      case ServiceCostingType.manual:
        return 'Ручная';
    }
  }
}

ServiceCostingType serviceCostingTypeFromValue(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'VARIABLE':
      return ServiceCostingType.variable;
    case 'MIXED':
      return ServiceCostingType.mixed;
    case 'MANUAL':
      return ServiceCostingType.manual;
    case 'FIXED':
    default:
      return ServiceCostingType.fixed;
  }
}

class ServiceCostModelView {
  const ServiceCostModelView({
    required this.serviceId,
    required this.costingType,
    required this.fixedCost,
    required this.variableCost,
    required this.defaultUnitCost,
    required this.currency,
    required this.ledgerScope,
    required this.notes,
  });

  final String serviceId;
  final ServiceCostingType costingType;
  final double fixedCost;
  final double variableCost;
  final double defaultUnitCost;
  final String currency;
  final LedgerScope ledgerScope;
  final String notes;

  factory ServiceCostModelView.fromMaps({
    required String serviceId,
    Map<String, dynamic>? serviceData,
    Map<String, dynamic>? costModelData,
  }) {
    final source = costModelData ?? serviceData ?? const <String, dynamic>{};
    return ServiceCostModelView(
      serviceId: serviceId,
      costingType: serviceCostingTypeFromValue(
        serviceString(source['costing_type']).isEmpty
            ? serviceString(source['service_costing_type'])
            : serviceString(source['costing_type']),
      ),
      fixedCost: serviceNum(source['fixed_cost']),
      variableCost: serviceNum(source['variable_cost']),
      defaultUnitCost: serviceNum(source['default_unit_cost']),
      currency: normalizeCurrencyCode(serviceString(source['currency'])),
      ledgerScope: ledgerScopeFromData(source),
      notes: serviceString(source['notes']),
    );
  }
}

class ServiceExecutionResult {
  const ServiceExecutionResult({
    required this.costingType,
    required this.quantity,
    required this.unitPrice,
    required this.revenueAmount,
    required this.unitCost,
    required this.costAmount,
    required this.marginAmount,
  });

  final ServiceCostingType costingType;
  final double quantity;
  final double unitPrice;
  final double revenueAmount;
  final double unitCost;
  final double costAmount;
  final double marginAmount;
}

ServiceExecutionResult calculateServiceExecution({
  required ServiceCostModelView costModel,
  required double quantity,
  required double unitPrice,
  double? manualUnitCost,
}) {
  final safeQty = quantity <= 0 ? 0.0 : quantity.toDouble();
  final revenue = safeQty * unitPrice;
  double totalCost;
  switch (costModel.costingType) {
    case ServiceCostingType.fixed:
      totalCost = safeQty *
          (costModel.fixedCost > 0
              ? costModel.fixedCost
              : costModel.defaultUnitCost);
      break;
    case ServiceCostingType.variable:
      totalCost = safeQty *
          (costModel.variableCost > 0
              ? costModel.variableCost
              : costModel.defaultUnitCost);
      break;
    case ServiceCostingType.mixed:
      totalCost =
          (safeQty * costModel.variableCost) + (safeQty * costModel.fixedCost);
      if (totalCost <= 0) {
        totalCost = safeQty * costModel.defaultUnitCost;
      }
      break;
    case ServiceCostingType.manual:
      totalCost = safeQty *
          ((manualUnitCost ?? 0) > 0
              ? manualUnitCost!
              : costModel.defaultUnitCost);
      break;
  }
  final unitCost = safeQty <= 0 ? 0.0 : totalCost / safeQty;
  return ServiceExecutionResult(
    costingType: costModel.costingType,
    quantity: safeQty,
    unitPrice: unitPrice,
    revenueAmount: revenue,
    unitCost: unitCost,
    costAmount: totalCost,
    marginAmount: revenue - totalCost,
  );
}

Map<String, dynamic> buildServiceCostModelPayload({
  required String companyId,
  required String serviceId,
  required ServiceCostingType costingType,
  required double fixedCost,
  required double variableCost,
  required double defaultUnitCost,
  required String currency,
  required LedgerScope ledgerScope,
  required String notes,
  required bool isCreate,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'service_id': serviceId.trim(),
    'costing_type': costingType.storageValue,
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'fixed_cost': fixedCost,
    'variable_cost': variableCost,
    'default_unit_cost': defaultUnitCost,
    'currency': normalizeCurrencyCode(currency),
    'notes': notes.trim(),
    'updated_at': FieldValue.serverTimestamp(),
    if (isCreate) 'created_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildServiceExecutionPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required String transactionId,
  required String serviceId,
  required String serviceName,
  required String serviceCategory,
  required String customerId,
  required String customerName,
  required String shopId,
  required String shopName,
  required String cashRegisterId,
  required String cashRegisterName,
  required LedgerScope ledgerScope,
  required ServiceExecutionResult execution,
  required String status,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'transaction_id': transactionId.trim(),
    'service_id': serviceId.trim(),
    'service_name': serviceName.trim(),
    'service_category': serviceCategory.trim(),
    'customer_id': customerId.trim(),
    'customer_name': customerName.trim(),
    'shop_id': shopId.trim(),
    'shop_name': shopName.trim(),
    'cash_register_id': cashRegisterId.trim(),
    'cash_register_name': cashRegisterName.trim(),
    'quantity': execution.quantity,
    'unit_price': execution.unitPrice,
    'revenue_amount': execution.revenueAmount,
    'unit_cost': execution.unitCost,
    'cost_amount': execution.costAmount,
    'margin_amount': execution.marginAmount,
    'service_costing_type': execution.costingType.storageValue,
    'status': status.trim().isEmpty ? 'COMPLETED' : status.trim(),
    'performed_at': FieldValue.serverTimestamp(),
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildServiceSaleCogsPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required String serviceId,
  required String serviceName,
  required LedgerScope ledgerScope,
  required ServiceExecutionResult execution,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'item_type': 'service',
    'service_id': serviceId.trim(),
    'service_name': serviceName.trim(),
    'quantity': execution.quantity,
    'unit_cost': execution.unitCost,
    'unit_cost_applied': execution.unitCost,
    'total_cost': execution.costAmount,
    'costing_method': 'SERVICE_${execution.costingType.storageValue}',
    'service_costing_type': execution.costingType.storageValue,
    'basis_type': 'SERVICE_COST_MODEL',
    'created_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildServiceCogsEntryPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required String serviceId,
  required String serviceName,
  required LedgerScope ledgerScope,
  required ServiceExecutionResult execution,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'item_kind': 'service',
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'service_id': serviceId.trim(),
    'service_name': serviceName.trim(),
    'quantity': execution.quantity,
    'qty': execution.quantity,
    'unit_cost': execution.unitCost,
    'total_cost': execution.costAmount,
    'costing_method': 'SERVICE_${execution.costingType.storageValue}',
    'service_costing_type': execution.costingType.storageValue,
    'created_at': FieldValue.serverTimestamp(),
  };
}

class ServiceReportRow {
  const ServiceReportRow({
    required this.key,
    required this.label,
    required this.category,
    required this.ledgerScope,
    required this.quantity,
    required this.revenue,
    required this.cost,
    required this.margin,
  });

  final String key;
  final String label;
  final String category;
  final LedgerScope ledgerScope;
  final double quantity;
  final double revenue;
  final double cost;
  final double margin;

  double get marginPercent => revenue <= 0 ? 0 : (margin / revenue) * 100;
}

List<ServiceReportRow> buildServiceReportRows({
  required List<Map<String, dynamic>> executionDocs,
  required String breakdown,
  LedgerScope? ledgerScope,
  DateTime? start,
  DateTime? end,
}) {
  final rows = <String, ServiceReportRow>{};
  for (final doc in executionDocs) {
    final rowScope = ledgerScopeFromData(doc);
    if (ledgerScope != null && !rowScope.matches(ledgerScope)) continue;
    final performedAt = serviceDate(doc['performed_at']) ??
        serviceDate(doc['created_at']) ??
        serviceDate(doc['updated_at']);
    if (start != null && performedAt != null && performedAt.isBefore(start)) {
      continue;
    }
    if (end != null && performedAt != null && performedAt.isAfter(end)) {
      continue;
    }
    final category = serviceString(doc['service_category']);
    final serviceName = serviceString(doc['service_name']);
    final key = switch (breakdown) {
      'category' => category.isEmpty ? 'Без категории' : category,
      'period' => performedAt == null
          ? 'Без даты'
          : '${performedAt.year}-${performedAt.month.toString().padLeft(2, '0')}',
      'ledger' => rowScope.storageValue,
      _ => serviceString(doc['service_id']).isEmpty
          ? serviceName
          : serviceString(doc['service_id']),
    };
    final label = switch (breakdown) {
      'category' => category.isEmpty ? 'Без категории' : category,
      'period' => key,
      'ledger' => rowScope.storageValue,
      _ => serviceName.isEmpty ? 'Без услуги' : serviceName,
    };
    final current = rows[key];
    final quantity = serviceNum(doc['quantity']);
    final revenue = serviceNum(doc['revenue_amount']);
    final cost = serviceNum(doc['cost_amount']);
    final margin = serviceNum(doc['margin_amount']);
    rows[key] = ServiceReportRow(
      key: key,
      label: label,
      category: category,
      ledgerScope: rowScope,
      quantity: (current?.quantity ?? 0) + quantity,
      revenue: (current?.revenue ?? 0) + revenue,
      cost: (current?.cost ?? 0) + cost,
      margin: (current?.margin ?? 0) + margin,
    );
  }
  final list = rows.values.toList();
  list.sort((a, b) => b.revenue.compareTo(a.revenue));
  return list;
}

List<ServiceReportRow> buildServiceReportRowsFromEvents({
  required List<Map<String, dynamic>> eventDocs,
  required String breakdown,
  LedgerScope? ledgerScope,
  DateTime? start,
  DateTime? end,
}) {
  final executionLikeDocs = eventDocs
      .where((doc) =>
          serviceString(doc['event_type']).toUpperCase() == 'SERVICE_PERFORMED')
      .map((doc) => <String, dynamic>{
            ...doc,
            'performed_at': doc['occurred_at'] ?? doc['created_at'],
            'service_name': serviceString(doc['service_name']),
            'service_category': serviceString(doc['service_category']),
            'quantity': serviceNum(doc['quantity']),
            'revenue_amount': serviceNum(doc['revenue']),
            'cost_amount': serviceNum(doc['cost']),
            'margin_amount':
                serviceNum(doc['margin']) > 0 || serviceNum(doc['revenue']) == 0
                    ? serviceNum(doc['margin'])
                    : serviceNum(doc['revenue']) - serviceNum(doc['cost']),
          })
      .toList(growable: false);
  return buildServiceReportRows(
    executionDocs: executionLikeDocs,
    breakdown: breakdown,
    ledgerScope: ledgerScope,
    start: start,
    end: end,
  );
}
