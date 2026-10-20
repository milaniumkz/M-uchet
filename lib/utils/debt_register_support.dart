import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';

enum DebtType { ar, ap }

enum DebtStatus { open, partial, closed }

DebtType debtTypeFromValue(String? rawValue) {
  switch ((rawValue ?? '').trim().toLowerCase()) {
    case 'ar':
    case 'receivable':
      return DebtType.ar;
    case 'ap':
    case 'payable':
    default:
      return DebtType.ap;
  }
}

DebtStatus debtStatusFromAmounts({
  required double totalAmount,
  required double remainingAmount,
}) {
  if (remainingAmount <= 0.000001) {
    return DebtStatus.closed;
  }
  if (remainingAmount + 0.000001 < totalAmount) {
    return DebtStatus.partial;
  }
  return DebtStatus.open;
}

extension DebtTypeStorage on DebtType {
  String get storageValue {
    switch (this) {
      case DebtType.ar:
        return 'AR';
      case DebtType.ap:
        return 'AP';
    }
  }

  String get label {
    switch (this) {
      case DebtType.ar:
        return 'AR';
      case DebtType.ap:
        return 'AP';
    }
  }
}

extension DebtStatusStorage on DebtStatus {
  String get storageValue {
    switch (this) {
      case DebtStatus.open:
        return 'OPEN';
      case DebtStatus.partial:
        return 'PARTIAL';
      case DebtStatus.closed:
        return 'CLOSED';
    }
  }
}

class DebtRecordView {
  const DebtRecordView({
    required this.id,
    required this.type,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.sourceDocumentId,
    required this.sourceType,
    required this.totalAmount,
    required this.remainingAmount,
    required this.currency,
    required this.ledgerScope,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.creditLimit,
    required this.idCompany,
  });

  final String id;
  final DebtType type;
  final String counterpartyId;
  final String counterpartyName;
  final String sourceDocumentId;
  final String sourceType;
  final double totalAmount;
  final double remainingAmount;
  final String currency;
  final LedgerScope ledgerScope;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final DebtStatus status;
  final double creditLimit;
  final String idCompany;

  bool get isOpen => status != DebtStatus.closed && remainingAmount > 0.000001;

  bool get isCreditLimitExceeded =>
      creditLimit > 0 && remainingAmount - creditLimit > 0.000001;

  factory DebtRecordView.fromMap(Map<String, dynamic> map) {
    final totalAmount = _toNum(map['total_amount'] ?? map['totalAmount']);
    final remainingAmount =
        _toNum(map['remaining_amount'] ?? map['remainingAmount']);
    return DebtRecordView(
      id: (map['id'] ?? '').toString(),
      type: debtTypeFromValue(map['type']?.toString()),
      counterpartyId:
          (map['counterparty_id'] ?? map['counterpartyId'] ?? '').toString(),
      counterpartyName: (map['counterparty_name'] ??
              map['counterpartyName'] ??
              map['counterparty'] ??
              '')
          .toString(),
      sourceDocumentId: (map['source_document_id'] ??
              map['sourceDocumentId'] ??
              map['source_id'] ??
              '')
          .toString(),
      sourceType:
          (map['source_type'] ?? map['sourceType'] ?? '').toString().trim(),
      totalAmount: totalAmount,
      remainingAmount: remainingAmount,
      currency: normalizeCurrencyCode((map['currency'] ?? 'KZT').toString()),
      ledgerScope: ledgerScopeFromData(map),
      createdAt: _toDateTime(map['created_at'] ?? map['createdAt']),
      dueDate: _toDateTime(map['due_date'] ?? map['dueDate']),
      status: debtStatusFromAmounts(
        totalAmount: totalAmount,
        remainingAmount: remainingAmount,
      ),
      creditLimit: _toNum(map['credit_limit'] ?? map['creditLimit'] ?? 0.0),
      idCompany: (map['idCompany'] ?? '').toString(),
    );
  }
}

class DebtPaymentAllocation {
  const DebtPaymentAllocation({
    required this.debtId,
    required this.sourceDocumentId,
    required this.sourceType,
    required this.amount,
    required this.remainingAfter,
  });

  final String debtId;
  final String sourceDocumentId;
  final String sourceType;
  final double amount;
  final double remainingAfter;
}

class DebtPaymentResult {
  const DebtPaymentResult({
    required this.updatedDebts,
    required this.allocations,
    required this.unappliedAmount,
  });

  final List<DebtRecordView> updatedDebts;
  final List<DebtPaymentAllocation> allocations;
  final double unappliedAmount;
}

class DebtAgingSummary {
  const DebtAgingSummary({
    required this.bucket0To30,
    required this.bucket31To60,
    required this.bucket61To90,
    required this.bucket90Plus,
  });

  final double bucket0To30;
  final double bucket31To60;
  final double bucket61To90;
  final double bucket90Plus;
}

String debtDocIdForSource({
  required DebtType type,
  required String sourceType,
  required String sourceDocumentId,
}) {
  final normalizedSourceType = sourceType
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final normalizedSourceId = sourceDocumentId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return '${type.storageValue.toLowerCase()}_${normalizedSourceType}_$normalizedSourceId';
}

