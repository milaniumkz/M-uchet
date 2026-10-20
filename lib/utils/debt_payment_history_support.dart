import '/utils/debt_register_support.dart';
import '/utils/ledger_scope.dart';

class DebtPaymentHistoryRow {
  const DebtPaymentHistoryRow({
    required this.paymentTransactionId,
    required this.amount,
    required this.createdAt,
    required this.accountTitle,
    required this.description,
    required this.status,
  });

  final String paymentTransactionId;
  final double amount;
  final DateTime? createdAt;
  final String accountTitle;
  final String description;
  final String status;
}

class DebtPaymentTimelineRow {
  const DebtPaymentTimelineRow({
    required this.debtId,
    required this.debtType,
    required this.counterpartyName,
    required this.paymentTransactionId,
    required this.amount,
    required this.createdAt,
    required this.accountTitle,
    required this.description,
    required this.status,
    required this.ledgerScope,
  });

  final String debtId;
  final DebtType debtType;
  final String counterpartyName;
  final String paymentTransactionId;
  final double amount;
  final DateTime? createdAt;
  final String accountTitle;
  final String description;
  final String status;
  final LedgerScope ledgerScope;
}

List<DebtPaymentHistoryRow> buildDebtPaymentHistoryRows({
  required String debtId,
  required List<Map<String, dynamic>> paymentLinks,
  required List<Map<String, dynamic>> transactions,
}) {
  final txById = <String, Map<String, dynamic>>{
    for (final tx in transactions)
      (tx['id'] ?? '').toString(): tx,
  };

  final rows = paymentLinks
      .where((link) => (link['debt_id'] ?? link['debtId'] ?? '').toString() == debtId)
      .map((link) {
        final transactionId = (link['payment_transaction_id'] ??
                link['paymentTransactionId'] ??
                '')
            .toString();
        final transaction = txById[transactionId] ?? const <String, dynamic>{};
        return DebtPaymentHistoryRow(
          paymentTransactionId: transactionId,
          amount: _toNum(link['amount']),
          createdAt: _toDateTime(
            link['created_at'] ?? link['createdAt'] ?? transaction['date'],
          ),
          accountTitle: (transaction['schetTitle'] ??
                  transaction['wallet_name'] ??
                  transaction['walletName'] ??
                  '')
              .toString(),
          description:
              (transaction['text'] ?? transaction['description'] ?? '').toString(),
          status: (transaction['status'] ?? '').toString(),
        );
      })
      .toList();

  rows.sort((left, right) {
    final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateCompare = rightDate.compareTo(leftDate);
    if (dateCompare != 0) return dateCompare;
    return right.paymentTransactionId.compareTo(left.paymentTransactionId);
  });
  return rows;
}

List<DebtPaymentTimelineRow> buildDebtPaymentTimelineRows({
  required List<DebtRecordView> debts,
  required List<Map<String, dynamic>> paymentLinks,
  required List<Map<String, dynamic>> transactions,
  DebtType? type,
  LedgerScope? ledgerScope,
}) {
  final debtById = <String, DebtRecordView>{
    for (final debt in debts) debt.id: debt,
  };
  final txById = <String, Map<String, dynamic>>{
    for (final tx in transactions) (tx['id'] ?? '').toString(): tx,
  };

  final rows = paymentLinks
      .map((link) {
        final debtId = (link['debt_id'] ?? link['debtId'] ?? '').toString();
        final debt = debtById[debtId];
        if (debt == null) return null;
        if (type != null && debt.type != type) return null;
        if (ledgerScope != null && !debt.ledgerScope.matches(ledgerScope)) {
          return null;
        }
        final transactionId = (link['payment_transaction_id'] ??
                link['paymentTransactionId'] ??
                '')
            .toString();
        final transaction = txById[transactionId] ?? const <String, dynamic>{};
        return DebtPaymentTimelineRow(
          debtId: debt.id,
          debtType: debt.type,
          counterpartyName: debt.counterpartyName,
          paymentTransactionId: transactionId,
          amount: _toNum(link['amount']),
          createdAt: _toDateTime(
            link['created_at'] ?? link['createdAt'] ?? transaction['date'],
          ),
          accountTitle: (transaction['schetTitle'] ??
                  transaction['wallet_name'] ??
                  transaction['walletName'] ??
                  '')
              .toString(),
          description:
              (transaction['text'] ?? transaction['description'] ?? '').toString(),
          status: (transaction['status'] ?? '').toString(),
          ledgerScope: debt.ledgerScope,
        );
      })
      .whereType<DebtPaymentTimelineRow>()
      .toList();

  rows.sort((left, right) {
    final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateCompare = rightDate.compareTo(leftDate);
    if (dateCompare != 0) return dateCompare;
    return right.paymentTransactionId.compareTo(left.paymentTransactionId);
  });
  return rows;
}

List<List<String>> buildDebtPaymentTimelineExportRows({
  required String title,
  required List<DebtPaymentTimelineRow> rows,
}) {
  return <List<String>>[
    <String>[title],
    <String>[],
    <String>[
      'Контрагент',
      'Тип долга',
      'Транзакция',
      'Счёт',
      'Описание',
      'Статус',
      'Контур',
      'Дата',
      'Сумма',
    ],
    ...rows.map(
      (row) => <String>[
        row.counterpartyName,
        row.debtType.label,
        row.paymentTransactionId,
        row.accountTitle,
        row.description,
        row.status,
        row.ledgerScope.storageValue,
        row.createdAt?.toIso8601String() ?? '',
        row.amount.toStringAsFixed(2),
      ],
    ),
  ];
}

double _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
