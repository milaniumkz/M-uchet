// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/utils/accounting_entry_service.dart';
import '/utils/debt_register_support.dart';
import '/utils/transaction_sync.dart';
import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_wallet_support.dart';
import '/utils/company_lock.dart';
import '/utils/effective_company_support.dart';
import '/utils/app_money_format.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/editing_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

String _formatObligationDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatObligationPeriodLabel(DateTime date) {
  const monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${monthNames[date.month - 1]} ${date.year}';
}

String _budgetCategoryForObligation(Map<String, dynamic> obligation) {
  final raw = [
    obligation['title'],
    obligation['name'],
    obligation['type'],
    obligation['description'],
  ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
  if (raw.contains('маркетинг')) return 'Маркетинг (всё включено)';
  if (raw.contains('аренд')) return 'Аренда / инфраструктура';
  if (raw.contains('кредит')) return 'Оплата кредита';
  if (raw.contains('налог') || raw.contains('осмс') || raw.contains('ндс')) {
    return 'Налоги';
  }
  if (raw.contains('товар') || raw.contains('закуп')) return 'Закуп товара';
  return 'Администрация (не доходная)';
}

DateTime? _parseObligationDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}
    final slashMatch =
        RegExp(r'^(\d{1,2})[\/.](\d{1,2})[\/.](\d{4})$').firstMatch(raw);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
  }
  return null;
}

Future<void> _upsertObligationDebtRegister({
  required FirebaseFirestore firestore,
  required String companyId,
  required String obligationId,
  required Map<String, dynamic> obligationData,
}) async {
  final amount = ((obligationData['amount'] ?? 0) as num).toDouble();
  final totalPaid = ((obligationData['total_paid'] ?? 0) as num).toDouble();
  final remainingAmount = (amount - totalPaid).clamp(0, amount).toDouble();
  final dueDate = _parseObligationDate(
      obligationData['due_date'] ?? obligationData['period_end']);
  final creditLimit =
      ((obligationData['counterparty_credit_limit'] ?? 0) as num).toDouble();
  final debtId = debtDocIdForSource(
    type: DebtType.ap,
    sourceType: 'obligation',
    sourceDocumentId: obligationId,
  );
  await firestore.collection('debt_register').doc(debtId).set(
        buildDebtRecordPayload(
          idCompany: companyId,
          type: DebtType.ap,
          counterpartyId: (obligationData['counterparty_id'] ?? '').toString(),
          counterpartyName: (obligationData['counterparty'] ?? '').toString(),
          sourceDocumentId: obligationId,
          sourceType: 'obligation',
          totalAmount: amount,
          remainingAmount: remainingAmount,
          ledgerScope: ledgerScopeFromData(obligationData),
          currency: normalizeCurrencyCode(
            (obligationData['currency'] ??
                    obligationData['company_currency'] ??
                    obligationData['companyCurrency'] ??
                    'KZT')
                .toString(),
          ),
          dueDate: dueDate,
          createdAt: DateTime.now(),
          creditLimit: creditLimit,
        ),
        SetOptions(merge: true),
      );
}

Future<void> _applyDebtPaymentForCounterparty({
  required FirebaseFirestore firestore,
  required String companyId,
  required String counterpartyName,
  required LedgerScope ledgerScope,
  required String paymentTransactionId,
  required double amount,
}) async {
  final debtSnap = await firestore
      .collection('debt_register')
      .where('idCompany', isEqualTo: companyId)
      .where('type', isEqualTo: DebtType.ap.storageValue)
      .where('counterparty_name', isEqualTo: counterpartyName.trim())
      .get();
  final debts = debtSnap.docs
      .map((doc) => DebtRecordView.fromMap({'id': doc.id, ...doc.data()}))
      .where((debt) => debt.ledgerScope.matches(ledgerScope))
      .where((debt) => debt.isOpen)
      .toList();
  if (debts.isEmpty) return;

  final paymentResult = applyDebtPaymentFifo(
    debts: debts,
    paymentAmount: amount,
  );
  final batch = firestore.batch();
  for (final debt in paymentResult.updatedDebts) {
    batch.set(
      firestore.collection('debt_register').doc(debt.id),
      buildDebtRecordPayload(
        idCompany: debt.idCompany,
        type: debt.type,
        counterpartyId: debt.counterpartyId,
        counterpartyName: debt.counterpartyName,
        sourceDocumentId: debt.sourceDocumentId,
        sourceType: debt.sourceType,
        totalAmount: debt.totalAmount,
        remainingAmount: debt.remainingAmount,
        ledgerScope: debt.ledgerScope,
        currency: debt.currency,
        dueDate: debt.dueDate,
        createdAt: debt.createdAt,
        creditLimit: debt.creditLimit,
      ),
      SetOptions(merge: true),
    );
  }
  for (final allocation in paymentResult.allocations) {
    batch.set(
      firestore.collection('debt_payment_links').doc(),
      buildDebtPaymentLinkPayload(
        idCompany: companyId,
        debtId: allocation.debtId,
        paymentTransactionId: paymentTransactionId,
        amount: allocation.amount,
        ledgerScope: ledgerScope,
      ),
    );
    if (allocation.sourceType == 'obligation' &&
        allocation.sourceDocumentId.isNotEmpty) {
      batch.update(
        firestore.collection('obyaz').doc(allocation.sourceDocumentId),
        <String, dynamic>{
          'total_paid': FieldValue.increment(allocation.amount),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );
    }
  }
  await batch.commit();
}

class ObligationsWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final Function()? onAddObligation;

  const ObligationsWidget({
    Key? key,
    this.width,
    this.height,
    this.onAddObligation,
  }) : super(key: key);

  @override
  _ObligationsWidgetState createState() => _ObligationsWidgetState();
}

