// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/sale_item_cogs_report_support.dart';

class SalesCogsBreakdownWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final bool embedded;

  const SalesCogsBreakdownWidget({
    super.key,
    this.width,
    this.height,
    this.embedded = false,
  });

  @override
  State<SalesCogsBreakdownWidget> createState() =>
      _SalesCogsBreakdownWidgetState();
}

class _SalesCogsBreakdownWidgetState extends State<SalesCogsBreakdownWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<SaleItemCogsReportRow> _rows = [];
  List<SaleItemCogsReportRow> _filtered = [];
  String _methodFilter = 'all';
  String _currencyCode = 'KZT';
  bool _loading = false;

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
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: currentUserUid,
      );
      if (companyId.trim().isEmpty) {
        setState(() {
          _rows = [];
          _filtered = [];
        });
        return;
      }

      final cogsEntrySnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: companyId)
          .get();
      final legacySnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: companyId)
          .get();
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();
      final items = resolveSalesCogsItems(
        cogsEntries: cogsEntrySnap.docs.map(
          (doc) => {'id': doc.id, ...doc.data()},
        ),
        legacyCogsItems: legacySnap.docs.map(
          (doc) => {'id': doc.id, ...doc.data()},
        ),
      );
      final rows = buildSaleItemCogsReportRows(cogsItems: items);
      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _rows = rows;
        _filtered = rows;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading sales COGS breakdown: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _rows.where((row) {
      if (_methodFilter != 'all' && row.costingMethod != _methodFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.productName.toLowerCase().contains(query) ||
          row.saleId.toLowerCase().contains(query) ||
          row.saleItemId.toLowerCase().contains(query) ||
          row.warehouseName.toLowerCase().contains(query);
    }).toList();

    setState(() => _filtered = filtered);
  }

  String _money(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded)
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
                  child: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COGS breakdown',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Себестоимость продаж по партиям и методам списания',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Поиск по продаже / товару / складу',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _methodFilter,
                  decoration: const InputDecoration(
                    labelText: 'Метод списания',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все')),
                    DropdownMenuItem(value: 'FIFO', child: Text('FIFO')),
                    DropdownMenuItem(
                      value: 'WEIGHTED_AVERAGE',
                      child: Text('Средневзвешенная'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _methodFilter = value);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final row = _filtered[index];
                    final method = inventoryCostingMethodLabel(
                      inventoryCostingMethodFromValue(row.costingMethod),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.productName.isEmpty
                                      ? 'Без названия'
                                      : row.productName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).accent1,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(method),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sale: ${row.saleId} | Item: ${row.saleItemId} | Склад: ${row.warehouseName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Text('Qty: ${row.quantity.toStringAsFixed(2)}'),
                              Text('Unit COGS: ${_money(row.unitCostApplied)}'),
                              Text('Total COGS: ${_money(row.totalCost)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (row.batchBreakdown.isNotEmpty)
                            ...row.batchBreakdown.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: content,
    );
  }
}
