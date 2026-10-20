// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/accounting_accounts.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/money_flow_type.dart';
import '/utils/owner_investment_support.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoneyCompanyMoneyWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const MoneyCompanyMoneyWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<MoneyCompanyMoneyWidget> createState() =>
      _MoneyCompanyMoneyWidgetState();
}

class _MoneyCompanyMoneyWidgetState extends State<MoneyCompanyMoneyWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<_CompanyCashFlowRow> _rows = [];
  MoneyFlowType? _flowFilter;
  String _currencyCode = 'KZT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _rows = const []);
        return;
      }
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final snap = await _firestore
          .collection('accounting_entries')
          .where('idCompany', isEqualTo: companyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();

      final rows = snap.docs
          .map((d) => AccountingEntryRecord.fromSnapshot(d))
          .map(_buildCashFlowRow)
          .whereType<_CompanyCashFlowRow>()
          .toList()
        ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _rows = rows;
      });
    } catch (e) {
      debugPrint('Error loading company cash flow: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  _CompanyCashFlowRow? _buildCashFlowRow(AccountingEntryRecord entry) {
    final debitNature = accountNatureForId(entry.debitAccountId);
    final creditNature = accountNatureForId(entry.creditAccountId);
    final debitIsAsset = debitNature == AccountNature.asset &&
        !_isNonCashAsset(entry.debitAccountId);
    final creditIsAsset = creditNature == AccountNature.asset &&
        !_isNonCashAsset(entry.creditAccountId);

    if (!debitIsAsset && !creditIsAsset) return null;

    final date = entry.entryDate ?? entry.createdAt ?? entry.updatedAt;
    final flowType = entry.moneyFlowTypeEnum;
    final amount = entry.amount;
    final isOwnerOpeningBalance = flowType == MoneyFlowType.financing &&
        (looksLikeOwnerInvestmentLabel(entry.description) ||
            looksLikeOwnerInvestmentLabel(entry.memo) ||
            looksLikeOwnerInvestmentLabel(entry.debitAccountTitle) ||
            looksLikeOwnerInvestmentLabel(entry.creditAccountTitle));

    if (debitIsAsset && creditIsAsset) {
      return _CompanyCashFlowRow(
        date: date,
        sortDate: date ?? DateTime.fromMillisecondsSinceEpoch(0),
        flowType: flowType,
        title: entry.description.trim().isEmpty
            ? 'Внутренний перевод'
            : entry.description.trim(),
        description: entry.memo.trim().isEmpty
            ? '${entry.creditAccountTitle} -> ${entry.debitAccountTitle}'
            : entry.memo.trim(),
        accountTitle:
            '${entry.creditAccountTitle.trim().isEmpty ? '-' : entry.creditAccountTitle} -> ${entry.debitAccountTitle.trim().isEmpty ? '-' : entry.debitAccountTitle}',
        signedAmount: 0,
        displayAmount: amount,
        isTransfer: true,
        displayFlowLabel: isOwnerOpeningBalance
            ? ownerInvestmentDisplayLabel
            : flowType.label,
      );
    }

    final signedAmount = debitIsAsset ? amount : -amount;
    return _CompanyCashFlowRow(
      date: date,
      sortDate: date ?? DateTime.fromMillisecondsSinceEpoch(0),
      flowType: flowType,
      title: (debitIsAsset ? entry.creditAccountTitle : entry.debitAccountTitle)
              .trim()
              .isEmpty
          ? 'Прочее'
          : (debitIsAsset ? entry.creditAccountTitle : entry.debitAccountTitle)
              .trim(),
      description: entry.description.trim().isEmpty
          ? (entry.memo.trim().isEmpty ? '-' : entry.memo.trim())
          : entry.description.trim(),
      accountTitle: (debitIsAsset
                  ? entry.debitAccountTitle
                  : entry.creditAccountTitle)
              .trim()
              .isEmpty
          ? '-'
          : (debitIsAsset ? entry.debitAccountTitle : entry.creditAccountTitle)
              .trim(),
      signedAmount: signedAmount,
      displayAmount: amount,
      isTransfer: false,
      displayFlowLabel:
          isOwnerOpeningBalance ? ownerInvestmentDisplayLabel : flowType.label,
    );
  }

  bool _isNonCashAsset(String accountId) {
    final normalized = accountId.trim().toLowerCase();
    return normalized.startsWith('virtual:asset:receivable:') ||
        normalized.startsWith('virtual:asset:inventory:') ||
        normalized.startsWith('virtual:asset:fixed_asset:');
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  List<_CompanyCashFlowRow> get _visibleRows {
    if (_flowFilter == null) return _rows;
    return _rows.where((row) => row.flowType == _flowFilter).toList();
  }

  double _sumForFlow(MoneyFlowType flowType) {
    return _rows
        .where((row) => row.flowType == flowType && !row.isTransfer)
        .fold<double>(0, (total, row) => total + row.signedAmount);
  }

  double get _operating => _sumForFlow(MoneyFlowType.operating);
  double get _investing => _sumForFlow(MoneyFlowType.investing);
  double get _financing => _sumForFlow(MoneyFlowType.financing);
  double get _netCashFlow => _operating + _investing + _financing;
  double get _transferVolume => _rows
      .where((row) => row.flowType == MoneyFlowType.transfer || row.isTransfer)
      .fold<double>(0, (total, row) => total + row.displayAmount.abs());

  void _openJournalForFlow(MoneyFlowType? flowType) {
    final params = <String, String>{
      if (flowType != null) 'flow': flowType.storageValue,
    };
    context.pushNamedAuth(
      'tranzactionJournal',
      mounted,
      queryParameters: params,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AuthUserStreamWidget(
      builder: (context) {
        scheduleReloadOnCompanyChange(_loadData);
        if (!PermissionsHelper.has('money.my')) {
          return PermissionsHelper.noAccess();
        }
        return ResponsiveFrame(
          backgroundColor: const Color(0xFFF7F8FA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.accent1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance_wallet_outlined,
                          color: theme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Денежные потоки компании',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Operating, investing, financing и внутренние переводы из проводок',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _statCard(
                      title: 'Net Cash Flow',
                      value: _formatMoney(_netCashFlow),
                      amount: _netCashFlow,
                      icon: Icons.show_chart,
                      iconBg: theme.accent1,
                      iconColor: theme.primary,
                      onTap: () => _openJournalForFlow(null),
                    ),
                    _statCard(
                      title: 'Operating',
                      value: _formatMoney(_operating),
                      amount: _operating,
                      icon: Icons.work_outline,
                      iconBg: theme.success.withValues(alpha: 0.14),
                      iconColor: theme.success,
                      onTap: () => _openJournalForFlow(MoneyFlowType.operating),
                    ),
                    _statCard(
                      title: 'Investing',
                      value: _formatMoney(_investing),
                      amount: _investing,
                      icon: Icons.precision_manufacturing_outlined,
                      iconBg: theme.warning.withValues(alpha: 0.14),
                      iconColor: theme.warning,
                      onTap: () => _openJournalForFlow(MoneyFlowType.investing),
                    ),
                    _statCard(
                      title: 'Financing',
                      value: _formatMoney(_financing),
                      amount: _financing,
                      icon: Icons.account_balance_outlined,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () => _openJournalForFlow(MoneyFlowType.financing),
                    ),
                    _statCard(
                      title: 'Transfers',
                      value: _formatMoney(_transferVolume),
                      amount: null,
                      icon: Icons.swap_horiz,
                      iconBg: const Color(0xFFE5E7EB),
                      iconColor: const Color(0xFF4B5563),
                      onTap: () => _openJournalForFlow(MoneyFlowType.transfer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все'),
                      selected: _flowFilter == null,
                      onSelected: (_) => setState(() => _flowFilter = null),
                    ),
                    for (final flowType in MoneyFlowType.values)
                      ChoiceChip(
                        label: Text(flowType.label),
                        selected: _flowFilter == flowType,
                        onSelected: (_) =>
                            setState(() => _flowFilter = flowType),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.alternate),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Журнал денежных потоков',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                _HeaderCell('Дата', flex: 2),
                                _HeaderCell('Поток', flex: 2),
                                _HeaderCell('Статья', flex: 3),
                                _HeaderCell('Описание', flex: 4),
                                _HeaderCell('Счет', flex: 3),
                                _HeaderCell('Cash Impact', flex: 2),
                              ],
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _visibleRows.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Денежных потоков не найдено',
                                        style: TextStyle(
                                            color: theme.secondaryText),
                                      ),
                                    )
                                  : ListView(
                                      children: _visibleRows.map(_row).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    num? amount,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final card = Container(
      width: 210,
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: theme.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: amountTextColor(
                      context,
                      amount,
                      positiveColor: theme.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _row(_CompanyCashFlowRow item) {
    final date = item.date;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          _Cell(date == null ? '-' : dateTimeFormat('d/M/y', date), flex: 2),
          _Cell(item.displayFlowLabel, flex: 2, bold: true),
          _Cell(item.title, flex: 3, bold: true),
          _Cell(item.description, flex: 4),
          _Cell(item.accountTitle, flex: 3),
          _Cell(
            _formatMoney(item.signedAmount),
            flex: 2,
            amount: item.signedAmount,
          ),
        ],
      ),
    );
  }
}

class _CompanyCashFlowRow {
  const _CompanyCashFlowRow({
    required this.date,
    required this.sortDate,
    required this.flowType,
    required this.title,
    required this.description,
    required this.accountTitle,
    required this.signedAmount,
    required this.displayAmount,
    required this.isTransfer,
    required this.displayFlowLabel,
  });

  final DateTime? date;
  final DateTime sortDate;
  final MoneyFlowType flowType;
  final String title;
  final String description;
  final String accountTitle;
  final double signedAmount;
  final double displayAmount;
  final bool isTransfer;
  final String displayFlowLabel;
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: FlutterFlowTheme.of(context).secondaryText,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final num? amount;

  const _Cell(this.text, {required this.flex, this.bold = false, this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: amountTextColor(
            context,
            amount,
            positiveColor: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
      ),
    );
  }
}
