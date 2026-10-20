// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/cogs_register_support.dart';
import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesControlsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesControlsWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesControlsWidget> createState() => _SalesControlsWidgetState();
}

class _SalesControlsWidgetState extends State<SalesControlsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  List<_DiscountRow> _items = [];
  String _zoneFilter = 'all';
  final Map<String, int> _recommendedOverrides = <String, int>{};
  final Set<String> _expandedRows = <String>{};
  Map<String, Map<String, dynamic>> _warehousesById =
      <String, Map<String, dynamic>>{};
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

  Color get _softText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.56)
      : const Color(0xFF6B7280);

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
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _items = []);
        return;
      }
      final companyId = _effectiveCompanyId(user);
      final now = DateTime.now();
      final ninetyDaysAgo = now.subtract(const Duration(days: 90));

      final results = await Future.wait<dynamic>([
        _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('warehouses')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('sales_items')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('cogs_register')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('sale_item_cogs')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('inventory_batches')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
      ]);
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();
      final productsSnap = results[0] as QuerySnapshot;
      final warehousesSnap = results[1] as QuerySnapshot;
      final salesItemsSnap = results[2] as QuerySnapshot;
      final cogsSnap = results[3] as QuerySnapshot;
      final legacyCogsSnap = results[4] as QuerySnapshot;
      final inventoryBatchesSnap = results[5] as QuerySnapshot;
      final warehousesById = <String, Map<String, dynamic>>{};
      for (final doc in warehousesSnap.docs) {
        final data = _docMap(doc.data());
        warehousesById[doc.id] = <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }
      _warehousesById = warehousesById;
      final batchesByProductId = <String, List<Map<String, dynamic>>>{};
      for (final doc in inventoryBatchesSnap.docs) {
        final data = _docMap(doc.data());
        final productId =
            (data['product_id'] ?? data['productId'] ?? '').toString().trim();
        if (productId.isEmpty) continue;
        final qty = _num(data['qty_remaining'] ?? data['qtyRemaining']);
        final isActive =
            data['is_active'] != false && data['isActive'] != false;
        final status = (data['status'] ?? '').toString().toUpperCase();
        if (!isActive || qty <= 0 || status == 'DEPLETED') continue;
        batchesByProductId.putIfAbsent(
            productId, () => <Map<String, dynamic>>[])
          ..add(<String, dynamic>{'id': doc.id, ...data});
      }

      final cogsByItemKey = buildCogsBySalesItemKey(
        cogsEntries: cogsSnap.docs.map((d) {
          final data = _docMap(d.data());
          return {'id': d.id, ...data};
        }).toList(),
        legacyCogsItems: legacyCogsSnap.docs.map((d) {
          final data = _docMap(d.data());
          return {'id': d.id, ...data};
        }).toList(),
      );

      final salesAgg = <String, _SalesAgg>{};
      for (final doc in salesItemsSnap.docs) {
        final data = _docMap(doc.data());
        final productId = (data['product_id'] ?? '').toString().trim();
        if (productId.isEmpty) continue;

        final row = salesAgg.putIfAbsent(productId, _SalesAgg.new);
        final qty = _num(data['qty']);
        final amount = _num(data['amount']);
        final saleItemId = doc.id;
        final saleId = (data['sale_id'] ?? '').toString().trim();
        final productName = (data['product_name'] ?? data['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final cogs = cogsByItemKey['sale_item:$saleItemId'] ??
            (saleId.isNotEmpty && productId.isNotEmpty
                ? cogsByItemKey['sale_product:$saleId:$productId']
                : null) ??
            (saleId.isNotEmpty && productName.isNotEmpty
                ? cogsByItemKey['sale_name:$saleId:$productName']
                : null) ??
            _num(data['cogs_amount'] ?? data['cost']);
        final createdAt = _toDate(data['created_at']);

        row.revenue += amount;
        row.cogs += cogs;
        if (createdAt != null) {
          if (row.lastSaleAt == null || createdAt.isAfter(row.lastSaleAt!)) {
            row.lastSaleAt = createdAt;
          }
          if (!createdAt.isBefore(ninetyDaysAgo)) {
            row.qty90 += qty;
          }
        }
      }

      final rows = <_DiscountRow>[];
      for (final doc in productsSnap.docs) {
        final data = _docMap(doc.data());
        final id = doc.id;

        final stock = _num(data['stock']);
        final purchase = _num(data['purchase_price'] ?? data['cost_price']);
        final sale = _num(data['sale_price'] ?? data['price']);

        final agg = salesAgg[id] ?? _SalesAgg();
        final productBatches =
            batchesByProductId[id] ?? const <Map<String, dynamic>>[];
        final primaryBatch = _primaryWarehouseBatch(productBatches);
        final warehouseId = (primaryBatch?['warehouse_id'] ??
                primaryBatch?['warehouseId'] ??
                data['warehouse_id'] ??
                data['warehouseId'] ??
                '')
            .toString()
            .trim();
        final warehouseDoc =
            warehousesById[warehouseId] ?? const <String, dynamic>{};
        final warehouseName = _resolveWarehouseName(
          batch: primaryBatch,
          warehouseDoc: warehouseDoc,
          productData: data,
        );
        final monthlySales = agg.qty90 <= 0 ? 0.0 : agg.qty90 / 3.0;
        final turnoverDays = stock <= 0
            ? 0
            : (monthlySales <= 0 ? 999 : ((stock / monthlySales) * 30).round());

        final fallbackDate =
            _toDate(data['updated_at']) ?? _toDate(data['created_at']);
        final basisDate = agg.lastSaleAt ?? fallbackDate;
        final agingDays = basisDate == null
            ? 0
            : now.difference(basisDate).inDays.clamp(0, 9999);

        rows.add(
          _DiscountRow(
            id: id,
            name: (data['name'] ?? 'Без названия').toString(),
            category: (data['category'] ?? data['type'] ?? 'Без категории')
                .toString(),
            warehouseId: warehouseId,
            warehouse: warehouseName,
            stock: stock,
            purchasePrice: purchase,
            salePrice: sale,
            markupCoeff: _markupCoeff(data, purchase, sale),
            turnoverDays: turnoverDays,
            agingDays: agingDays,
            staleCost: stock * purchase,
            revenue: agg.revenue,
            cogs: agg.cogs,
            grossProfit: agg.revenue - agg.cogs,
            margin: agg.revenue <= 0
                ? 0
                : ((agg.revenue - agg.cogs) / agg.revenue) * 100,
            currentDiscount: _num(data['discount_percent']).round(),
            official: _isOfficialProduct(
              productData: data,
              warehouseDoc: warehouseDoc,
              productBatches: productBatches,
            ),
          ),
        );
      }

      _applyAbc(rows);

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _items = rows;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading discount controls: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyAbc(List<_DiscountRow> rows) {
    final sorted = List<_DiscountRow>.from(rows)
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final totalRevenue = sorted.fold<double>(
        0, (total, item) => total + (item.revenue > 0 ? item.revenue : 0));

    if (totalRevenue <= 0) {
      for (final item in sorted) {
        item.abc = 'C';
      }
      return;
    }

    double cumulative = 0;
    for (final item in sorted) {
      cumulative += item.revenue > 0 ? item.revenue : 0;
      final share = cumulative / totalRevenue;
      if (share <= 0.80) {
        item.abc = 'A';
      } else if (share <= 0.95) {
        item.abc = 'B';
      } else {
        item.abc = 'C';
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {});
  }

  String _effectiveCompanyId(User user) {
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    final companyIds = (currentUserDocument?.companyIds ?? const <String>[])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (raw == '__all__') {
      if (active.isNotEmpty) return active;
      if (companyIds.isNotEmpty) return companyIds.first;
      return user.uid;
    }
    if (raw.isNotEmpty) return raw;
    if (active.isNotEmpty) return active;
    if (companyIds.isNotEmpty) return companyIds.first;
    return user.uid;
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isOfficialProduct({
    required Map<String, dynamic> productData,
    required Map<String, dynamic> warehouseDoc,
    required List<Map<String, dynamic>> productBatches,
  }) {
    final batchLabels = productBatches
        .map((batch) => _resolveWarehouseName(
              batch: batch,
              warehouseDoc: warehouseDocForBatch(batch),
              productData: productData,
            ))
        .where((value) => value.trim().isNotEmpty)
        .toList();
    if (batchLabels.isNotEmpty) {
      final hasUnofficial = batchLabels.any(_isUnofficialWarehouseLabel);
      final hasOfficial = batchLabels.any(_isOfficialWarehouseLabel);
      if (hasUnofficial && !hasOfficial) return false;
      if (hasOfficial && !hasUnofficial) return true;
    }

    final warehouseType = warehouseTypeFromData(
      warehouseDoc.isNotEmpty ? warehouseDoc : productData,
    );
    final accountingScope = ledgerScopeFromLegacyValue(
      (productData['accounting_mode'] ?? productData['typeUchet']).toString(),
    );
    if (accountingScope == LedgerScope.management) {
      return false;
    }
    return warehouseType.isOfficial;
  }

  Map<String, dynamic> warehouseDocForBatch(Map<String, dynamic> batch) {
    final warehouseId =
        (batch['warehouse_id'] ?? batch['warehouseId'] ?? '').toString().trim();
    return warehouseId.isEmpty
        ? const <String, dynamic>{}
        : _warehousesById[warehouseId] ?? const <String, dynamic>{};
  }

  Map<String, dynamic>? _primaryWarehouseBatch(
    List<Map<String, dynamic>> batches,
  ) {
    if (batches.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(batches)
      ..sort((a, b) => _num(b['qty_remaining'] ?? b['qtyRemaining'])
          .compareTo(_num(a['qty_remaining'] ?? a['qtyRemaining'])));
    return sorted.first;
  }

  String _resolveWarehouseName({
    required Map<String, dynamic>? batch,
    required Map<String, dynamic> warehouseDoc,
    required Map<String, dynamic> productData,
  }) {
    final batchName = (batch?['warehouse_name'] ??
            batch?['warehouseName'] ??
            batch?['warehouse'] ??
            '')
        .toString()
        .trim();
    if (batchName.isNotEmpty) return batchName;
    final warehouseName = (warehouseDoc['name'] ?? '').toString().trim();
    if (warehouseName.isNotEmpty) return warehouseName;
    return (productData['warehouse_name'] ??
            productData['warehouseName'] ??
            productData['warehouse'] ??
            'Не указан')
        .toString();
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

  double _markupCoeff(Map<String, dynamic> data, double purchase, double sale) {
    final explicit = _num(data['markup_ratio'] ?? data['markup_coeff']);
    if (explicit > 0) return explicit;
    if (purchase <= 0 || sale <= 0) return 0;
    return sale / purchase;
  }

  String _zoneByDays(int days) {
    if (days > 180) return 'red180';
    if (days > 90) return 'red';
    if (days >= 30) return 'yellow';
    return 'green';
  }

  String _zoneLabel(int days) {
    if (days > 180) return '>180 дн';
    if (days > 90) return '>90 дн';
    if (days >= 30) return '30-90 дн';
    return '<30 дн';
  }

  Color _zoneColor(int days) {
    if (days > 180) return const Color(0xFF991B1B);
    if (days > 90) return FlutterFlowTheme.of(context).error;
    if (days >= 30) return FlutterFlowTheme.of(context).warning;
    return FlutterFlowTheme.of(context).success;
  }

  int _recommendedDiscount(_DiscountRow row) {
    int percent = 0;
    if (row.agingDays > 180 || row.turnoverDays >= 120) {
      percent = 25;
    } else if (row.agingDays > 90 || row.turnoverDays >= 90) {
      percent = 15;
    } else if (row.agingDays >= 30 || row.turnoverDays >= 45) {
      percent = 10;
    }
    if (row.abc == 'A') percent = (percent - 5).clamp(0, 20);
    if (row.abc == 'B') percent = (percent - 2).clamp(0, 22);
    final override = _recommendedOverrides[row.id];
    if (override != null) return override.clamp(0, 90);
    return percent;
  }

  String _discountReason(_DiscountRow row, int percent) {
    final turnoverText =
        row.turnoverDays >= 999 ? 'нет продаж' : '${row.turnoverDays} дн';
    return 'Рекомендовано автоматически: $percent%. ABC:${row.abc}, '
        'залежалость ${row.agingDays} дн, оборачиваемость $turnoverText.';
  }

  Future<void> _applyRecommendedDiscount(_DiscountRow row,
      {int? forcePercent}) async {
    final percent = forcePercent ?? _recommendedDiscount(row);
    if (percent <= 0) return;
    try {
      await _firestore.collection('nomenklatura').doc(row.id).set({
        'discount_percent': percent,
        'discount_reason': _discountReason(row, percent),
        'discount_updated_at': FieldValue.serverTimestamp(),
        'discount_started_at': FieldValue.serverTimestamp(),
        'category_before_discount': row.category,
        'category_at_discount': row.category,
        if (row.warehouseId.isNotEmpty) 'warehouse_id': row.warehouseId,
        'warehouse_name': row.warehouse,
        'warehouse': row.warehouse,
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => row.currentDiscount = percent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скидка $percent% сохранена для "${row.name}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения скидки: $e')),
      );
    }
  }

  Future<void> _clearDiscount(_DiscountRow row) async {
    try {
      await _firestore.collection('nomenklatura').doc(row.id).set({
        'discount_percent': FieldValue.delete(),
        'discount_reason': FieldValue.delete(),
        'discount_updated_at': FieldValue.serverTimestamp(),
        'discount_started_at': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => row.currentDiscount = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скидка снята для "${row.name}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка снятия скидки: $e')),
      );
    }
  }

  Future<void> _editRecommendedPercent(_DiscountRow row) async {
    final initial = _recommendedDiscount(row);
    final controller = TextEditingController(
      text: initial > 0 ? initial.toString() : '',
    );
    final next = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Рекоменд. скидка для "${row.name}"'),
        content: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Процент, %',
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
              if (parsed < 0 || parsed > 90) {
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
    if (next == null || next < 0 || next > 90) return;
    if (!mounted) return;
    setState(() {
      _recommendedOverrides[row.id] = next;
    });
  }

  String _money(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  List<_DiscountRow> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      if (_zoneFilter != 'all' && _zoneByDays(item.agingDays) != _zoneFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.warehouse.toLowerCase().contains(q) ||
          item.abc.toLowerCase() == q;
    }).toList();
  }

  List<_DiscountRow> _rowsByOfficial(bool official) {
    final rows = _visible.where((e) => e.official == official).toList()
      ..sort((a, b) {
        final zone = _zoneWeight(_zoneByDays(b.agingDays))
            .compareTo(_zoneWeight(_zoneByDays(a.agingDays)));
        if (zone != 0) return zone;
        return b.staleCost.compareTo(a.staleCost);
      });
    return rows;
  }

  int _zoneWeight(String zone) {
    switch (zone) {
      case 'red180':
        return 4;
      case 'red':
        return 3;
      case 'yellow':
        return 2;
      default:
        return 1;
    }
  }

  int get _total => _items.length;
  double get _totalCogs => _items.fold(0, (total, item) => total + item.cogs);
  double get _totalGrossProfit =>
      _items.fold(0, (total, item) => total + item.grossProfit);
  int get _officialCount => _items.where((e) => e.official).length;
  int get _unofficialCount => _items.where((e) => !e.official).length;

  double _staleCostByZone(String zone) {
    return _items.fold<double>(0, (total, item) {
      if (_zoneByDays(item.agingDays) != zone) return total;
      return total + item.staleCost;
    });
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.controls')) {
      return PermissionsHelper.noAccess();
    }

    final officialRows = _rowsByOfficial(true);
    final unofficialRows = _rowsByOfficial(false);

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
                  child: const Icon(Icons.discount_outlined,
                      color: Color(0xFF9E7B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Управление скидками',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ABC, оборачиваемость и залежалые остатки по складам',
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _kpiCard('Всего товаров', '$_total', const Color(0xFF1F2A37)),
                const SizedBox(width: 10),
                _kpiCard(
                  'COGS',
                  _money(_totalCogs),
                  FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 10),
                _kpiCard(
                  'Валовая',
                  _money(_totalGrossProfit),
                  FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 10),
                _kpiCard('Официальные', '$_officialCount',
                    FlutterFlowTheme.of(context).primary),
                const SizedBox(width: 10),
                _kpiCard('Неофициальные', '$_unofficialCount',
                    const Color(0xFF6B7280)),
                const SizedBox(width: 10),
                _kpiCard('30-90 дн', _money(_staleCostByZone('yellow')),
                    FlutterFlowTheme.of(context).warning),
                const SizedBox(width: 10),
                _kpiCard(
                    '90+ дн',
                    _money(
                        _staleCostByZone('red') + _staleCostByZone('red180')),
                    FlutterFlowTheme.of(context).error),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                        Icon(Icons.search, color: _softText, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Поиск по товару или складу...',
                              hintStyle: TextStyle(color: _softText),
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
                const SizedBox(width: 10),
                SizedBox(
                  width: 220,
                  child: _zoneDropdown(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1000;
                      if (!isWide) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          children: [
                            _bucketSection(
                              title: 'Официальные товары',
                              subtitle: 'Белый контур учета',
                              rows: officialRows,
                              color: const Color(0xFF1D4ED8),
                            ),
                            const SizedBox(height: 12),
                            _bucketSection(
                              title: 'Неофициальные товары',
                              subtitle: 'Серый контур учета',
                              rows: unofficialRows,
                              color: const Color(0xFF4B5563),
                            ),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _bucketSection(
                                title: 'Официальные товары',
                                subtitle: 'Белый контур учета',
                                rows: officialRows,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _bucketSection(
                                title: 'Неофициальные товары',
                                subtitle: 'Серый контур учета',
                                rows: unofficialRows,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _zoneDropdown() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _zoneFilter,
          isExpanded: true,
          dropdownColor: _panelSurface,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          iconEnabledColor: _mutedText,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Все зоны')),
            DropdownMenuItem(value: 'green', child: Text('Зеленая: <30 дн')),
            DropdownMenuItem(value: 'yellow', child: Text('Желтая: 30-90 дн')),
            DropdownMenuItem(value: 'red', child: Text('Красная: >90 дн')),
            DropdownMenuItem(value: 'red180', child: Text('Критично: >180 дн')),
          ],
          onChanged: (v) {
            setState(() => _zoneFilter = v ?? 'all');
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return SizedBox(
      width: 180,
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panelSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _panelBorder),
        ),
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
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bucketSection({
    required String title,
    required String subtitle,
    required List<_DiscountRow> rows,
    required Color color,
  }) {
    final totalStale = rows.fold<double>(0, (total, e) => total + e.staleCost);
    final redCount =
        rows.where((e) => _zoneByDays(e.agingDays).startsWith('red')).length;

    return Container(
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                _smallChip('Позиций: ${rows.length}'),
                const SizedBox(width: 8),
                _smallChip('Красная зона: $redCount',
                    bg: FlutterFlowTheme.of(context)
                        .error
                        .withValues(alpha: 0.14),
                    fg: const Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                _smallChip('Стоимость остатков: ${_money(totalStale)}',
                    bg: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.14),
                    fg: const Color(0xFF166534)),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Данные не найдены',
                    style: TextStyle(color: _mutedText)),
              )
            else
              ...rows.map(_productCard),
          ],
        ),
      ),
    );
  }

  Widget _productCard(_DiscountRow row) {
    final zoneColor = _zoneColor(row.agingDays);
    final zoneLabel = _zoneLabel(row.agingDays);
    final turnoverText = row.turnoverDays >= 999
        ? 'нет продаж'
        : '${row.turnoverDays.toString()} дн';
    final discount = _recommendedDiscount(row);
    final expanded = _expandedRows.contains(row.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zoneColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedRows.remove(row.id);
                } else {
                  _expandedRows.add(row.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _smallChip('ABC ${row.abc}',
                      bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9)),
                  const SizedBox(width: 6),
                  _smallChip(zoneLabel,
                      bg: zoneColor.withValues(alpha: 0.12), fg: zoneColor),
                  const SizedBox(width: 6),
                  _smallChip(
                    discount > 0 ? 'Рек. скидка $discount%' : 'Скидка не нужна',
                    bg: discount > 0
                        ? FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.14)
                        : FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.14),
                    fg: discount > 0
                        ? const Color(0xFFB45309)
                        : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Склад: ${row.warehouse}',
              style: TextStyle(fontSize: 12, color: _mutedText)),
          if (expanded) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric(
                    'Коэф. наценки',
                    row.markupCoeff > 0
                        ? row.markupCoeff.toStringAsFixed(0)
                        : '—',
                    const Color(0xFF7C3AED)),
                _metric(
                    'Оборачиваемость',
                    turnoverText,
                    row.turnoverDays >= 90
                        ? FlutterFlowTheme.of(context).error
                        : (row.turnoverDays >= 30
                            ? FlutterFlowTheme.of(context).warning
                            : FlutterFlowTheme.of(context).success)),
                _metric('Остаток', '${row.stock.toStringAsFixed(0)} шт',
                    const Color(0xFF1F2A37)),
                _metric('Выручка', _money(row.revenue),
                    FlutterFlowTheme.of(context).primary),
                _metric('COGS', _money(row.cogs),
                    FlutterFlowTheme.of(context).warning),
                _metric('Валовая', _money(row.grossProfit),
                    FlutterFlowTheme.of(context).success),
                _metric('Маржа', '${row.margin.toStringAsFixed(1)}%',
                    const Color(0xFF0F766E)),
                _metric('Залежалость', '${row.agingDays} дн', zoneColor),
                _metric('Стоимость залежалого',
                    _money(row.agingDays >= 30 ? row.staleCost : 0), zoneColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _smallChip(
                  row.currentDiscount > 0
                      ? 'Текущая скидка: ${row.currentDiscount}%'
                      : 'Текущая скидка: —',
                  bg: FlutterFlowTheme.of(context).accent1,
                  fg: const Color(0xFF1D4ED8),
                ),
                if (discount > 0)
                  OutlinedButton.icon(
                    onPressed: () => _applyRecommendedDiscount(row),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text('Применить $discount%'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _editRecommendedPercent(row),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Редактировать %'),
                ),
                if (row.currentDiscount > 0)
                  OutlinedButton.icon(
                    onPressed: () => _clearDiscount(row),
                    icon: const Icon(Icons.close,
                        size: 16, color: Color(0xFFB91C1C)),
                    label: const Text(
                      'Снять',
                      style: TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: _mutedText,
              )),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _smallChip(String text, {Color? bg, Color? fg}) {
    final fill = bg ?? FlutterFlowTheme.of(context).primaryBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg ?? _textOn(fill),
        ),
      ),
    );
  }
}

class _SalesAgg {
  double qty90 = 0;
  double revenue = 0;
  double cogs = 0;
  DateTime? lastSaleAt;
}

class _DiscountRow {
  final String id;
  final String name;
  final String category;
  final String warehouseId;
  final String warehouse;
  final bool official;
  final double stock;
  final double purchasePrice;
  final double salePrice;
  final double markupCoeff;
  final int turnoverDays;
  final int agingDays;
  final double staleCost;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double margin;
  int currentDiscount;
  String abc = 'C';

  _DiscountRow({
    required this.id,
    required this.name,
    required this.category,
    required this.warehouseId,
    required this.warehouse,
    required this.official,
    required this.stock,
    required this.purchasePrice,
    required this.salePrice,
    required this.markupCoeff,
    required this.turnoverDays,
    required this.agingDays,
    required this.staleCost,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.margin,
    this.currentDiscount = 0,
  });
}
