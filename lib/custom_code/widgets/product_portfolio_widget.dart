// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
import 'dart:math' as math;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/inventory_batch_metrics_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/product_batch_report_support.dart';
import '/utils/product_portfolio_discount_service.dart';
import '/utils/product_portfolio_support.dart';
import '/utils/product_sales_metrics_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/ledger_scope.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ProductPortfolioWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final Function()? onExport;

  const ProductPortfolioWidget({
    super.key,
    this.width,
    this.height,
    this.onExport,
  });

  @override
  State<ProductPortfolioWidget> createState() => _ProductPortfolioWidgetState();
}

class _ProductPortfolioWidgetState extends State<ProductPortfolioWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _batchDocs = [];

  String _tab = 'sales'; // sales, revenue, discount, abc, requests
  String _categoryFilter = 'all';
  String _abcFilter = 'all';
  String _costingFilter = 'all';
  String _sortBy = 'salesCount';
  final Set<String> _expandedProductIds = <String>{};
  bool _showOfficialColumn = true;
  bool _showUnofficialColumn = true;
  String _currencyCode = 'KZT';

  bool _loading = false;

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

  Color _textOn(Color color, {double darkAlpha = 0.92}) {
    return color.computeLuminance() > 0.6
        ? const Color(0xFF111827)
        : Colors.white.withValues(alpha: darkAlpha);
  }

  Map<String, dynamic> _docMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _filtered = [];
        });
        return;
      }

      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final results = await Future.wait<dynamic>([
        _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sales_items')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('cogs_register')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sale_item_cogs')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('inventory_batches')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
      ]);
      final snap = results[0] as QuerySnapshot;
      final salesItemsSnap = results[1] as QuerySnapshot;
      final cogsSnap = results[2] as QuerySnapshot;
      final legacyCogsSnap = results[3] as QuerySnapshot;
      final batchesSnap = results[4] as QuerySnapshot;
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final unique = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        final data = _docMap(d.data());
        final enriched = {'id': d.id, ...data};
        final candidate =
            (enriched['sku'] ?? enriched['code'] ?? enriched['name'] ?? d.id)
                .toString()
                .trim();
        final key = candidate.isEmpty ? d.id : candidate;
        if (unique.containsKey(key)) continue;
        unique[key] = enriched;
      }

      final rawItemsList = unique.values.toList();
      final batches = batchesSnap.docs.map((d) {
        final data = _docMap(d.data());
        return {'id': d.id, ...data};
      }).toList();
      final liveValuedItems = List<Map<String, dynamic>>.from(
        enrichProductsWithBatchValuation(
          products: rawItemsList,
          inventoryBatches: batches,
        )['items'] as List,
      );
      final salesItems = salesItemsSnap.docs.map((d) {
        final data = _docMap(d.data());
        return {'id': d.id, ...data};
      }).toList();
      final cogsItems = resolveSalesCogsItems(
        cogsEntries: cogsSnap.docs.map((d) {
          final data = _docMap(d.data());
          return {'id': d.id, ...data};
        }).toList(),
        legacyCogsItems: legacyCogsSnap.docs.map((d) {
          final data = _docMap(d.data());
          return {'id': d.id, ...data};
        }).toList(),
      );
      final itemsList = List<Map<String, dynamic>>.from(
        enrichProductsWithSalesMetrics(
          products: liveValuedItems,
          salesItems: salesItems,
          cogsEntries: cogsItems,
        )['items'] as List,
      );
      final categories = _distinctValues('category',
          source: itemsList, include: _categoryFilter);
      final nextCategoryFilter =
          categories.contains(_categoryFilter) ? _categoryFilter : 'all';

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _items = itemsList;
        _filtered = List.from(itemsList);
        _batchDocs = batches;
        _categoryFilter = nextCategoryFilter;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading nomenklatura for portfolio: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    List<Map<String, dynamic>> list = List.from(_items);

    if (_categoryFilter != 'all') {
      list = list
          .where((i) => (i['category'] ?? '').toString() == _categoryFilter)
          .toList();
    }

    if (_abcFilter != 'all') {
      list = list
          .where((i) =>
              (i['abc'] ?? '').toString().toLowerCase() ==
              _abcFilter.toLowerCase())
          .toList();
    }

    if (_costingFilter != 'all') {
      list = list.where((i) {
        return resolveInventoryCostingMethod(productData: i).storageValue ==
            _costingFilter;
      }).toList();
    }

    if (q.isNotEmpty) {
      list = list.where((i) {
        final name = (i['name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }

    if (_tab == 'requests') {
      list = list.where(_needsPurchaseRequest).toList();
    }

    if (_tab == 'discount') {
      list = list
          .where((i) =>
              _inventory(i).discountPercent > 0 ||
              _recommendedDiscountPercent(i) > 0)
          .toList();
    }

    list.sort((a, b) {
      double va = 0;
      double vb = 0;
      switch (_sortBy) {
        case 'salesCount':
          va = _inventory(a).salesCount;
          vb = _inventory(b).salesCount;
          break;
        case 'revenue':
          va = _inventory(a).revenue;
          vb = _inventory(b).revenue;
          break;
        case 'profit':
          va = _inventory(a).profit;
          vb = _inventory(b).profit;
          break;
        case 'turnoverDays':
          va = _turnoverDays(a);
          vb = _turnoverDays(b);
          break;
        case 'agingDays':
          va = _stockAgingDays(a).toDouble();
          vb = _stockAgingDays(b).toDouble();
          break;
        case 'staleCost':
          va = productStaleCost(_inventory(a));
          vb = productStaleCost(_inventory(b));
          break;
      }
      if (_tab == 'abc') {
        final abcCmp = _abcWeight(a).compareTo(_abcWeight(b));
        if (abcCmp != 0) return abcCmp;
      }
      return vb.compareTo(va);
    });

    setState(() => _filtered = list);
  }

  Widget _buildMainPanel(BuildContext context, double listHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
                child: const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF9E7B4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Портфель товаров',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Аналитика и рейтинги по товарам',
                      style: TextStyle(
                        fontSize: 13,
                        color: _mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onExport,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Экспорт'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Обновить'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _statCard(
                title: 'Всего товаров',
                value: '$_totalProducts',
                icon: Icons.inventory_2_outlined,
                iconBg: FlutterFlowTheme.of(context)
                    .warning
                    .withValues(alpha: 0.10),
                iconColor: const Color(0xFFC8A06A),
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Общая выручка',
                value: _money(_totalRevenue),
                valueColor: FlutterFlowTheme.of(context).primary,
                icon: Icons.attach_money,
                iconBg: FlutterFlowTheme.of(context).accent1,
                iconColor: FlutterFlowTheme.of(context).primary,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Общая прибыль',
                value: _money(_totalProfit),
                valueColor: FlutterFlowTheme.of(context).success,
                icon: Icons.trending_up,
                iconBg: FlutterFlowTheme.of(context)
                    .success
                    .withValues(alpha: 0.14),
                iconColor: FlutterFlowTheme.of(context).success,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Сред. коэф. наценки',
                value: _avgMarkupCoeff.toStringAsFixed(0),
                valueColor: const Color(0xFF7C3AED),
                icon: Icons.percent,
                iconBg: const Color(0xFFF2E8FF),
                iconColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Залежалый >90 дн',
                value: _money(_staleOver90Cost),
                valueColor: FlutterFlowTheme.of(context).error,
                icon: Icons.warning_amber_rounded,
                iconBg:
                    FlutterFlowTheme.of(context).error.withValues(alpha: 0.14),
                iconColor: FlutterFlowTheme.of(context).error,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'ABC категории',
                value:
                    'A:${_abcCounts['A']}  B:${_abcCounts['B']}  C:${_abcCounts['C']}',
                icon: Icons.bar_chart,
                iconBg: const Color(0xFFEDE7FF),
                iconColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _tabButton('По продажам', 'sales', Icons.shopping_cart),
              const SizedBox(width: 8),
              _tabButton('По выручке', 'revenue', Icons.attach_money),
              const SizedBox(width: 8),
              _tabButton(
                  'Управление скидками', 'discount', Icons.discount_outlined),
              const SizedBox(width: 8),
              _tabButton('ABC анализ', 'abc', Icons.bar_chart),
              const SizedBox(width: 8),
              _tabButton(
                'Заявки ($_purchaseRequestCount)',
                'requests',
                Icons.assignment,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _panelSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _panelBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: _mutedText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Поиск по наименованию',
                            hintStyle: TextStyle(color: _mutedText),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'Категория товара',
                  value: _categoryFilter,
                  items: _distinctValues('category', include: _categoryFilter),
                  onChanged: (v) {
                    setState(() => _categoryFilter = v ?? 'all');
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'ABC категория',
                  value: _abcFilter,
                  items: ['all', 'A', 'B', 'C'],
                  onChanged: (v) {
                    setState(() => _abcFilter = v ?? 'all');
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'Метод списания',
                  value: _costingFilter,
                  items: const ['all', 'FIFO', 'WEIGHTED_AVERAGE'],
                  onChanged: (v) {
                    setState(() => _costingFilter = v ?? 'all');
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'Сортировка',
                  value: _sortBy,
                  items: [
                    'salesCount',
                    'revenue',
                    'profit',
                    'turnoverDays',
                    'agingDays',
                    'staleCost',
                  ],
                  onChanged: (v) {
                    setState(() => _sortBy = v ?? 'salesCount');
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_tab == 'discount' || _tab == 'abc')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _discountControlPanel(),
          ),
        if (_tab == 'discount' || _tab == 'abc') const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: _showOfficialColumn,
                label: const Text('ОФ'),
                onSelected: (value) {
                  setState(() => _showOfficialColumn = value);
                },
              ),
              FilterChip(
                selected: _showUnofficialColumn,
                label: const Text('неОФ'),
                onSelected: (value) {
                  setState(() => _showUnofficialColumn = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: listHeight,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildPortfolioColumns(listHeight),
        ),
      ],
    );
  }

  bool _isOfficialItem(Map<String, dynamic> item) {
    final batchLabels = _productBatchRows(item)
        .map((row) =>
            (row['warehouse_name'] ?? row['warehouse'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (batchLabels.isNotEmpty) {
      final hasUnofficial = batchLabels.any(_isUnofficialWarehouseLabel);
      final hasOfficial = batchLabels.any(_isOfficialWarehouseLabel);
      if (hasUnofficial && !hasOfficial) return false;
      if (hasOfficial && !hasUnofficial) return true;
    }

    final warehouseLabel = [
      (item['warehouse_name'] ?? '').toString(),
      (item['warehouseName'] ?? '').toString(),
      (item['warehouse'] ?? '').toString(),
      (item['sklad'] ?? '').toString(),
    ].where((value) => value.trim().isNotEmpty).join(' ');

    if (_isUnofficialWarehouseLabel(warehouseLabel)) return false;
    if (_isOfficialWarehouseLabel(warehouseLabel)) return true;

    return warehouseTypeFromData(item).isOfficial;
  }

  bool _isOfficialWarehouseLabel(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('официаль') || normalized.contains('белый');
  }

  bool _isUnofficialWarehouseLabel(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('неофициаль') ||
        normalized.contains('серый') ||
        normalized.contains('gray') ||
        normalized.contains('grey') ||
        normalized.contains('гараж');
  }

  Widget _buildPortfolioColumns(double listHeight) {
    final official = _filtered.where(_isOfficialItem).toList();
    final unofficial = _filtered.where((i) => !_isOfficialItem(i)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return ListView(
              children: [
                _portfolioColumn(
                  'Официальные товары',
                  official,
                  expanded: _showOfficialColumn,
                  onToggle: () => setState(
                      () => _showOfficialColumn = !_showOfficialColumn),
                ),
                const SizedBox(height: 12),
                _portfolioColumn(
                  'Неофициальные товары',
                  unofficial,
                  expanded: _showUnofficialColumn,
                  onToggle: () => setState(
                      () => _showUnofficialColumn = !_showUnofficialColumn),
                ),
              ],
            );
          }
          final sections = <Widget>[
            if (_showOfficialColumn)
              _portfolioColumn(
                'Официальные товары',
                official,
                expanded: true,
                onToggle: () =>
                    setState(() => _showOfficialColumn = !_showOfficialColumn),
              ),
            if (_showUnofficialColumn)
              _portfolioColumn(
                'Неофициальные товары',
                unofficial,
                expanded: true,
                onToggle: () => setState(
                    () => _showUnofficialColumn = !_showUnofficialColumn),
              ),
          ];
          if (sections.isEmpty) {
            return Center(
              child: Text(
                'Обе колонки скрыты',
                style: TextStyle(color: _mutedText),
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                Expanded(
                  child: SingleChildScrollView(child: sections[i]),
                ),
                if (i != sections.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _portfolioColumn(
    String title,
    List<Map<String, dynamic>> rows, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${rows.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(expanded ? 'Свернуть' : 'Развернуть'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!expanded)
            Text(
              'Скрыто',
              style: TextStyle(color: _mutedText),
            )
          else if (rows.isEmpty)
            Text(
              _tab == 'discount'
                  ? 'Нет товаров со скидкой или рекомендацией'
                  : 'Товаров нет',
              style: TextStyle(color: _mutedText),
            )
          else
            ...rows.map(_portfolioExpandableCard),
        ],
      ),
    );
  }

  Widget _portfolioExpandableCard(Map<String, dynamic> i) {
    final entry = _inventory(i);
    final id = entry.id.isNotEmpty ? entry.id : entry.name;
    final expanded = _expandedProductIds.contains(id);
    final name = entry.name.isEmpty ? 'Без названия' : entry.name;
    final currentDiscount = entry.discountPercent.toInt();
    final recommendedDiscount = _recommendedDiscountPercent(i);
    final salesCount = entry.salesCount.toInt();
    final stockCount = entry.stock.toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedProductIds.remove(id);
                } else {
                  _expandedProductIds.add(id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _chip(_tab == 'discount'
                      ? (currentDiscount > 0 ? '$currentDiscount%' : '—')
                      : 'Продаж: $salesCount'),
                  const SizedBox(width: 6),
                  _chip(
                    _tab == 'discount'
                        ? (recommendedDiscount > 0
                            ? '$recommendedDiscount%'
                            : '0%')
                        : 'Остаток: $stockCount',
                    color: _tab == 'discount'
                        ? FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.14)
                        : FlutterFlowTheme.of(context).primaryBackground,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _productCard(i),
            ),
        ],
      ),
    );
  }

  String _money(double v) {
    return formatMoneyWithCurrency(v, currencyCode: _currencyCode);
  }

  InventoryEntryView _inventory(Map<String, dynamic> item) =>
      InventoryEntryView.fromMap(item);

  int get _totalProducts => _items.length;
  double get _totalRevenue =>
      _items.fold(0, (s, i) => s + _inventory(i).revenue);
  double get _totalProfit => _items.fold(0, (s, i) => s + _inventory(i).profit);

  int get _purchaseRequestCount => _items.where(_needsPurchaseRequest).length;

  double get _staleOver90Cost {
    return _items.fold(0.0, (total, item) {
      if (_stockAgingDays(item) <= 90) return total;
      return total + productStaleCost(_inventory(item));
    });
  }

  double get _avgMarkupCoeff {
    double sum = 0;
    int count = 0;
    for (final item in _items) {
      final rawValue = item['markup_ratio'] ?? item['markup_coeff'];
      final explicit = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse((rawValue ?? '').toString().replaceAll(',', '.'));
      if (explicit != null && explicit > 0) {
        sum += explicit;
        count++;
        continue;
      }
      final purchaseRaw = item['purchase_price'] ?? item['cost_price'];
      final saleRaw = item['sale_price'] ?? item['price'];
      final purchase = purchaseRaw is num
          ? purchaseRaw.toDouble()
          : double.tryParse(
                  (purchaseRaw ?? '').toString().replaceAll(',', '.')) ??
              0;
      final sale = saleRaw is num
          ? saleRaw.toDouble()
          : double.tryParse((saleRaw ?? '').toString().replaceAll(',', '.')) ??
              0;
      if (purchase > 0 && sale > 0) {
        sum += sale / purchase;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  Map<String, int> get _abcCounts {
    final map = {'A': 0, 'B': 0, 'C': 0};
    for (final i in _items) {
      final abc = _inventory(i).abc;
      if (map.containsKey(abc)) map[abc] = (map[abc] ?? 0) + 1;
    }
    return map;
  }

  int _stockAgingDays(Map<String, dynamic> item) {
    return productStockAgingDays(_inventory(item));
  }

  String _agingZoneLabel(int days) {
    return productAgingZoneLabel(days);
  }

  Color _agingZoneColor(int days) {
    if (days > 90) return FlutterFlowTheme.of(context).error;
    if (days >= 30) return FlutterFlowTheme.of(context).warning;
    return FlutterFlowTheme.of(context).success;
  }

  bool _needsPurchaseRequest(Map<String, dynamic> item) {
    return productNeedsPurchaseRequest(_inventory(item));
  }

  double _turnoverDays(Map<String, dynamic> item) {
    return productTurnoverDays(_inventory(item));
  }

  String _turnoverLabel(Map<String, dynamic> item) {
    return productTurnoverLabel(_inventory(item));
  }

  Color _turnoverColor(Map<String, dynamic> item) {
    final days = _turnoverDays(item);
    if (days >= 90) return FlutterFlowTheme.of(context).error;
    if (days >= 30) return FlutterFlowTheme.of(context).warning;
    return FlutterFlowTheme.of(context).success;
  }

  int _abcWeight(Map<String, dynamic> item) {
    return productAbcWeight(_inventory(item));
  }

  int _recommendedDiscountPercent(Map<String, dynamic> item) {
    return productRecommendedDiscountPercent(_inventory(item));
  }

  String _discountReason(Map<String, dynamic> item) {
    return productDiscountReason(_inventory(item));
  }

  int _discountDays(Map<String, dynamic> item) {
    return productDiscountDays(_inventory(item));
  }

  int _discountSalesCount(Map<String, dynamic> item) {
    return productDiscountSalesCount(_inventory(item));
  }

  double _discountSalesAmount(Map<String, dynamic> item) {
    return productDiscountSalesAmount(_inventory(item));
  }

  List<Map<String, dynamic>> _productBatchRows(Map<String, dynamic> item) {
    return buildProductBatchRows(
      product: item,
      inventoryBatches: _batchDocs,
    );
  }

  Future<void> _editDiscountDialog(
      Map<String, dynamic> item, int current) async {
    final controller = TextEditingController(
      text: current > 0 ? current.toString() : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Процент скидки'),
        content: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Скидка, %',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim()) ?? -1;
              if (parsed < 0 || parsed > 100) {
                Navigator.pop(context, -1);
                return;
              }
              Navigator.pop(context, parsed);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null || value < 0 || value > 100) return;
    await _setDiscount(item, value);
  }

  Future<void> _setDiscount(Map<String, dynamic> item, int percent) async {
    final entry = _inventory(item);
    final id = entry.id.trim();
    if (id.isEmpty) return;
    try {
      await _firestore.collection('nomenklatura').doc(id).set(
          buildProductDiscountSetPayload(entry, percent),
          SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        item.addAll(buildProductDiscountLocalPatch(entry, percent));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скидка $percent% сохранена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения скидки: $e')),
      );
    }
  }

  Future<void> _clearDiscount(Map<String, dynamic> item) async {
    final entry = _inventory(item);
    final id = entry.id.trim();
    if (id.isEmpty) return;
    try {
      await _firestore
          .collection('nomenklatura')
          .doc(id)
          .set(buildProductDiscountClearPayload(), SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        final patch = buildProductDiscountClearLocalPatch();
        patch.forEach((key, value) {
          if (value == null) {
            item.remove(key);
          } else {
            item[key] = value;
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скидка снята')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка снятия скидки: $e')),
      );
    }
  }

  Widget _discountControlPanel() {
    final source = (_filtered.isEmpty ? _items : _filtered).map(_inventory);
    final summary = buildProductDiscountSummary(source);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tab == 'discount'
                ? 'Управление скидками: товары со скидкой + эффективность'
                : 'ABC + оборачиваемость по товарам',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                  'ABC',
                  'A:${summary.abcA}  B:${summary.abcB}  C:${summary.abcC}',
                  const Color(0xFFF3E8FF),
                  const Color(0xFF7C3AED)),
              _summaryChip(
                  'Со скидкой',
                  '${summary.discountedCount}',
                  FlutterFlowTheme.of(context).accent1,
                  const Color(0xFF1D4ED8)),
              _summaryChip(
                  'Сред. оборач.',
                  summary.avgTurnover > 0
                      ? '${summary.avgTurnover.toStringAsFixed(0)} дн'
                      : '—',
                  FlutterFlowTheme.of(context).accent1,
                  FlutterFlowTheme.of(context).primary),
              _summaryChip(
                  'Риск 90+',
                  '${summary.riskyCount}',
                  FlutterFlowTheme.of(context).error.withValues(alpha: 0.14),
                  FlutterFlowTheme.of(context).error),
              _summaryChip(
                  'Нет продаж',
                  '${summary.noSalesCount}',
                  FlutterFlowTheme.of(context).warning.withValues(alpha: 0.14),
                  FlutterFlowTheme.of(context).warning),
              _summaryChip(
                  'Сумма со скидкой',
                  _money(summary.discountedSalesAmount),
                  FlutterFlowTheme.of(context).success.withValues(alpha: 0.14),
                  const Color(0xFF15803D)),
              _summaryChip(
                  'Стоимость 30+',
                  _money(summary.totalStaleCost),
                  FlutterFlowTheme.of(context).success.withValues(alpha: 0.14),
                  const Color(0xFF15803D)),
              _summaryChip(
                  'FIFO',
                  '${_items.where((i) => resolveInventoryCostingMethod(productData: i) == InventoryCostingMethod.fifo).length}',
                  FlutterFlowTheme.of(context).accent1,
                  FlutterFlowTheme.of(context).primary),
              _summaryChip(
                  'Средневзвеш.',
                  '${_items.where((i) => resolveInventoryCostingMethod(productData: i) == InventoryCostingMethod.weightedAverage).length}',
                  FlutterFlowTheme.of(context).warning.withValues(alpha: 0.14),
                  FlutterFlowTheme.of(context).warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color bg, Color fg) {
    final labelColor = _textOn(bg, darkAlpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: labelColor, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('analytics.portfolio')) {
      return PermissionsHelper.noAccess();
    }
    final screenHeight = widget.height ?? MediaQuery.sizeOf(context).height;
    final listHeight = math.max(320.0, screenHeight * 0.55);
    final mainPanel = _buildMainPanel(context, listHeight);

    return ResponsiveFrame(
      backgroundColor: _pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return mainPanel;
        },
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        height: 90,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: _mutedText,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: valueColor ??
                          FlutterFlowTheme.of(context).primaryText,
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

  Widget _tabButton(String label, String value, IconData icon) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = value);
          _applyFilters();
        },
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFC8A06A)
                : (_isDarkTheme
                    ? Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.04),
                        FlutterFlowTheme.of(context).secondaryBackground,
                      )
                    : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFFC8A06A).withValues(alpha: 0.7)
                  : _panelBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? Colors.white
                    : FlutterFlowTheme.of(context).primaryText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            )),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _panelSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _panelBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: _panelSurface,
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: _mutedText,
              items: items
                  .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          i,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  List<String> _distinctValues(String field,
      {List<Map<String, dynamic>>? source, String? include}) {
    final data = source ?? _items;
    final values = <String>{};
    for (final i in data) {
      final v = (i[field] ?? '').toString().trim();
      if (v.isNotEmpty) values.add(v);
    }
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final result = ['all', ...sorted];
    final includeValue = include ?? '';
    if (includeValue.isNotEmpty &&
        includeValue != 'all' &&
        !result.contains(includeValue)) {
      result.add(includeValue);
    }
    return result;
  }

  Widget _productCard(Map<String, dynamic> i) {
    final entry = _inventory(i);
    final name = entry.name.isEmpty ? 'Без названия' : entry.name;
    final category = entry.category.isEmpty ? 'Без категории' : entry.category;
    final abc = entry.abc;
    final lowStock = entry.stock <= entry.minStock;

    final sales = entry.salesCount;
    final revenue = entry.revenue;
    final profit = entry.profit;
    final margin = revenue > 0 ? (profit / revenue) * 100.0 : 0.0;
    final stock = entry.stock;
    final purchasePrice =
        entry.purchasePrice > 0 ? entry.purchasePrice : entry.costPrice;
    final salePrice = entry.salePrice;
    final markupCoeff =
        purchasePrice > 0 && salePrice > 0 ? salePrice / purchasePrice : 0;
    final agingDays = _stockAgingDays(i);
    final agingColor = _agingZoneColor(agingDays);
    final staleCost = productStaleCost(entry);
    final turnoverLabel = _turnoverLabel(i);
    final turnoverColor = _turnoverColor(i);
    final currentDiscount = entry.discountPercent.toInt();
    final recommendedDiscount = _recommendedDiscountPercent(i);
    final official = entry.isOfficial ? 'Оф' : 'Неоф';
    final costingMethod = inventoryCostingMethodLabel(
      resolveInventoryCostingMethod(productData: i),
    );
    final batchRows = _productBatchRows(i);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _tab == 'discount'
              ? agingColor.withValues(alpha: 0.35)
              : _panelBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                name,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _chip(category),
              const SizedBox(width: 6),
              _chip(abc),
              const SizedBox(width: 6),
              _chip(official,
                  color: official == 'Оф'
                      ? FlutterFlowTheme.of(context).accent1
                      : FlutterFlowTheme.of(context).primaryBackground),
              const SizedBox(width: 6),
              _chip(costingMethod,
                  color: FlutterFlowTheme.of(context)
                      .secondaryBackground
                      .withValues(alpha: 0.95)),
              const SizedBox(width: 6),
              _chip(_agingZoneLabel(agingDays),
                  color: agingColor.withValues(alpha: 0.12)),
              if (lowStock) ...[
                const SizedBox(width: 6),
                _chip('Низкий остаток',
                    color: FlutterFlowTheme.of(context)
                        .error
                        .withValues(alpha: 0.14)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Продано', '${sales.toStringAsFixed(0)} шт',
                  const Color(0xFF1F2A37)),
              _metric('Выручка', _money(revenue),
                  FlutterFlowTheme.of(context).primary),
              _metric('Прибыль', _money(profit),
                  FlutterFlowTheme.of(context).success),
              _metric('Маржа', '${margin.toStringAsFixed(0)}%',
                  const Color(0xFF8B5CF6)),
              _metric(
                  'Коэф. наценки',
                  markupCoeff > 0 ? markupCoeff.toStringAsFixed(0) : '—',
                  const Color(0xFF7C3AED)),
              _metric('Остаток', '${stock.toStringAsFixed(0)} шт',
                  lowStock ? Colors.red : Colors.green),
              _metric(
                  'Залежалось',
                  '${agingDays.toStringAsFixed(0)} дн / ${_money(staleCost)}',
                  agingColor),
              _metric(
                  _tab == 'discount' || _tab == 'abc'
                      ? 'Оборачиваемость'
                      : 'Закупить',
                  _tab == 'discount' || _tab == 'abc'
                      ? turnoverLabel
                      : (_needsPurchaseRequest(i) ? 'Да' : '—'),
                  _tab == 'discount' || _tab == 'abc'
                      ? turnoverColor
                      : (_needsPurchaseRequest(i)
                          ? FlutterFlowTheme.of(context).error
                          : const Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Активные партии',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (batchRows.isEmpty)
            Text(
              'Активных партий нет',
              style: TextStyle(fontSize: 12, color: _mutedText),
            )
          else
            Column(
              children: batchRows
                  .map(
                    (row) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _panelBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              (row['warehouse_name'] ?? '-').toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _chip(
                              (row['ledger_scope_label'] ?? '-').toString(),
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${((row['qty_remaining'] as num?) ?? 0).toStringAsFixed(0)} шт',
                              style: TextStyle(
                                fontSize: 12,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _money(
                                  ((row['unit_cost'] as num?) ?? 0).toDouble()),
                              style: TextStyle(
                                fontSize: 12,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _money(((row['total_value'] as num?) ?? 0)
                                  .toDouble()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (_tab == 'discount' || _tab == 'abc') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _chip(
                    currentDiscount > 0
                        ? 'Текущая скидка: $currentDiscount%'
                        : 'Текущая скидка: —',
                    color: FlutterFlowTheme.of(context).accent1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _chip(
                    recommendedDiscount > 0
                        ? 'Рекомендовано: $recommendedDiscount%'
                        : 'Рекомендовано: без скидки',
                    color: recommendedDiscount > 0
                        ? FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.14)
                        : FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.14),
                  ),
                ),
              ],
            ),
            if (_tab == 'discount') const SizedBox(height: 8),
            if (_tab == 'discount')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: recommendedDiscount > 0
                        ? () => _setDiscount(i, recommendedDiscount)
                        : null,
                    child: const Text('Применить рекоменд.'),
                  ),
                  OutlinedButton(
                    onPressed: () => _editDiscountDialog(
                        i,
                        currentDiscount > 0
                            ? currentDiscount
                            : recommendedDiscount),
                    child: const Text('Редактировать %'),
                  ),
                  TextButton(
                    onPressed:
                        currentDiscount > 0 ? () => _clearDiscount(i) : null,
                    child: const Text('Снять скидку'),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              _discountReason(i),
              style: TextStyle(
                fontSize: 12,
                color: _mutedText,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Эффективность: ${_discountDays(i)} дн',
                    color: FlutterFlowTheme.of(context).primaryBackground),
                _chip('Продаж со скидкой: ${_discountSalesCount(i)}',
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.14)),
                _chip('Сумма со скидкой: ${_money(_discountSalesAmount(i))}',
                    color: const Color(0xFFEFF6FF)),
                _chip(
                    'Категория: ${(entry.categoryBeforeDiscount.isNotEmpty ? entry.categoryBeforeDiscount : (entry.categoryAtDiscount.isNotEmpty ? entry.categoryAtDiscount : (entry.category.isNotEmpty ? entry.category : '—')))} → ${(entry.category.isEmpty ? '—' : entry.category)}',
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: _mutedText,
              )),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {Color? color}) {
    final bg = color ?? FlutterFlowTheme.of(context).primaryBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textOn(bg),
        ),
      ),
    );
  }
}

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
