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
import '/utils/business_event_support.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/analytics_service.dart';
import '/utils/cogs_integrity_support.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/product_sales_metrics_support.dart';
import '/utils/report_export_service.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_gross_profit_support.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/warehouse_scope_support.dart';

class AnalyticsSalesReportWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const AnalyticsSalesReportWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<AnalyticsSalesReportWidget> createState() =>
      _AnalyticsSalesReportWidgetState();
}

class _AnalyticsSalesReportWidgetState extends State<AnalyticsSalesReportWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<SaleEntryView> _sales = [];
  List<Map<String, dynamic>> _cogsItems = [];
  List<Map<String, dynamic>> _salesItems = [];
  List<Map<String, dynamic>> _cogsRegisterItems = [];
  List<Map<String, dynamic>> _batchConsumptions = [];
  List<Map<String, dynamic>> _businessEvents = [];
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
        setState(() => _sales = []);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final salesSnap = await _firestore
          .collection('sales')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .orderBy('created_at', descending: true)
          .limit(200)
          .getCached();
      final txSnap = await _firestore
          .collection('tranzaction')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final salesItemsSnap = await _firestore
          .collection('sales_items')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final cogsEntrySnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final legacyCogsSnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final batchConsumptionsSnap = await _firestore
          .collection('batch_consumptions')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final businessEventsSnap = await _firestore
          .collection('business_events')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .orderBy('occurred_at', descending: true)
          .limit(400)
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
        final userData = currentUserDocument?.snapshotData;
        final sales = salesSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        final transactions = txSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        final scopedSales = filterRowsByUserShopScope(
          userData: userData,
          rows: buildSalesLedger(sales: sales, transactions: transactions),
        );
        final scopedSaleIds = resolveSaleIdsFromRows(scopedSales);
        _salesItems = filterRowsByShopScopeOrSaleIds(
          userData: userData,
          saleIds: scopedSaleIds,
          rows: salesItemsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _cogsRegisterItems = filterRowsByShopScopeOrSaleIds(
          userData: userData,
          saleIds: scopedSaleIds,
          rows: cogsEntrySnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        final legacyCogsItems = filterRowsByShopScopeOrSaleIds(
          userData: userData,
          saleIds: scopedSaleIds,
          rows: legacyCogsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _cogsItems = resolveSalesCogsItems(
          cogsEntries: _cogsRegisterItems,
          legacyCogsItems: legacyCogsItems,
        );
        _batchConsumptions = filterRowsByShopScopeOrSaleIds(
          userData: userData,
          saleIds: scopedSaleIds,
          rows: batchConsumptionsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _businessEvents = filterRowsByShopScopeOrSaleIds(
          userData: userData,
          saleIds: scopedSaleIds,
          rows: businessEventsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _sales = scopedSales.map(SaleEntryView.fromMap).toList();
      });
    } catch (e) {
      debugPrint('Error loading sales report: $e');
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

  List<Map<String, dynamic>> get _salesBusinessEvents =>
      _businessEvents.where((event) {
        final type = businessEventTypeFromValue(
          (event['event_type'] ?? event['eventType'])?.toString(),
        );
        return type == BusinessEventType.saleCreated ||
            type == BusinessEventType.servicePerformed;
      }).toList(growable: false);

  List<_SalesMonthRow> get _salesByMonth {
    if (_salesBusinessEvents.isNotEmpty) {
      return buildEventAnalyticsMonthRows(events: _salesBusinessEvents)
          .map((row) {
        final dt = DateTime.parse('${row.monthKey}-01');
        final marginPercent =
            row.revenue <= 0 ? 0.0 : (row.margin / row.revenue) * 100;
        return _SalesMonthRow(
          monthKey: row.monthKey,
          monthLabel: _monthLabel(dt),
          revenue: row.revenue,
          cogs: row.cost,
          grossProfit: row.margin,
          marginPercent: marginPercent,
          orders: row.eventCount,
        );
      }).toList();
    }
    final orderCounts = <String, int>{};
    for (final sale in _sales) {
      final dt = sale.createdAt;
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      orderCounts[key] = (orderCounts[key] ?? 0) + 1;
    }
    return buildSalesGrossProfitMonthRows(
      sales: _sales
          .map((sale) => {
                'amount': sale.amount,
                'created_at': sale.createdAt,
              })
          .toList(),
      cogsItems: _cogsItems,
    ).map((row) {
      final dt = DateTime.parse('${row.monthKey}-01');
      return _SalesMonthRow(
        monthKey: row.monthKey,
        monthLabel: _monthLabel(dt),
        revenue: row.revenue,
        cogs: row.cogs,
        grossProfit: row.grossProfit,
        marginPercent: row.marginPercent,
        orders: orderCounts[row.monthKey] ?? 0,
      );
    }).toList();
  }

  SalesGrossProfitSnapshot get _grossProfitSnapshot =>
      _salesBusinessEvents.isNotEmpty
          ? (() {
              final snapshot = computeEventAnalyticsSnapshot(
                events: _salesBusinessEvents,
              );
              final marginPercent = snapshot.revenue <= 0
                  ? 0.0
                  : (snapshot.margin / snapshot.revenue) * 100;
              return SalesGrossProfitSnapshot(
                revenue: snapshot.revenue,
                cogs: snapshot.cost,
                grossProfit: snapshot.margin,
                marginPercent: marginPercent,
              );
            })()
          : computeSalesGrossProfitSnapshot(
              sales: _sales
                  .map((sale) => {
                        'amount': sale.amount,
                        'created_at': sale.createdAt,
                      })
                  .toList(),
              cogsItems: _cogsItems,
            );
  double get _totalRevenue => _grossProfitSnapshot.revenue;
  double get _totalCogs => _grossProfitSnapshot.cogs;
  double get _grossProfit => _grossProfitSnapshot.grossProfit;
  double get _grossMargin => _grossProfitSnapshot.marginPercent;
  int get _ordersCount => _sales.length;
  double get _avgCheck => _ordersCount == 0 ? 0 : _totalRevenue / _ordersCount;
  CogsIntegritySummary get _cogsIntegrity => computeCogsIntegritySummary(
        salesItems: _salesItems,
        cogsEntries: _cogsRegisterItems,
        legacyCogsItems: const [],
        batchConsumptions: _batchConsumptions,
      );
  Future<void> _exportCogsAuditExcel() {
    return exportReportExcel(
      filename: 'cogs_audit.xls',
      title: 'COGS Audit',
      rows: buildCogsIntegrityExportRows(summary: _cogsIntegrity),
    );
  }

  Future<void> _exportCogsAuditPdf() {
    return exportReportPdf(
      filename: 'cogs_audit.pdf',
      title: 'COGS Audit',
      rows: buildCogsIntegrityExportRows(summary: _cogsIntegrity),
    );
  }

  List<Map<String, dynamic>> get _productMetrics {
    final rows = buildProductSalesMetricsRows(
      salesItems: _salesItems,
      cogsEntries: _cogsItems,
    );
    rows.sort(
      (a, b) => productSalesNum(b['profit']).compareTo(
        productSalesNum(a['profit']),
      ),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('analytics.sales')) {
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
                    color: FlutterFlowTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отчёт продаж',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выручка, средний чек, топ магазинов и COGS',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _exportCogsAuditPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('COGS PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _exportCogsAuditExcel,
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('COGS Excel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _panelSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _panelBorder),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        labelColor: FlutterFlowTheme.of(context).primaryText,
                        unselectedLabelColor: _mutedText,
                        indicator: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tabs: const [
                          Tab(text: 'Продажи'),
                          Tab(text: 'COGS'),
                          Tab(text: 'Товары'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _statCard(
                                    title: 'Выручка',
                                    value: _formatMoney(_totalRevenue),
                                    icon: Icons.attach_money,
                                    iconBg: FlutterFlowTheme.of(context)
                                        .success
                                        .withValues(alpha: 0.14),
                                    iconColor:
                                        FlutterFlowTheme.of(context).success,
                                  ),
                                  _statCard(
                                    title: 'Чеки',
                                    value: _ordersCount.toString(),
                                    icon: Icons.receipt_long,
                                    iconBg: FlutterFlowTheme.of(context)
                                        .warning
                                        .withValues(alpha: 0.14),
                                    iconColor:
                                        FlutterFlowTheme.of(context).warning,
                                  ),
                                  _statCard(
                                    title: 'Средний чек',
                                    value: _formatMoney(_avgCheck),
                                    icon: Icons.trending_up,
                                    iconBg:
                                        FlutterFlowTheme.of(context).accent1,
                                    iconColor:
                                        FlutterFlowTheme.of(context).primary,
                                  ),
                                  _statCard(
                                    title: 'COGS',
                                    value: _formatMoney(_totalCogs),
                                    icon: Icons.inventory_2_outlined,
                                    iconBg: FlutterFlowTheme.of(context)
                                        .warning
                                        .withValues(alpha: 0.14),
                                    iconColor:
                                        FlutterFlowTheme.of(context).warning,
                                  ),
                                  _statCard(
                                    title: 'Валовая прибыль',
                                    value:
                                        '${_formatMoney(_grossProfit)} (${_grossMargin.toStringAsFixed(1)}%)',
                                    icon: Icons.show_chart,
                                    iconBg: FlutterFlowTheme.of(context)
                                        .success
                                        .withValues(alpha: 0.14),
                                    iconColor:
                                        FlutterFlowTheme.of(context).success,
                                  ),
                                  _statCard(
                                    title: 'COGS Audit',
                                    value:
                                        '${_cogsIntegrity.totalIssues} проблем',
                                    subtitle:
                                        'Нет COGS: ${_cogsIntegrity.missingCogsCount} • FIFO: ${_cogsIntegrity.fifoMissingBatchCount}',
                                    icon: Icons.rule_folder_outlined,
                                    iconBg: FlutterFlowTheme.of(context)
                                        .warning
                                        .withValues(alpha: 0.14),
                                    iconColor:
                                        FlutterFlowTheme.of(context).warning,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _panelSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _panelBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Продажи по месяцам',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _tableHeader(),
                                          const Divider(height: 1),
                                          Expanded(
                                            child: _salesByMonth.isEmpty
                                                ? Center(
                                                    child: Text(
                                                      'Данные не найдены',
                                                      style: TextStyle(
                                                          color: _mutedText),
                                                    ),
                                                  )
                                                : ListView(
                                                    children: _salesByMonth
                                                        .map(_tableRow)
                                                        .toList(),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SalesCogsBreakdownWidget(embedded: true),
                        Container(
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
                                'Товары по валовой прибыли',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _productHeader(),
                              const Divider(height: 1),
                              Expanded(
                                child: _loading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _productMetrics.isEmpty
                                        ? Center(
                                            child: Text(
                                              'Данные не найдены',
                                              style:
                                                  TextStyle(color: _mutedText),
                                            ),
                                          )
                                        : ListView(
                                            children: _productMetrics
                                                .take(50)
                                                .map(_productRow)
                                                .toList(),
                                          ),
                              ),
                            ],
                          ),
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
    String? subtitle,
  }) {
    return SizedBox(
      width: 220,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _mutedText),
                    ),
                  ],
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
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Чеки', flex: 1),
        _HeaderCell('Маржа', flex: 1),
      ],
    );
  }

  Widget _tableRow(_SalesMonthRow row) {
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
          _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
          _Cell(
            _formatMoney(row.grossProfit),
            flex: 2,
            amount: row.grossProfit,
          ),
          _Cell(row.orders.toString(), flex: 1),
          _Cell('${row.marginPercent.toStringAsFixed(1)}%', flex: 1),
        ],
      ),
    );
  }

  Widget _productHeader() {
    return const Row(
      children: [
        _HeaderCell('Товар', flex: 3),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Маржа', flex: 1),
      ],
    );
  }

  Widget _productRow(Map<String, dynamic> row) {
    final revenue = productSalesNum(row['revenue']);
    final cost = productSalesNum(row['cost']);
    final profit = productSalesNum(row['profit']);
    final margin = productSalesNum(row['margin']);
    final name = (row['product_name'] ?? '').toString().trim();
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
          _Cell(name.isEmpty ? 'Без названия' : name, flex: 3, bold: true),
          _Cell(_formatMoney(revenue), flex: 2, amount: revenue),
          _Cell(_formatMoney(cost), flex: 2, amount: cost),
          _Cell(_formatMoney(profit), flex: 2, amount: profit),
          _Cell('${margin.toStringAsFixed(1)}%', flex: 1),
        ],
      ),
    );
  }
}

class _SalesMonthRow {
  final String monthKey;
  final String monthLabel;
  double revenue;
  double cogs;
  double grossProfit;
  double marginPercent;
  int orders;

  _SalesMonthRow({
    required this.monthKey,
    required this.monthLabel,
    this.revenue = 0,
    this.cogs = 0,
    this.grossProfit = 0,
    this.marginPercent = 0,
    this.orders = 0,
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
