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
import '/utils/ledger_scope.dart';
import '/utils/report_export_service.dart';
import '/utils/service_accounting_support.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServiceReportsWidget extends StatefulWidget {
  const ServiceReportsWidget({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<ServiceReportsWidget> createState() => _ServiceReportsWidgetState();
}

class _ServiceReportsWidgetState extends State<ServiceReportsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _executions = [];
  List<Map<String, dynamic>> _businessEvents = [];
  LedgerScope _scope = LedgerScope.both;
  String _breakdown = 'service';
  String _currencyCode = 'KZT';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final results = await Future.wait([
        _firestore
            .collection('service_executions')
            .where('idCompany', isEqualTo: companyId)
            .limit(2000)
            .getCached(),
        _firestore
            .collection('business_events')
            .where('idCompany', isEqualTo: companyId)
            .limit(4000)
            .getCached(),
      ]);
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();
      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        final execSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
        final eventSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
        _executions = execSnap.docs.map((doc) {
          final raw = Map<String, dynamic>.from(doc.data() as Map);
          return <String, dynamic>{
            'id': doc.id,
            ...raw,
          };
        }).toList();
        _businessEvents = eventSnap.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ServiceReportRow> get _rows => _businessEvents.any(
        (event) =>
            (event['event_type'] ?? '').toString().toUpperCase() ==
            'SERVICE_PERFORMED',
      )
          ? buildServiceReportRowsFromEvents(
              eventDocs: _businessEvents,
              breakdown: _breakdown,
              ledgerScope: _scope == LedgerScope.both ? null : _scope,
            )
          : buildServiceReportRows(
              executionDocs: _executions,
              breakdown: _breakdown,
              ledgerScope: _scope == LedgerScope.both ? null : _scope,
            );

  double get _revenue => _rows.fold<double>(0, (t, r) => t + r.revenue);
  double get _cost => _rows.fold<double>(0, (t, r) => t + r.cost);
  double get _margin => _rows.fold<double>(0, (t, r) => t + r.margin);
  double get _qty => _rows.fold<double>(0, (t, r) => t + r.quantity);

  String _money(double value) =>
      formatMoneyWithCurrency(value, currencyCode: _currencyCode);

  Future<void> _exportExcel() {
    final rows = buildServiceReportExportRows(
      title: 'Отчет по услугам',
      bodyRows: <List<String>>[
        <String>[
          'Разрез',
          'Количество',
          'Выручка',
          'Себестоимость',
          'Маржа',
          'Маржа %'
        ],
        ..._rows.map(
          (row) => <String>[
            row.label,
            row.quantity.toStringAsFixed(2),
            row.revenue.toStringAsFixed(2),
            row.cost.toStringAsFixed(2),
            row.margin.toStringAsFixed(2),
            row.marginPercent.toStringAsFixed(2),
          ],
        ),
      ],
    );
    return exportReportExcel(
      filename: 'service-report.xls',
      title: 'Отчет по услугам',
      rows: rows,
    );
  }

  Future<void> _exportPdf() {
    final rows = buildServiceReportExportRows(
      title: 'Отчет по услугам',
      bodyRows: <List<String>>[
        <String>[
          'Разрез',
          'Количество',
          'Выручка',
          'Себестоимость',
          'Маржа',
          'Маржа %'
        ],
        ..._rows.map(
          (row) => <String>[
            row.label,
            row.quantity.toStringAsFixed(2),
            row.revenue.toStringAsFixed(2),
            row.cost.toStringAsFixed(2),
            row.margin.toStringAsFixed(2),
            row.marginPercent.toStringAsFixed(2),
          ],
        ),
      ],
    );
    return exportReportPdf(
      filename: 'service-report.pdf',
      title: 'Отчет по услугам',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Отчет по услугам',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportExcel,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _statCard('Выручка', _money(_revenue))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Себестоимость', _money(_cost))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Маржа', _money(_margin))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Кол-во', _qty.toStringAsFixed(0))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<LedgerScope>(
                    initialValue: _scope,
                    decoration: const InputDecoration(
                      labelText: 'Контур',
                      border: OutlineInputBorder(),
                    ),
                    items: LedgerScope.values
                        .map((scope) => DropdownMenuItem(
                              value: scope,
                              child: Text(scope.storageValue),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _scope = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _breakdown,
                    decoration: const InputDecoration(
                      labelText: 'Разрез',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'service', child: Text('По услугам')),
                      DropdownMenuItem(
                          value: 'category', child: Text('По категориям')),
                      DropdownMenuItem(
                          value: 'period', child: Text('По периодам')),
                      DropdownMenuItem(
                          value: 'ledger', child: Text('По контурам')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _breakdown = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(row.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            Expanded(
                                child: Text(row.quantity.toStringAsFixed(2))),
                            Expanded(child: Text(_money(row.revenue))),
                            Expanded(child: Text(_money(row.cost))),
                            Expanded(child: Text(_money(row.margin))),
                            Expanded(
                                child: Text(
                                    '${row.marginPercent.toStringAsFixed(1)}%')),
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

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