class _ObligationsWidgetState extends State<ObligationsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _completedCount = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;
  double _totalAmount = 0;
  double _totalPaid = 0;
  double _unpaidAmount = 0;
  String _periodicityFilter = 'Все';
  List<Map<String, dynamic>> _obligations = [];
  bool _activeExpanded = true;
  bool _overdueExpanded = true;
  bool _completedExpanded = true;
  String _companyCurrency = 'KZT';

  bool get _isCompactLayout => MediaQuery.of(context).size.width < 1100;

  @override
  void initState() {
    super.initState();
    _loadCompanyCurrency();
    _loadObligations();
  }

  Future<void> _loadCompanyCurrency() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
    Map<String, dynamic> profileData = const <String, dynamic>{};
    try {
      final snap =
          await _firestore.collection('company_profile').doc(companyId).get();
      profileData = snap.data() ?? const <String, dynamic>{};
    } catch (_) {}
    final profile = countryProfileFromData(profileData);
    final currency = companyCurrencyFromProfileData(
      profileData,
      fallback: profile.baseCurrency,
    );
    if (!mounted) return;
    setState(() => _companyCurrency = currency);
  }

  Future<void> _loadObligations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final companyIds = resolveQueryCompanyIds(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final docsById = <String, Map<String, dynamic>>{};
      for (final field in const ['idCompany', 'companyId', 'company_id']) {
        for (final chunk in splitCompanyIdsForWhereIn(companyIds)) {
          final query = chunk.length == 1
              ? _firestore
                  .collection('obyaz')
                  .where(field, isEqualTo: chunk.first)
              : _firestore.collection('obyaz').where(field, whereIn: chunk);
          final snap = await query.getCached();
          for (final doc in snap.docs) {
            final raw = doc.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            docsById[doc.id] = data;
          }
        }
      }

      List<Map<String, dynamic>> obligations = [];
      int completedCount = 0;
      int paidCount = 0;
      int unpaidCount = 0;
      double totalAmount = 0;
      double totalPaid = 0;
      double unpaidAmount = 0;
      for (final entry in docsById.entries) {
        final data = entry.value;
        final amount = (data['amount'] ?? 0).toDouble();
        final paid = (data['total_paid'] ?? 0).toDouble();
        final displayStatus = _displayStatusForObligation(data);
        final obligation = {
          'id': entry.key,
          ...data,
          'display_status': displayStatus,
        };
        obligations.add(obligation);

        totalAmount += amount;
        totalPaid += paid;
        if (_obligationDebtStatus(obligation) == DebtStatus.closed) {
          completedCount++;
        }
        if (paid >= amount && amount > 0) {
          paidCount++;
        } else if (amount > 0) {
          unpaidCount++;
          unpaidAmount += (amount - paid);
        }
      }

      setState(() {
        _obligations = obligations;
        _completedCount = completedCount;
        _paidCount = paidCount;
        _unpaidCount = unpaidCount;
        _totalAmount = totalAmount;
        _totalPaid = totalPaid;
        _unpaidAmount = unpaidAmount;
      });
    } catch (e) {
      debugPrint('Error loading obligations: $e');
    }
  }

  Future<bool> _ensureUnlocked() async {
    final user = _auth.currentUser;
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    final effectiveCompanyId =
        rawCompanyId.isNotEmpty ? rawCompanyId : user?.uid ?? '';
    if (effectiveCompanyId.isEmpty) return true;
    final locked = await CompanyLock.isLocked(effectiveCompanyId);
    if (locked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Редактирование отключено после завершения первого входа.'),
        ),
      );
    }
    return !locked;
  }

  DateTime? _parseDateValue(dynamic value) {
    return _parseObligationDate(value);
  }

  DebtStatus _obligationDebtStatus(Map<String, dynamic> obligation) {
    final amount = (obligation['amount'] ?? 0).toDouble();
    final paid = (obligation['total_paid'] ?? 0).toDouble();
    final remaining = (amount - paid).clamp(0, double.infinity).toDouble();
    return debtStatusFromAmounts(
      totalAmount: amount,
      remainingAmount: remaining,
    );
  }

  bool _isOverdueObligation(Map<String, dynamic> obligation) {
    final dueDate = _parseDateValue(
      obligation['due_date'] ?? obligation['period_end'],
    );
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _obligationDebtStatus(obligation) != DebtStatus.closed &&
        dueDate.isBefore(today);
  }

  String _displayStatusForObligation(Map<String, dynamic> obligation) {
    if (_isOverdueObligation(obligation)) {
      return 'Просрочено';
    }
    switch (_obligationDebtStatus(obligation)) {
      case DebtStatus.closed:
        return 'Завершено';
      case DebtStatus.open:
      case DebtStatus.partial:
        return 'Активно';
    }
  }

  String _formatCurrency(double amount) {
    return formatMoneyWithCurrency(amount, currencyCode: _companyCurrency);
  }

  double _remainingAmount(Map<String, dynamic> obligation) {
    final amount = (obligation['amount'] ?? 0).toDouble();
    final paid = (obligation['total_paid'] ?? 0).toDouble();
    final remaining = amount - paid;
    return remaining > 0 ? remaining : 0;
  }

  Widget _buildStatsCard() {
    final theme = FlutterFlowTheme.of(context);
    Widget card({
      required String title,
      required String value,
      required String subtitle,
      required Color color,
    }) {
      return Container(
        width: 260,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.25
                      : 0.06),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Обязательства',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.primaryText,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            card(
              title: 'Всего',
              value: '${_obligations.length} шт.',
              subtitle: _formatCurrency(_totalAmount),
              color: Colors.blueGrey,
            ),
            card(
              title: 'Оплачено',
              value: '$_paidCount шт.',
              subtitle:
                  '${_formatCurrency(_totalPaid)} • Выполнено: $_completedCount',
              color: Colors.green,
            ),
            card(
              title: 'Не оплачено',
              value: '$_unpaidCount шт.',
              subtitle: _formatCurrency(_unpaidAmount),
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildObligationCard(Map<String, dynamic> obligation) {
    final theme = FlutterFlowTheme.of(context);
    final displayStatus = _displayStatusForObligation(obligation);
    final periodicity =
        (obligation['frequency'] ?? obligation['periodicity'] ?? 'Разово')
            .toString();
    final dueDate = _formatDate(
      obligation['due_date'] ?? obligation['period_end'],
    );
    final remainingAmount = _remainingAmount(obligation);
    final paidAmount = (obligation['total_paid'] ?? 0).toDouble();
    return LiveDiffHighlight(
      timestamp: obligation['updated_at'] ?? obligation['created_at'],
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.25
                      : 0.05),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(displayStatus),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obligation['title'] ?? 'Без названия',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${obligation['type']} • $displayStatus',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatCurrency(remainingAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'Контрагент:',
                    obligation['counterparty'] ?? 'Не указан',
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    'Периодичность:',
                    periodicity,
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    periodicity == 'Разово'
                        ? 'Дата исполнения:'
                        : 'Дата до исполнения:',
                    dueDate,
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    'Оплачено:',
                    _formatCurrency(paidAmount),
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    'Остаток:',
                    _formatCurrency(remainingAmount),
                  ),
                  SizedBox(height: 12),
                  if (obligation['description'] != null &&
                      obligation['description'].isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(),
                        SizedBox(height: 8),
                        Text(
                          obligation['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'Завершить',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      onPressed: () => _completeObligation(obligation),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (EditingHelper.canEditExisting())
                    Expanded(
                      child: _buildActionButton(
                        text: 'Изменить',
                        icon: Icons.edit_outlined,
                        color: Colors.blue,
                        onPressed: () => _editObligation(obligation),
                      ),
                    ),
                  if (EditingHelper.canEditExisting()) SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      text: 'Удалить',
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onPressed: () => _deleteObligation(obligation['id']),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _isCompactLayout ? 120 : 160,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.secondaryText,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: theme.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final selected = _periodicityFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Color(0xFFE5E7EB),
      onSelected: (_) {
        setState(() {
          _periodicityFilter = label;
        });
      },
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          spacing: 12,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded ? '−' : '+',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSection({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPeriodReport(List<Map<String, dynamic>> items) {
    final theme = FlutterFlowTheme.of(context);
    final Map<String, Map<String, dynamic>> byMonth = {};
    final Map<String, DateTime> periodDates = {};
    for (final item in items) {
      final date = _parseDateValue(item['due_date'] ?? item['period_end']);
      if (date == null) continue;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      periodDates[key] = DateTime(date.year, date.month);
      byMonth.putIfAbsent(key, () {
        return {
          'count': 0,
          'amount': 0.0,
          'paid': 0.0,
          'completed': 0,
        };
      });
      final entry = byMonth[key]!;
      final amount = (item['amount'] ?? 0).toDouble();
      final paid = (item['total_paid'] ?? 0).toDouble();
      entry['count'] = (entry['count'] as int) + 1;
      entry['amount'] = (entry['amount'] as double) + amount;
      entry['paid'] = (entry['paid'] as double) + paid;
      if (_obligationDebtStatus(item) == DebtStatus.closed) {
        entry['completed'] = (entry['completed'] as int) + 1;
      }
    }

    final keys = byMonth.keys.toList()..sort();
    final reportTint = theme.primary.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
    );
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(reportTint, theme.secondaryBackground),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color.alphaBlend(
            theme.primary.withOpacity(0.35),
            theme.alternate,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.primary.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.14,
                ),
                theme.secondaryBackground,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primary.withOpacity(0.25),
              ),
            ),
            child: Text(
              'Сводный отчет по периодам',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
          ),
          SizedBox(height: 12),
          if (keys.isEmpty)
            Text(
              'Нет данных за период',
              style: TextStyle(color: theme.secondaryText),
            )
          else
            Column(
              children: keys.map((key) {
                final entry = byMonth[key]!;
                final amount = entry['amount'] as double;
                final paid = entry['paid'] as double;
                final count = entry['count'] as int;
                final completed = entry['completed'] as int;
                final metrics = [
                  'Всего: $count',
                  'Выполнено: $completed',
                  'Сумма: ${_formatCurrency(amount)}',
                  'Оплачено: ${_formatCurrency(paid)}',
                ];
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      theme.primary.withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.10
                            : 0.05,
                      ),
                      theme.primaryBackground,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color.alphaBlend(
                        theme.primary.withOpacity(0.16),
                        theme.alternate,
                      ),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    spacing: 16,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160),
                        child: Text(
                          _formatObligationPeriodLabel(periodDates[key]!),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                      ...metrics.map(
                        (metric) => ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 170),
                          child: Text(
                            metric,
                            style: TextStyle(
                              color: metric.startsWith('Сумма:')
                                  ? theme.primaryText
                                  : theme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: color.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Активно':
        return Colors.blue;
      case 'Завершено':
        return Colors.green;
      case 'Просрочено':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    final parsed = _parseObligationDate(date);
    if (parsed == null) return 'Не указано';
    return _formatObligationDate(parsed);
  }

  Future<void> _completeObligation(Map<String, dynamic> obligation) async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Закрыть обязательство?'),
          content: Text('Вы провели оплату?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Нет'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Да'),
            ),
          ],
        );
      },
    );

    if (confirmed == null) {
      return;
    }

    if (confirmed == false) {
      await _createTransactionForObligation(
        obligation: obligation,
        status: 'Не проведена',
        openEditor: false,
      );
      return;
    }

    await _createTransactionForObligation(
      obligation: obligation,
      status: 'Проведена',
      openEditor: true,
    );
  }

  Future<void> _createTransactionForObligation({
    required Map<String, dynamic> obligation,
    required String status,
    required bool openEditor,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = _auth.currentUser;
    if (user == null) return;
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    final companyId = rawCompanyId.isNotEmpty ? rawCompanyId : user.uid;
    final amount = (obligation['amount'] ?? 0).toDouble();
    final currentPaid = (obligation['total_paid'] ?? 0).toDouble();
    final availableToPay = (amount - currentPaid).clamp(0, amount).toDouble();

    double paidAmount = availableToPay;
    if (openEditor) {
      final saved = await showDialog<double>(
        context: context,
        builder: (context) => _ObligationPaymentDialog(
          obligation: obligation,
          status: status,
        ),
      );
      if (!mounted) return;
      if (saved == null) return;
      paidAmount = saved;
    } else {
      final account = await TransactionSync.selectAccount(
        companyId,
        tip: 'bank',
      );
      final wallet = await ensureWalletForAccountReference(
        firestore: _firestore,
        accountRef: account.reference,
        fallbackTitle: account.title,
      );
      final txRef = TranzactionRecord.collection.doc();
      final budgetCategory = _budgetCategoryForObligation(obligation);
      final txData = createTranzactionRecordData(
        type: 'decome',
        typeUchet: 'Up1',
        ledgerScope: LedgerScope.management.storageValue,
        kat: budgetCategory,
        text: 'Оплата обязательства: ${obligation['title'] ?? ''}',
        summa: paidAmount,
        nds: false,
        summaNds: 0,
        idCompany: companyId,
        schetId: account.reference,
        schetTitle: account.title,
        walletId: wallet?.reference.id,
        walletName: wallet?.name,
        walletType: wallet?.type,
        date: DateTime.now(),
        status: status,
        counterparty: (obligation['counterparty'] ?? '').toString(),
        obligationId: (obligation['id'] ?? '').toString(),
        obligationTitle: (obligation['title'] ?? '').toString(),
      );
      await txRef.set({
        ...txData,
        ...mapToFirestore(
          transactionMoneyFieldsForAccountData(
            amountOriginal: paidAmount,
            accountData: account.snapshotData,
          ),
        ),
        ...mapToFirestore({
          'date': FieldValue.serverTimestamp(),
          'category_name': budgetCategory,
          'budget_category': budgetCategory,
          'budget_category_type': 'expense',
        }),
      });
      await createEntriesForTransaction(
        firestore: _firestore,
        transactionRef: txRef,
        transactionData: txData,
      );
      await _applyDebtPaymentForCounterparty(
        firestore: _firestore,
        companyId: companyId,
        counterpartyName: (obligation['counterparty'] ?? '').toString(),
        ledgerScope: LedgerScope.management,
        paymentTransactionId: txRef.id,
        amount: paidAmount,
      );
    }
    final refreshedObligation =
        await _firestore.collection('obyaz').doc(obligation['id']).get();
    final refreshedData =
        refreshedObligation.data() ?? const <String, dynamic>{};
    final refreshedPaid =
        ((refreshedData['total_paid'] ?? currentPaid) as num).toDouble();
    final paidDelta = status == 'Проведена' ? paidAmount : 0.0;
    final nextTotalPaid =
        (refreshedPaid + paidDelta).clamp(0, amount).toDouble();
    final nextStatus =
        nextTotalPaid >= amount && amount > 0 ? 'Завершено' : 'Активно';

    await _firestore.collection('obyaz').doc(obligation['id']).update({
      'total_paid': nextTotalPaid,
      'status': nextStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('tranzaction', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('sheta', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('obyaz', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('debt_register', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('debt_payment_links', companyId);
    await TransactionSync.recomputeAllForCompany(companyId);
    await _loadObligations();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'Завершено'
                ? 'Обязательство завершено'
                : 'Оплата сохранена, остаток: ${_formatCurrency(amount - nextTotalPaid)}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteObligation(String id) async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    if (!EditingHelper.guardEdit(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить обязательство?'),
        content: Text(
            'Вы уверены, что хотите удалить это обязательство? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('obyaz').doc(id).delete();
        final user = _auth.currentUser;
        final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
        final effectiveCompanyId =
            rawCompanyId.isNotEmpty ? rawCompanyId : user?.uid ?? '';
        if (effectiveCompanyId.isNotEmpty) {
          FirestoreQueryCache.instance
              .invalidateCompanyCollection('obyaz', effectiveCompanyId);
        } else {
          FirestoreQueryCache.instance.invalidateCollection('obyaz');
        }
        await _loadObligations();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Обязательство удалено')),
        );
      } catch (e) {
        debugPrint('Error deleting obligation: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Ошибка при удалении обязательства')),
        );
      }
    }
  }

  Future<void> _editObligation(Map<String, dynamic> obligation) async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    if (!EditingHelper.guardEdit(context)) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddObligationDialog(
        onObligationAdded: _loadObligations,
        existing: obligation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('money.obligations')) {
      return PermissionsHelper.noAccess();
    }
    final filtered = _obligations.where((o) {
      final freq = (o['frequency'] ?? o['periodicity'] ?? 'Разово').toString();
      if (_periodicityFilter == 'Все') return true;
      if (_periodicityFilter == 'Разовые') {
        return freq == 'Разово';
      }
      return freq == _periodicityFilter;
    }).toList();
    final activeList =
        filtered.where((o) => o['display_status'] == 'Активно').toList();
    final overdueList =
        filtered.where((o) => o['display_status'] == 'Просрочено').toList();
    final completedList =
        filtered.where((o) => o['display_status'] == 'Завершено').toList();
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final allowed = await _ensureUnlocked();
                    if (!mounted) return;
                    if (!allowed) return;
                    await _showAddObligationDialog();
                    widget.onAddObligation?.call();
                  },
                  icon: Icon(Icons.add, size: 20),
                  label: Text('Добавить обязательства'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _buildPageSection(child: _buildStatsCard()),
              SizedBox(height: 20),
              _buildPageSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodReport(filtered),
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip('Все'),
                        _filterChip('Разовые'),
                        _filterChip('Ежедневно'),
                        _filterChip('Еженедельно'),
                        _filterChip('Ежемесячно'),
                        _filterChip('Ежеквартально'),
                        _filterChip('Раз в 6 месяцев'),
                        _filterChip('Ежегодно'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              if (_obligations.isNotEmpty) ...[
                _buildPageSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        'Активные обязательства',
                        '${activeList.length} из ${filtered.length}',
                        expanded: _activeExpanded,
                        onToggle: () {
                          setState(() {
                            _activeExpanded = !_activeExpanded;
                          });
                        },
                      ),
                      if (_activeExpanded) ...[
                        SizedBox(height: 12),
                        ...activeList.map(_buildObligationCard).toList(),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
                _buildPageSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        'Просроченные обязательства',
                        '${overdueList.length}',
                        expanded: _overdueExpanded,
                        onToggle: () {
                          setState(() {
                            _overdueExpanded = !_overdueExpanded;
                          });
                        },
                      ),
                      if (_overdueExpanded) ...[
                        SizedBox(height: 12),
                        if (overdueList.isEmpty)
                          Text(
                            'Просроченных обязательств нет',
                            style: TextStyle(
                                color:
                                    FlutterFlowTheme.of(context).secondaryText),
                          )
                        else
                          ...overdueList.map(_buildObligationCard).toList(),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
                _buildPageSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        'Завершенные обязательства',
                        '${completedList.length}',
                        expanded: _completedExpanded,
                        onToggle: () {
                          setState(() {
                            _completedExpanded = !_completedExpanded;
                          });
                        },
                      ),
                      if (_completedExpanded) ...[
                        SizedBox(height: 12),
                        if (completedList.isEmpty)
                          Text(
                            'Завершенных обязательств пока нет',
                            style: TextStyle(
                                color:
                                    FlutterFlowTheme.of(context).secondaryText),
                          )
                        else
                          ...completedList.map(_buildObligationCard).toList(),
                      ],
                    ],
                  ),
                ),
              ] else
                _buildPageSection(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Нет активных обязательств',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Добавьте первое обязательство',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddObligationDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddObligationDialog(
        onObligationAdded: _loadObligations,
      ),
    );
  }
}

