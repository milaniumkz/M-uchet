import '/utils/debt_register_support.dart';

class DebtAgingService {
  const DebtAgingService._();

  static DebtAgingSummary compute({
    required List<DebtRecordView> debts,
    required DateTime asOf,
    DebtType? type,
  }) {
    return buildDebtAgingSummary(
      debts: debts,
      asOf: asOf,
      type: type,
    );
  }
}
