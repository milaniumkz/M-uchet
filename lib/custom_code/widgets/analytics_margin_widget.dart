// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/product_sales_metrics_support.dart';
import '/utils/sale_item_cogs_report_support.dart';

class AnalyticsMarginWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const AnalyticsMarginWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<AnalyticsMarginWidget> createState() => _AnalyticsMarginWidgetState();
}

class _AnalyticsMarginWidgetState extends State<AnalyticsMarginWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<MarginMonthEntryView> _items = [];
  List<Map<String, dynamic>> _methodRows = [];
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
        setState(() => _items = []);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final snap = await _firestore
          .collection('sales_items')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final cogsSnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final legacyCogsSnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final productsSnap = await _firestore
          .collection('nomenklatura')
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
        final salesItems = snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        final cogsItems = resolveSalesCogsItems(
          cogsEntries: cogsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
          legacyCogsItems: legacyCogsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _items = buildMonthlyMarginMetrics(
          salesItems: salesItems,
          cogsEntries: cogsItems,
        ).map(MarginMonthEntryView.fromMap).toList();
        _methodRows = buildCostingMethodMarginMetrics(
          salesItems: salesItems,
          cogsEntries: cogsItems,
          products: productsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
      });
    } catch (e) {
      debugPrint('Error loading margin data: $e');
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

  List<_MarginMonthRow> get _monthlyRows {
    final map = <String, _MarginMonthRow>{};
    for (final item in _items) {
      final dt = item.date;
      if (dt == null) continue;
      final key = item.monthKey;
      map.putIfAbsent(
        key,
        () => _MarginMonthRow(monthKey: key, monthLabel: _monthLabel(dt)),
      );
      map[key]!.revenue += item.revenue;
      map[key]!.cost += item.cost;
    }
    final rows = map.values.toList();
    rows.sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return rows;
  }

  double get _totalRevenue => _monthlyRows.fold(0.0, (s, i) => s + i.revenue);
  double get _totalCost => _monthlyRows.fold(0.0, (s, i) => s + i.cost);
  double get _totalMargin => _totalRevenue - _totalCost;
  double get _fifoRevenue => _methodMetric('FIFO', 'revenue');
  double get _avgRevenue => _methodMetric('WEIGHTED_AVERAGE', 'revenue');
  double get _fifoProfit => _methodMetric('FIFO', 'profit');
  double get _avgProfit => _methodMetric('WEIGHTED_AVERAGE', 'profit');

  double _methodMetric(String method, String key) {
    final row = _methodRows.firstWhere(
      (item) => (item['method'] ?? '') == method,
      orElse: () => const <String, dynamic>{},
    );
    return productSalesNum(row[key]);
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('analytics.margin')) {
      return PermissionsHelper.noAccess();
    }
    final marginPercent =
        _totalRevenue == 0 ? 0 : (_totalMargin / _totalRevenue) * 100;
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
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.percent, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Маржа',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Маржинальность по товарам',
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
                  title: 'Выручка',
                  value: _formatMoney(_totalRevenue),
                  icon: Icons.attach_money,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Себестоимость',
                  value: _formatMoney(_totalCost),
                  icon: Icons.shopping_bag_outlined,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Валовая',
                  value: _formatMoney(_totalMargin),
                  icon: Icons.stacked_line_chart,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Маржа',
                  value: '${marginPercent.toStringAsFixed(0)}%',
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
                          'Маржинальность по месяцам',
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
                                    'Данные не найдены',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : ListView(
                                  children: [
                                    ..._monthlyRows.map(_tableRow),
                                    const SizedBox(height: 16),
                                    Text(
                                      'По методу списания',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _methodChip(
                                          inventoryCostingMethodLabel(
                                            InventoryCostingMethod.fifo,
                                          ),
                                          _fifoRevenue,
                                          _fifoProfit,
                                        ),
                                        _methodChip(
                                          inventoryCostingMethodLabel(
                                            InventoryCostingMethod
                                                .weightedAverage,
                                          ),
                                          _avgRevenue,
                                          _avgProfit,
                                        ),
                                      ],
                                    ),
                                  ],
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
    return const Row(
      children: [
        _HeaderCell('Месяц', flex: 3),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('Себестоимость', flex: 2),
        _HeaderCell('Маржа', flex: 2),
      ],
    );
  }

  Widget _tableRow(_MarginMonthRow row) {
    final marginPercent =
        row.revenue == 0 ? 0 : (row.margin / row.revenue) * 100;
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
          _Cell(_formatMoney(row.revenue), flex: 2, amount: row.revenue),
          _Cell(_formatMoney(row.cost), flex: 2, amount: row.cost),
          _Cell('${marginPercent.toStringAsFixed(0)}%', flex: 2),
        ],
      ),
    );
  }

  Widget _methodChip(String label, double revenue, double profit) {
    final margin = revenue <= 0 ? 0 : (profit / revenue) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Выручка: ${_formatMoney(revenue)}',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          Text(
            'Валовая: ${_formatMoney(profit)}',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          Text(
            'Маржа: ${margin.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
        ],
      ),
    );
  }
}

class _MarginMonthRow {
  final String monthKey;
  final String monthLabel;
  double revenue = 0;
  double cost = 0;
  double get margin => revenue - cost;

  _MarginMonthRow({
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
