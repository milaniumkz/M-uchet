// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/effective_company_support.dart';

class AnalyticsFinModelsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const AnalyticsFinModelsWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<AnalyticsFinModelsWidget> createState() =>
      _AnalyticsFinModelsWidgetState();
}

class _AnalyticsFinModelsWidgetState extends State<AnalyticsFinModelsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _models = [];
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
        setState(() => _models = []);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final snap = await _firestore
          .collection('fin_models')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();

      setState(() {
        _models = snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
      });
    } catch (e) {
      print('Error loading fin models: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime? _extractDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
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

  String _resolveMonthLabel(Map<String, dynamic> item) {
    final period = (item['period'] ?? '').toString().trim();
    if (period.isNotEmpty) return period;
    final dt = _extractDate(item['date']) ??
        _extractDate(item['created_at']) ??
        _extractDate(item['updated_at']);
    if (dt == null) return 'Без периода';
    return _monthLabel(dt);
  }

  List<_ModelMonthRow> get _monthlyRows {
    final map = <String, _ModelMonthRow>{};
    for (final model in _models) {
      final label = _resolveMonthLabel(model);
      final key = label.toLowerCase();
      map.putIfAbsent(
        key,
        () => _ModelMonthRow(monthLabel: label),
      );
      map[key]!.count += 1;
      final name = (model['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        map[key]!.examples.add(name);
      }
    }
    final rows = map.values.toList();
    rows.sort((a, b) => a.monthLabel.compareTo(b.monthLabel));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('analytics.models')) {
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
                  child: const Icon(Icons.calculate_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Финансовые модели',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Сценарии и расчеты развития',
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
                          'Модели по месяцам',
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
                                    'Модели не найдены',
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

  Widget _tableHeader() {
    return Row(
      children: const [
        _HeaderCell('Месяц', flex: 3),
        _HeaderCell('Кол-во моделей', flex: 2),
        _HeaderCell('Модели', flex: 3),
      ],
    );
  }

  Widget _tableRow(_ModelMonthRow row) {
    final examples = row.examples.take(2).join(', ');
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
          _Cell(row.count.toString(), flex: 2),
          _Cell(examples.isEmpty ? '-' : examples, flex: 3),
        ],
      ),
    );
  }
}

class _ModelMonthRow {
  final String monthLabel;
  int count = 0;
  final List<String> examples = [];

  _ModelMonthRow({required this.monthLabel});
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

  const _Cell(this.text, {required this.flex, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: FlutterFlowTheme.of(context).primaryText,
        ),
      ),
    );
  }
}
