import 'ledger_scope.dart';

class AccountingWorkflowStage {
  static const purchase = 'purchase';
  static const warehouse = 'warehouse';
  static const sales = 'sales';
  static const planFact = 'plan_fact';
  static const reconciliation = 'reconciliation';
}

class AccountingWorkflowStatus {
  static const draft = 'draft';
  static const posted = 'posted';
  static const inReview = 'in_review';
  static const reconciled = 'reconciled';
  static const cancelled = 'cancelled';

  static const values = <String>[
    draft,
    posted,
    inReview,
    reconciled,
    cancelled,
  ];
}

String normalizeWorkflowStatus(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (AccountingWorkflowStatus.values.contains(v)) return v;
  return AccountingWorkflowStatus.draft;
}

Map<String, dynamic> workflowMeta({
  required String stage,
  required String accountingMode,
  String status = AccountingWorkflowStatus.posted,
}) {
  final ledgerScope = ledgerScopeFromLegacyValue(accountingMode);
  return <String, dynamic>{
    'workflow_stage': stage,
    'workflow_status': normalizeWorkflowStatus(status),
    'accounting_mode':
        ledgerScope == LedgerScope.both ? 'Bu' : ledgerScope.legacyTypeUchet,
    'ledger_scope': ledgerScope.storageValue,
  };
}

List<String> requiredFieldsForStage({
  required String accountingMode,
  required String stage,
}) {
  final mode =
      ledgerScopeFromLegacyValue(accountingMode) == LedgerScope.accounting
          ? 'Bu'
          : 'Up1';
  switch (stage) {
    case AccountingWorkflowStage.purchase:
      return mode == 'Bu'
          ? <String>['supplier_name', 'invoice_date', 'gtd_number']
          : <String>[
              'delivery_type',
              'vehicle_number',
              'driver_name',
              'driver_phone',
            ];
    case AccountingWorkflowStage.warehouse:
      return mode == 'Bu'
          ? <String>['product_id', 'qty', 'reason']
          : <String>['product_id', 'qty'];
    default:
      return const <String>[];
  }
}

List<String> validateRequiredFields({
  required String accountingMode,
  required String stage,
  required Map<String, dynamic> payload,
}) {
  final required = requiredFieldsForStage(
    accountingMode: accountingMode,
    stage: stage,
  );
  return required.where((key) {
    final value = payload[key];
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }).toList();
}