class _ObligationPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> obligation;
  final String status;

  const _ObligationPaymentDialog({
    required this.obligation,
    required this.status,
  });

  @override
  State<_ObligationPaymentDialog> createState() =>
      _ObligationPaymentDialogState();
}

class _ObligationPaymentDialogState extends State<_ObligationPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _textController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1');
  DateTime? _date;
  DocumentReference? _schetId;
  String _schetTitle = '';
  Map<String, dynamic>? _selectedAccountData;
  String _accountCurrency = 'KZT';
  String _companyCurrency = 'KZT';
  String _typeUchet = 'Up1';
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    final activeCompanyId = (currentUserDocument?.activeCompanyId ?? '').trim();
    final companyIds = (currentUserDocument?.companyIds ?? const <String>[])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    _companyId = rawCompanyId.isNotEmpty && rawCompanyId != '__all__'
        ? rawCompanyId
        : activeCompanyId.isNotEmpty
            ? activeCompanyId
            : companyIds.isNotEmpty
                ? companyIds.first
                : (FirebaseAuth.instance.currentUser?.uid ?? '');
    final amount = (widget.obligation['amount'] ?? 0).toDouble();
    final paid = (widget.obligation['total_paid'] ?? 0).toDouble();
    final remaining = (amount - paid).clamp(0, amount).toDouble();
    _amountController.text = remaining.toStringAsFixed(0);
    _textController.text =
        'Оплата обязательства: ${widget.obligation['title'] ?? ''}';
    _counterpartyController.text =
        (widget.obligation['counterparty'] ?? '').toString();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _textController.dispose();
    _counterpartyController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  bool get _needsExchangeRate =>
      normalizeCurrencyCode(_accountCurrency) !=
      normalizeCurrencyCode(_companyCurrency);

  double get _exchangeRate =>
      double.tryParse(
        _exchangeRateController.text.replaceAll(' ', '').replaceAll(',', '.'),
      ) ??
      1.0;

  double get _amountOriginal =>
      double.tryParse(
        _amountController.text.replaceAll(' ', '').replaceAll(',', '.'),
      ) ??
      0.0;

  double get _amountCompany =>
      _amountOriginal * (_needsExchangeRate ? _exchangeRate : 1.0);

  void _selectAccount(ShetaRecord? account) {
    if (account == null) {
      setState(() {
        _schetId = null;
        _schetTitle = '';
        _selectedAccountData = null;
        _accountCurrency = _companyCurrency;
      });
      return;
    }
    final data = account.snapshotData;
    final accountCurrency = originalCurrencyFromData(
      data,
      fallback: account.accountCurrency,
    );
    final companyCurrency = companyCurrencyFromData(
      data,
      fallback: account.companyCurrency,
    );
    setState(() {
      _schetId = account.reference;
      _schetTitle = account.title;
      _selectedAccountData = data;
      _accountCurrency = accountCurrency;
      _companyCurrency = companyCurrency;
      if (normalizeCurrencyCode(accountCurrency) ==
          normalizeCurrencyCode(companyCurrency)) {
        _exchangeRateController.text = '1';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final companyId = _companyId.isNotEmpty ? _companyId : user.uid;
    if (_schetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите счет для оплаты')),
      );
      return;
    }
    final amount = double.tryParse(
            _amountController.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0;
    if (_needsExchangeRate && _exchangeRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите курс больше нуля')),
      );
      return;
    }
    final wallet = await ensureWalletForAccountReference(
      firestore: FirebaseFirestore.instance,
      accountRef: _schetId,
      fallbackTitle: _schetTitle,
    );
    final accountSnap = await _schetId?.get();
    final accountData = accountSnap?.data() is Map
        ? Map<String, dynamic>.from(accountSnap!.data() as Map)
        : _selectedAccountData;
    final exchangeRate = _needsExchangeRate ? _exchangeRate : 1.0;
    final txRef = TranzactionRecord.collection.doc();
    final budgetCategory = _budgetCategoryForObligation(widget.obligation);
    final txData = createTranzactionRecordData(
      type: 'decome',
      typeUchet: _typeUchet,
      ledgerScope: ledgerScopeFromLegacyValue(_typeUchet).storageValue,
      kat: budgetCategory,
      text: _textController.text.trim(),
      summa: amount,
      nds: false,
      summaNds: 0,
      idCompany: companyId,
      schetId: _schetId,
      schetTitle: _schetTitle,
      walletId: wallet?.reference.id,
      walletName: wallet?.name,
      walletType: wallet?.type,
      date: _date,
      status: widget.status,
      counterparty: _counterpartyController.text.trim(),
      obligationId: (widget.obligation['id'] ?? '').toString(),
      obligationTitle: (widget.obligation['title'] ?? '').toString(),
    );
    final fullTxData = {
      ...txData,
      ...mapToFirestore(
        transactionMoneyFieldsForAccountData(
          amountOriginal: amount,
          accountData: accountData,
          exchangeRateToCompany: exchangeRate,
          exchangeRateDate: _date,
          exchangeRateSource: _needsExchangeRate
              ? 'manual_obligation_payment'
              : 'same_currency',
        ),
      ),
      ...mapToFirestore(
        {
          'date': _date ?? FieldValue.serverTimestamp(),
          'category_name': budgetCategory,
          'budget_category': budgetCategory,
          'budget_category_type': 'expense',
        },
      ),
    };
    await txRef.set(fullTxData);
    await createEntriesForTransaction(
      firestore: FirebaseFirestore.instance,
      transactionRef: txRef,
      transactionData: fullTxData,
    );
    await _applyDebtPaymentForCounterparty(
      firestore: FirebaseFirestore.instance,
      companyId: companyId,
      counterpartyName: _counterpartyController.text.trim(),
      ledgerScope: ledgerScopeFromLegacyValue(_typeUchet),
      paymentTransactionId: txRef.id,
      amount: _amountCompany,
    );
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('tranzaction', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('sheta', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('debt_register', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('debt_payment_links', companyId);
    await TransactionSync.recomputeAllForCompany(companyId);
    if (mounted) {
      Navigator.pop(context, _amountCompany);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Оплата обязательства'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _textController,
                decoration: InputDecoration(labelText: 'Описание'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите описание' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _counterpartyController,
                decoration: InputDecoration(labelText: 'Контрагент'),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration:
                    InputDecoration(labelText: 'Сумма ($_accountCurrency)'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введите сумму';
                  final entered = double.tryParse(
                        value.replaceAll(' ', '').replaceAll(',', '.'),
                      ) ??
                      0;
                  final amount = (widget.obligation['amount'] ?? 0).toDouble();
                  final paid =
                      (widget.obligation['total_paid'] ?? 0).toDouble();
                  final remaining = (amount - paid).clamp(0, amount).toDouble();
                  if (entered <= 0) return 'Сумма должна быть больше нуля';
                  final enteredCompany =
                      entered * (_needsExchangeRate ? _exchangeRate : 1.0);
                  if (enteredCompany > remaining) {
                    return 'Не больше остатка ${remaining.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _typeUchet,
                items: [
                  DropdownMenuItem(
                      value: 'Up1', child: Text('Управленческий (С)')),
                  DropdownMenuItem(value: 'Bu', child: Text('Бухгалтерский')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _typeUchet = value;
                  });
                },
                decoration: InputDecoration(labelText: 'Тип учета'),
              ),
              SizedBox(height: 12),
              StreamBuilder<List<ShetaRecord>>(
                stream: queryShetaRecord(
                  queryBuilder: (shetaRecord) => shetaRecord.where(
                    'idCompany',
                    isEqualTo: _companyId,
                  ),
                ),
                builder: (context, snapshot) {
                  final accounts = snapshot.data ?? [];
                  final hasValue =
                      accounts.any((account) => account.reference == _schetId);
                  return DropdownButtonFormField<DocumentReference>(
                    value: hasValue ? _schetId : null,
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.reference,
                        child: Text('${account.title} (${account.currency})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final match =
                          accounts.where((a) => a.reference == value).toList();
                      _selectAccount(match.isNotEmpty ? match.first : null);
                    },
                    decoration: InputDecoration(labelText: 'Счет'),
                  );
                },
              ),
              if (_schetId != null) ...[
                SizedBox(height: 12),
                if (_needsExchangeRate)
                  TextFormField(
                    controller: _exchangeRateController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Курс $_accountCurrency → $_companyCurrency',
                      helperText:
                          'В отчетах будет ${formatMoneyWithCurrency(_amountCompany, currencyCode: _companyCurrency)}',
                    ),
                    validator: (value) {
                      if (!_needsExchangeRate) return null;
                      final rate = double.tryParse(
                            (value ?? '')
                                .replaceAll(' ', '')
                                .replaceAll(',', '.'),
                          ) ??
                          0;
                      if (rate <= 0) return 'Укажите курс больше нуля';
                      return null;
                    },
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Валюта компании: $_companyCurrency, курс 1',
                      style: FlutterFlowTheme.of(context).bodySmall,
                    ),
                  ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _date == null
                          ? 'Дата не выбрана'
                          : dateTimeFormat(
                              'd/M/y',
                              _date!,
                              locale: FFLocalizations.of(context).languageCode,
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text('Выбрать дату'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Отмена'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Создать'),
        ),
      ],
    );
  }
}

class AddObligationDialog extends StatefulWidget {
  final VoidCallback onObligationAdded;
  final Map<String, dynamic>? existing;

  const AddObligationDialog({
    Key? key,
    required this.onObligationAdded,
    this.existing,
  }) : super(key: key);

  @override
  _AddObligationDialogState createState() => _AddObligationDialogState();
}

class _AddObligationDialogState extends State<AddObligationDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _titleController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '0');
  final _dueDateController = TextEditingController();
  String _selectedType = 'Аренда';
  String _selectedPeriodicity = 'Ежемесячно';
  bool _isPeriodic = true;
  bool _isSubmitting = false;
  String _companyCurrency = 'KZT';
  String _companyCurrencySymbol = moneySymbolForCurrency('KZT');

  final List<String> _types = [
    'Аренда',
    'Кредит',
    'Лизинг',
    'Налог',
    'Зарплата',
    'Коммунальные',
    'Услуги',
    'Другое',
  ];

  final List<String> _frequencies = [
    'Ежедневно',
    'Еженедельно',
    'Ежемесячно',
    'Ежеквартально',
    'Раз в 6 месяцев',
    'Ежегодно',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dueDateController.text = _formatObligationDate(now);
    _loadCompanyCurrency();
    final ex = widget.existing;
    if (ex != null) {
      _titleController.text = (ex['title'] ?? '').toString();
      _counterpartyController.text = (ex['counterparty'] ?? '').toString();
      _descriptionController.text = (ex['description'] ?? '').toString();
      _amountController.text = (ex['amount'] ?? '').toString();
      _creditLimitController.text =
          (ex['counterparty_credit_limit'] ?? 0).toString();
      final existingDate =
          _parseObligationDate(ex['due_date'] ?? ex['period_end']);
      _dueDateController.text = existingDate != null
          ? _formatObligationDate(existingDate)
          : (ex['due_date'] ?? ex['period_end'] ?? '').toString();
      final type = (ex['type'] ?? '').toString();
      if (_types.contains(type)) {
        _selectedType = type;
      } else if (type.isNotEmpty) {
        _selectedType = 'Другое';
        _customTypeController.text = type;
      }
      final freq = (ex['frequency'] ?? ex['periodicity'] ?? '').toString();
      if (_frequencies.contains(freq)) {
        _selectedPeriodicity = freq;
        _isPeriodic = true;
      } else {
        _isPeriodic = false;
      }
    }
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  Future<void> _loadCompanyCurrency() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = _effectiveCompanyId(user);
    Map<String, dynamic> profileData = const <String, dynamic>{};
    try {
      final snap =
          await _firestore.collection('company_profile').doc(companyId).get();
      profileData = snap.data() ?? const <String, dynamic>{};
    } catch (_) {}
    final profile = countryProfileFromData(profileData);
    final currency = companyCurrencyFromProfileData(
      profileData,
      fallback: profile.baseCurrency,
    );
    if (!mounted) return;
    setState(() {
      _companyCurrency = currency;
      _companyCurrencySymbol = moneySymbolForCurrency(currency);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final effectiveCompanyId = _effectiveCompanyId(user);

      final obligationType = _selectedType == 'Другое'
          ? _customTypeController.text.trim()
          : _selectedType;
      final data = {
        'title': _titleController.text,
        'type': obligationType.isEmpty ? _selectedType : obligationType,
        'status': widget.existing?['status'] ?? 'Активно',
        'counterparty': _counterpartyController.text,
        'counterparty_credit_limit':
            double.tryParse(_creditLimitController.text) ?? 0.0,
        'frequency': _isPeriodic ? _selectedPeriodicity : 'Разово',
        'periodicity': _isPeriodic ? _selectedPeriodicity : 'Разово',
        'period_end': _dueDateController.text,
        'due_date': _dueDateController.text,
        'description': _descriptionController.text,
        'amount': double.parse(_amountController.text),
        'total_paid': widget.existing?['total_paid'] ?? 0,
        'currency': _companyCurrency,
        'company_currency': _companyCurrency,
        'companyCurrency': _companyCurrency,
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      late final DocumentReference obligationRef;
      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        obligationRef = _firestore.collection('obyaz').doc();
        await obligationRef.set(data);
      } else {
        obligationRef =
            _firestore.collection('obyaz').doc(widget.existing!['id']);
        await obligationRef.update(data);
      }
      await _upsertObligationDebtRegister(
        firestore: _firestore,
        companyId: effectiveCompanyId,
        obligationId: obligationRef.id,
        obligationData: {
          ...data,
          'id': obligationRef.id,
          'created_at': widget.existing?['created_at'] ?? DateTime.now(),
        },
      );
      await upsertEntryForObligation(
        firestore: _firestore,
        obligationRef: obligationRef,
        obligationData: {
          ...data,
          'id': obligationRef.id,
          'created_at': widget.existing?['created_at'] ?? DateTime.now(),
        },
      );

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('obyaz', effectiveCompanyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
          'accounting_entries', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('debt_register', effectiveCompanyId);
      if (navigator.canPop()) {
        navigator.pop();
      }
      widget.onObligationAdded();
      messenger.showSnackBar(
        SnackBar(
            content: Text(widget.existing == null
                ? 'Обязательство добавлено'
                : 'Обязательство обновлено')),
      );
    } catch (e) {
      debugPrint('Error adding obligation: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении обязательства: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null
                      ? 'Добавить обязательство'
                      : 'Редактировать обязательство',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Тип',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Выберите тип';
                    }
                    return null;
                  },
                ),
                if (_selectedType == 'Другое') ...[
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _customTypeController,
                    decoration: InputDecoration(
                      labelText: 'Свой тип обязательства',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    validator: (value) {
                      if (_selectedType == 'Другое' &&
                          (value == null || value.isEmpty)) {
                        return 'Введите тип';
                      }
                      return null;
                    },
                  ),
                ],
                SizedBox(height: 16),
                TextFormField(
                  controller: _counterpartyController,
                  decoration: InputDecoration(
                    labelText: 'Контрагент',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите контрагента';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                SwitchListTile(
                  value: _isPeriodic,
                  onChanged: (val) {
                    setState(() {
                      _isPeriodic = val;
                    });
                  },
                  title: Text('Периодическое обязательство'),
                ),
                if (_isPeriodic) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedPeriodicity,
                    decoration: InputDecoration(
                      labelText: 'Периодичность',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: _frequencies.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriodicity = value!;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _dueDateController,
                  decoration: InputDecoration(
                    labelText:
                        _isPeriodic ? 'Дата до исполнения' : 'Дата исполнения',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _parseObligationDate(_dueDateController.text) ??
                              DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      _dueDateController.text = _formatObligationDate(date);
                    }
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Сумма ($_companyCurrencySymbol)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите сумму';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Введите корректное число';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Кредитный лимит',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null;
                    }
                    if (double.tryParse(value) == null) {
                      return 'Введите корректное число';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Описание (необязательно)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: Text('Отмена'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Добавить'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();
    _counterpartyController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _creditLimitController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }
}
