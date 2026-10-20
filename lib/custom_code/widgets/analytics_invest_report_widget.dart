// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';

class AnalyticsInvestReportWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const AnalyticsInvestReportWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<AnalyticsInvestReportWidget> createState() =>
      _AnalyticsInvestReportWidgetState();
}

class _AnalyticsInvestReportWidgetState
    extends State<AnalyticsInvestReportWidget> with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<InvestmentEntryView> _investments = [];
  String _currencyCode = 'KZT';
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF111722) : const Color(0xFFF7F8FA);
  Color get _panelSurface => _isDarkTheme
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.03),
          FlutterFlowTheme.of(context).secondaryBackground,
        )
      : FlutterFlowTheme.of(context).secondaryBackground;
  Color get _panelBorder => _isDarkTheme
      ? FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.42)
      : FlutterFlowTheme.of(context).alternate;
  Color get _mutedText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.72)
      : FlutterFlowTheme.of(context).secondaryText;

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
        setState(() => _investments = []);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final snap = await _firestore
          .collection('investments')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _investments = snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return InvestmentEntryView.fromMap({'id': d.id, ...data});
        }).toList();
      });
    } catch (e) {
      print('Error loading investments: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  String _monthLabel(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.year}';
  }

  List<_InvestMonthRow> get _monthlyRows {
    final map = <String, _InvestMonthRow>{};
    for (final item in _investments) {
      final dt = item.createdAt;
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(
        key,
        () => _InvestMonthRow(monthKey: key, monthLabel: _monthLabel(dt)),
      );
      map[key]!.invested += item.amount;
      map[key]!.returned += item.returnAmount;
    }
    final rows = map.values.toList();
    rows.sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return rows;
  }

  double get _totalInvested => _investments.fold(0, (s, i) => s + i.amount);
  double get _totalReturn => _investments.fold(0, (s, i) => s + i.returnAmount);
  double get _roi =>
      _totalInvested == 0 ? 0 : (_totalReturn / _totalInvested) * 100;

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('analytics.invest')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
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
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.savings_outlined,
                      color: Color(0xFF9E7B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Инвест‑отчёт',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Инвестиции и их окупаемость',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
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
            child: Row(
              children: [
                _statCard(
                  title: 'Инвестировано',
                  value: _formatMoney(_totalInvested),
                  icon: Icons.savings,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Возврат',
                  value: _formatMoney(_totalReturn),
                  icon: Icons.trending_up,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'ROI',
                  value: '${_roi.toStringAsFixed(0)}%',
                  icon: Icons.percent,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
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
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Инвестиции по месяцам',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _monthlyRows.isEmpty
                              ? Center(
                                  child: Text(
                                    'Инвестиций не найдено',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _monthlyRows.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_monthlyRows[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panelSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _panelBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 12, color: _mutedText)),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
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
      ),
    );
  }

  Widget _tableHeader() {
    return Row(
      children: const [
        _HeaderCell('Месяц', flex: 3),
        _HeaderCell('Инвестиции', flex: 2),
        _HeaderCell('Возврат', flex: 2),
        _HeaderCell('ROI', flex: 1),
      ],
    );
  }

  Widget _tableRow(_InvestMonthRow row) {
    final roi = row.invested == 0 ? 0 : (row.returned / row.invested) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _Cell(row.monthLabel, flex: 3, bold: true),
          _Cell(_formatMoney(row.invested), flex: 2, amount: row.invested),
          _Cell(_formatMoney(row.returned), flex: 2, amount: row.returned),
          _Cell('${roi.toStringAsFixed(0)}%', flex: 1),
        ],
      ),
    );
  }
}

class _InvestMonthRow {
  final String monthKey;
  final String monthLabel;
  double invested = 0;
  double returned = 0;

  _InvestMonthRow({
    required this.monthKey,
    required this.monthLabel,
  });
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
            fontSize: 12,
            color: FlutterFlowTheme.of(context).secondaryText,
          )),
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