Map<String, dynamic> buildDebtRecordPayload({
  required String idCompany,
  required DebtType type,
  required String counterpartyId,
  required String counterpartyName,
  required String sourceDocumentId,
  required String sourceType,
  required double totalAmount,
  required double remainingAmount,
  required LedgerScope ledgerScope,
  String currency = 'KZT',
  DateTime? dueDate,
  DateTime? createdAt,
  double creditLimit = 0.0,
}) {
  final status = debtStatusFromAmounts(
    totalAmount: totalAmount,
    remainingAmount: remainingAmount,
  );
  return <String, dynamic>{
    'idCompany': idCompany.trim(),
    'type': type.storageValue,
    'counterparty_id': counterpartyId.trim(),
    'counterparty_name': counterpartyName.trim(),
    'source_document_id': sourceDocumentId.trim(),
    'source_type': sourceType.trim(),
    'total_amount': totalAmount,
    'remaining_amount': remainingAmount,
    'currency': normalizeCurrencyCode(currency),
    ...ledgerScopeFields(
      ledgerScope: ledgerScope,
      legacyTypeUchet: ledgerScope.legacyTypeUchet,
    ),
    'status': status.storageValue,
    'credit_limit': creditLimit,
    'created_at': createdAt,
    'due_date': dueDate,
    'updated_at': DateTime.now(),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildDebtPaymentLinkPayload({
  required String idCompany,
  required String debtId,
  required String paymentTransactionId,
  required double amount,
  required LedgerScope ledgerScope,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'idCompany': idCompany.trim(),
    'debt_id': debtId.trim(),
    'payment_transaction_id': paymentTransactionId.trim(),
    'amount': amount,
    ...ledgerScopeFields(
      ledgerScope: ledgerScope,
      legacyTypeUchet: ledgerScope.legacyTypeUchet,
    ),
    'created_at': createdAt ?? DateTime.now(),
    'updated_at': DateTime.now(),
  };
}

DebtPaymentResult applyDebtPaymentFifo({
  required List<DebtRecordView> debts,
  required double paymentAmount,
}) {
  if (paymentAmount <= 0.000001) {
    return DebtPaymentResult(
      updatedDebts: List<DebtRecordView>.from(debts),
      allocations: const [],
      unappliedAmount: 0,
    );
  }
  var remainingPayment = paymentAmount;
  final sortedDebts = [...debts]..sort((a, b) {
      final aDate =
          a.createdAt ?? a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.createdAt ?? b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
  final updatedDebts = <DebtRecordView>[];
  final allocations = <DebtPaymentAllocation>[];

  for (final debt in sortedDebts) {
    if (!debt.isOpen || remainingPayment <= 0.000001) {
      updatedDebts.add(debt);
      continue;
    }
    final applied = remainingPayment > debt.remainingAmount
        ? debt.remainingAmount
        : remainingPayment;
    final nextRemaining =
        (debt.remainingAmount - applied).clamp(0, double.infinity).toDouble();
    remainingPayment -= applied;
    updatedDebts.add(
      DebtRecordView(
        id: debt.id,
        type: debt.type,
        counterpartyId: debt.counterpartyId,
        counterpartyName: debt.counterpartyName,
        sourceDocumentId: debt.sourceDocumentId,
        sourceType: debt.sourceType,
        totalAmount: debt.totalAmount,
        remainingAmount: nextRemaining,
        currency: debt.currency,
        ledgerScope: debt.ledgerScope,
        createdAt: debt.createdAt,
        dueDate: debt.dueDate,
        status: debtStatusFromAmounts(
          totalAmount: debt.totalAmount,
          remainingAmount: nextRemaining,
        ),
        creditLimit: debt.creditLimit,
        idCompany: debt.idCompany,
      ),
    );
    if (applied > 0.000001) {
      allocations.add(
        DebtPaymentAllocation(
          debtId: debt.id,
          sourceDocumentId: debt.sourceDocumentId,
          sourceType: debt.sourceType,
          amount: applied,
          remainingAfter: nextRemaining,
        ),
      );
    }
  }

  return DebtPaymentResult(
    updatedDebts: updatedDebts,
    allocations: allocations,
    unappliedAmount: remainingPayment,
  );
}

DebtAgingSummary buildDebtAgingSummary({
  required List<DebtRecordView> debts,
  required DateTime asOf,
  DebtType? type,
}) {
  double bucket0To30 = 0;
  double bucket31To60 = 0;
  double bucket61To90 = 0;
  double bucket90Plus = 0;

  for (final debt in debts) {
    if (!debt.isOpen) continue;
    if (type != null && debt.type != type) continue;
    final baseDate = debt.dueDate ?? debt.createdAt ?? asOf;
    final age = asOf.difference(baseDate).inDays;
    if (age <= 30) {
      bucket0To30 += debt.remainingAmount;
    } else if (age <= 60) {
      bucket31To60 += debt.remainingAmount;
    } else if (age <= 90) {
      bucket61To90 += debt.remainingAmount;
    } else {
      bucket90Plus += debt.remainingAmount;
    }
  }

  return DebtAgingSummary(
    bucket0To30: bucket0To30,
    bucket31To60: bucket31To60,
    bucket61To90: bucket61To90,
    bucket90Plus: bucket90Plus,
  );
}

double _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
