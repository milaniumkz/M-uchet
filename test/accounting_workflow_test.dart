import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/accounting_workflow.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  group('normalizeWorkflowStatus', () {
    test('keeps known status', () {
      expect(
        normalizeWorkflowStatus(AccountingWorkflowStatus.reconciled),
        AccountingWorkflowStatus.reconciled,
      );
    });

    test('normalizes unknown status to draft', () {
      expect(
          normalizeWorkflowStatus('unknown'), AccountingWorkflowStatus.draft);
      expect(normalizeWorkflowStatus(null), AccountingWorkflowStatus.draft);
      expect(normalizeWorkflowStatus('  '), AccountingWorkflowStatus.draft);
    });
  });

  group('workflowMeta', () {
    test('sets Up1 mode and keeps valid status', () {
      final meta = workflowMeta(
        stage: AccountingWorkflowStage.purchase,
        accountingMode: 'Up1',
        status: AccountingWorkflowStatus.inReview,
      );

      expect(meta['workflow_stage'], AccountingWorkflowStage.purchase);
      expect(meta['workflow_status'], AccountingWorkflowStatus.inReview);
      expect(meta['accounting_mode'], 'Up1');
      expect(meta['ledger_scope'], LedgerScope.management.storageValue);
    });

    test('normalizes mode to Bu for any non-Up1 value', () {
      final meta = workflowMeta(
        stage: AccountingWorkflowStage.sales,
        accountingMode: 'anything',
        status: 'bad_status',
      );

      expect(meta['accounting_mode'], 'Bu');
      expect(meta['workflow_status'], AccountingWorkflowStatus.draft);
      expect(meta['ledger_scope'], LedgerScope.accounting.storageValue);
    });

    test('stores BOTH scope for aggregate Up mode with compatible output', () {
      final meta = workflowMeta(
        stage: AccountingWorkflowStage.sales,
        accountingMode: 'Up',
      );

      expect(meta['accounting_mode'], 'Bu');
      expect(meta['ledger_scope'], LedgerScope.both.storageValue);
    });
  });

  group('requiredFieldsForStage', () {
    test('purchase Bu requires supplier, invoice and gtd', () {
      expect(
        requiredFieldsForStage(
          accountingMode: 'Bu',
          stage: AccountingWorkflowStage.purchase,
        ),
        <String>['supplier_name', 'invoice_date', 'gtd_number'],
      );
    });

    test('purchase Up1 requires delivery fields', () {
      expect(
        requiredFieldsForStage(
          accountingMode: 'Up1',
          stage: AccountingWorkflowStage.purchase,
        ),
        <String>[
          'delivery_type',
          'vehicle_number',
          'driver_name',
          'driver_phone',
        ],
      );
    });

    test('warehouse Bu differs from Up1', () {
      expect(
        requiredFieldsForStage(
          accountingMode: 'Bu',
          stage: AccountingWorkflowStage.warehouse,
        ),
        <String>['product_id', 'qty', 'reason'],
      );
      expect(
        requiredFieldsForStage(
          accountingMode: 'Up1',
          stage: AccountingWorkflowStage.warehouse,
        ),
        <String>['product_id', 'qty'],
      );
    });

    test('unknown stage has no required fields', () {
      expect(
        requiredFieldsForStage(accountingMode: 'Bu', stage: 'unknown'),
        isEmpty,
      );
    });
  });

  group('validateRequiredFields', () {
    test('returns missing fields for null and blank strings', () {
      final missing = validateRequiredFields(
        accountingMode: 'Bu',
        stage: AccountingWorkflowStage.purchase,
        payload: <String, dynamic>{
          'supplier_name': '   ',
          'invoice_date': null,
          'gtd_number': 'GTD-1',
        },
      );

      expect(missing, <String>['supplier_name', 'invoice_date']);
    });

    test('returns empty list when all required fields are filled', () {
      final missing = validateRequiredFields(
        accountingMode: 'Up1',
        stage: AccountingWorkflowStage.warehouse,
        payload: <String, dynamic>{
          'product_id': 'p1',
          'qty': 10,
        },
      );

      expect(missing, isEmpty);
    });
  });
}
