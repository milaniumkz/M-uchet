import '/utils/debt_aging_service.dart';
import '/utils/debt_register_support.dart';
import '/utils/ledger_scope.dart';

class DebtRegisterRow {
  const DebtRegisterRow({
    required this.id,
    required this.type,
    required this.counterpartyName,
    required this.sourceType,
    required this.sourceDocumentId,
    required this.totalAmount,
    required this.remainingAmount,
    required this.ledgerScope,
    required this.status,
    required this.createdAt,
    required this.dueDate,
    required this.creditLimit,
    required this.isCreditLimitExceeded,
    required this.agingDays,
  });

  final String id;
  final DebtType type;
  final String counterpartyName;
  final String sourceType;
  final String sourceDocumentId;
  final double totalAmount;
  final double remainingAmount;
  final LedgerScope ledgerScope;
  final DebtStatus status;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final double creditLimit;
  final bool isCreditLimitExceeded;
  final int agingDays;
}

class DebtRegisterSummary {
  const DebtRegisterSummary({
    required this.arTotal,
    required this.apTotal,
    required this.openCount,
    required this.overdueCount,
    required this.limitExceededCount,
    required this.arAging,
    required this.apAging,
  });

  final double arTotal;
  final double apTotal;
  final int openCount;
  final int overdueCount;
  final int limitExceededCount;
  final DebtAgingSummary arAging;
  final DebtAgingSummary apAging;
}

List<List<String>> buildDebtRegisterExportRows({
  required String title,
  required DebtRegisterSummary summary,
  required List<DebtRegisterRow> rows,
}) {
  return <List<String>>[
    <String>[title],
    <String>[],
    <String>['Показатель', 'Значение'],
    <String>['AR', summary.arTotal.toStringAsFixed(2)],
    <String>['AP', summary.apTotal.toStringAsFixed(2)],
    <String>['Открытые', summary.openCount.toString()],
    <String>['Просрочено', summary.overdueCount.toString()],
    <String>['Лимит превышен', summary.limitExceededCount.toString()],
    <String>['AR 0-30', summary.arAging.bucket0To30.toStringAsFixed(2)],
    <String>['AR 31-60', summary.arAging.bucket31To60.toStringAsFixed(2)],
    <String>['AR 61-90', summary.arAging.bucket61To90.toStringAsFixed(2)],
    <String>['AR 90+', summary.arAging.bucket90Plus.toStringAsFixed(2)],
    <String>[],
    <String>[
      'Контрагент',
      'Тип',
      'Источник',
      'Документ',
      'Сумма',
      'Остаток',
      'Контур',
      'Aging',
      'Статус',
      'Лимит',
    ],
    ...rows.map(
      (row) => <String>[
        row.counterpartyName,
        row.type.label,
        row.sourceType,
        row.sourceDocumentId,
        row.totalAmount.toStringAsFixed(2),
        row.remainingAmount.toStringAsFixed(2),
        row.ledgerScope.storageValue,
        row.agingDays.toString(),
        row.isCreditLimitExceeded ? 'LIMIT' : row.status.storageValue,
        row.creditLimit.toStringAsFixed(2),
      ],
    ),
  ];
}

List<DebtRegisterRow> buildDebtRegisterRows({
  required List<DebtRecordView> debts,
  required DateTime asOf,
  LedgerScope? ledgerScope,
  DebtType? type,
  bool openOnly = true,
}) {
  final rows = debts.where((debt) {
    if (ledgerScope != null && !debt.ledgerScope.matches(ledgerScope)) {
      return false;
    }
    if (type != null && debt.type != type) {
      return false;
    }
    if (openOnly && !debt.isOpen) {
      return false;
    }
    return true;
  }).map((debt) {
    final basisDate = debt.dueDate ?? debt.createdAt;
    final agingDays = basisDate == null ? 0 : asOf.difference(basisDate).inDays;
    return DebtRegisterRow(
      id: debt.id,
      type: debt.type,
      counterpartyName: debt.counterpartyName,
      sourceType: debt.sourceType,
      sourceDocumentId: debt.sourceDocumentId,
      totalAmount: debt.totalAmount,
      remainingAmount: debt.remainingAmount,
      ledgerScope: debt.ledgerScope,
      status: debt.status,
      createdAt: debt.createdAt,
      dueDate: debt.dueDate,
      creditLimit: debt.creditLimit,
      isCreditLimitExceeded: debt.isCreditLimitExceeded,
      agingDays: agingDays < 0 ? 0 : agingDays,
    );
  }).toList();

  rows.sort((left, right) {
    final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateCompare = leftDate.compareTo(rightDate);
    if (dateCompare != 0) return dateCompare;
    return left.counterpartyName.compareTo(right.counterpartyName);
  });
  return rows;
}

DebtRegisterSummary computeDebtRegisterSummary({
  required List<DebtRecordView> debts,
  required DateTime asOf,
  LedgerScope? ledgerScope,
}) {
  final scopedDebts = debts.where((debt) {
    if (ledgerScope == null) return true;
    return debt.ledgerScope.matches(ledgerScope);
  }).toList();

  final rows = buildDebtRegisterRows(
    debts: scopedDebts,
    asOf: asOf,
    openOnly: true,
  );
  final arTotal = rows
      .where((row) => row.type == DebtType.ar)
      .fold<double>(0, (total, row) => total + row.remainingAmount);
  final apTotal = rows
      .where((row) => row.type == DebtType.ap)
      .fold<double>(0, (total, row) => total + row.remainingAmount);
  final overdueCount = rows
      .where((row) => row.dueDate != null && !row.dueDate!.isAfter(asOf))
      .length;
  final limitExceededCount =
      rows.where((row) => row.isCreditLimitExceeded).length;

  return DebtRegisterSummary(
    arTotal: arTotal,
    apTotal: apTotal,
    openCount: rows.length,
    overdueCount: overdueCount,
    limitExceededCount: limitExceededCount,
    arAging: DebtAgingService.compute(
      debts: scopedDebts,
      asOf: asOf,
      type: DebtType.ar,
    ),
    apAging: DebtAgingService.compute(
      debts: scopedDebts,
      asOf: asOf,
      type: DebtType.ap,
    ),
  );
}
