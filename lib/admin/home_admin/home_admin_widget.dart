import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import '/utils/admin_company_support.dart';
import '/utils/app_money_format.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'home_admin_model.dart';

class HomeAdminWidget extends StatefulWidget {
  const HomeAdminWidget({super.key});

  static String routeName = 'homeAdmin';
  static String routePath = '/homeAdmin';

  @override
  State<HomeAdminWidget> createState() => _HomeAdminWidgetState();
}

class _HomeAdminWidgetState extends State<HomeAdminWidget> {
  late HomeAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<Map<String, int>> _loadCounts() async {
    final firestore = FirebaseFirestore.instance;
    final companiesSnap = await firestore.collection('companies').get();
    final profilesSnap = await firestore.collection('company_profile').get();
    final usersSnap = await firestore.collection('users').get();
    final tranzSnap = await firestore.collection('tranzaction').get();
    final companyIds = <String>{
      for (final doc in companiesSnap.docs)
        if (isValidAdminCompanyId(doc.id)) doc.id.trim(),
      for (final doc in profilesSnap.docs)
        if (companyAdminIdFromData(doc.id, doc.data()).isNotEmpty)
          companyAdminIdFromData(doc.id, doc.data()),
    };
    return {
      'companies': companyIds.length,
      'users': usersSnap.size,
      'transactions': tranzSnap.size,
    };
  }

  String _formatCount(int value) {
    return formatNumber(
      value,
      formatType: FormatType.decimal,
      decimalType: DecimalType.automatic,
    );
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Widget _summaryTile(String title, int value, IconData icon, Color color) {
    const tileBg = Color(0xFF0F172A);
    const tileBorder = Color(0xFF334155);
    const tileTextColor = Color(0xFFF8FAFC);
    const tileMutedTextColor = Color(0xFFCBD5E1);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      ),
                      color: tileMutedTextColor,
                      letterSpacing: 0.0,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCount(value),
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.interTight(
                        fontWeight:
                            FlutterFlowTheme.of(context).titleLarge.fontWeight,
                      ),
                      color: tileTextColor,
                      letterSpacing: 0.0,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        drawer: Drawer(
          elevation: 16.0,
          child: wrapWithModel(
            model: _model.drawersModel2,
            updateCallback: () => safeSetState(() {}),
            child: const DrawersWidget(),
          ),
        ),
        body: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
              context: context,
              phone: false,
              tablet: false,
            ))
              Container(
                width: 270.0,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF111D31),
                  borderRadius: BorderRadius.circular(0.0),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                child: wrapWithModel(
                  model: _model.drawersModel1,
                  updateCallback: () => safeSetState(() {}),
                  child: const DrawersWidget(),
                ),
              ),
            Expanded(
              child: AdminContentFrame(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16.0, 16.0, 16.0, 0.0),
                        child: AdminResponsiveRow(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'db6gl5y5' /* Обзор */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.interTight(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .headlineMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .headlineMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .headlineMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 12.0, 16.0, 12.0),
                              child: AdminResponsiveRow(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 50.0,
                                    height: 50.0,
                                    decoration: BoxDecoration(
                                      color:
                                          FlutterFlowTheme.of(context).accent1,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 2.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) => ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: CachedNetworkImage(
                                            fadeInDuration: const Duration(
                                                milliseconds: 500),
                                            fadeOutDuration: const Duration(
                                                milliseconds: 500),
                                            imageUrl: currentUserPhoto,
                                            width: 44.0,
                                            height: 44.0,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, _, __) =>
                                                Container(
                                              color: const Color(0xFFE5E7EB),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.person,
                                                size: 20,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 0.0, 0.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AuthUserStreamWidget(
                                          builder: (context) => Text(
                                            currentUserDisplayName,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyLarge
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyLarge
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyLarge
                                                            .fontStyle,
                                                  ),
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyLarge
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyLarge
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          currentUserUid,
                                          style: FlutterFlowTheme.of(context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (responsiveVisibility(
                              context: context,
                              tabletLandscape: false,
                              desktop: false,
                            ))
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: FlutterFlowIconButton(
                                      borderRadius: 8.0,
                                      buttonSize: 36.0,
                                      fillColor:
                                          FlutterFlowTheme.of(context).primary,
                                      icon: Icon(
                                        Icons.menu,
                                        color:
                                            FlutterFlowTheme.of(context).info,
                                        size: 24.0,
                                      ),
                                      onPressed: () async {
                                        scaffoldKey.currentState!.openDrawer();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      AdminCard(
                        child: FutureBuilder<Map<String, int>>(
                          future: _loadCounts(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Text(
                                'Нет доступа к сводке админки.',
                              );
                            }
                            final data = snapshot.data ?? {};
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _summaryTile(
                                  'Компаний',
                                  data['companies'] ?? 0,
                                  Icons.apartment,
                                  const Color(0xFFEFF6FF),
                                ),
                                _summaryTile(
                                  'Пользователей',
                                  data['users'] ?? 0,
                                  Icons.people,
                                  const Color(0xFFF0FDF4),
                                ),
                                _summaryTile(
                                  'Транзакций',
                                  data['transactions'] ?? 0,
                                  Icons.swap_horiz,
                                  const Color(0xFFFFFBEB),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Последние транзакции',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('tranzaction')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Text(
                                    'Нет доступа к транзакциям.',
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final rows = snapshot.data!.docs.map((doc) {
                                  final data = Map<String, dynamic>.from(
                                      doc.data() as Map);
                                  return {
                                    'id': doc.id,
                                    'type': (data['type'] ?? '').toString(),
                                    'summa': (data['summa'] ?? 0) as num,
                                    'date': _dateFrom(data['date'] ??
                                        data['created_at'] ??
                                        data['createdAt']),
                                  };
                                }).toList()
                                  ..sort((a, b) {
                                    final aDate = a['date'] as DateTime?;
                                    final bDate = b['date'] as DateTime?;
                                    if (aDate == null && bDate == null) {
                                      return 0;
                                    }
                                    if (aDate == null) return 1;
                                    if (bDate == null) return -1;
                                    return bDate.compareTo(aDate);
                                  });
                                final visibleRows = rows.take(8).toList();
                                if (visibleRows.isEmpty) {
                                  return const Text('Нет транзакций');
                                }
                                return AdminTableScroll(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Дата')),
                                      DataColumn(label: Text('Тип')),
                                      DataColumn(label: Text('Сумма')),
                                    ],
                                    rows: visibleRows.map((row) {
                                      final date = row['date'] as DateTime?;
                                      return DataRow(cells: [
                                        DataCell(Text(date == null
                                            ? '-'
                                            : dateTimeFormat('dd/MM/yyyy', date,
                                                locale:
                                                    FFLocalizations.of(context)
                                                        .languageCode))),
                                        DataCell(Text(row['type'].toString())),
                                        DataCell(Text(formatMoneyWithCurrency(
                                          row['summa'] as num,
                                          currencyCode: row['company_currency']
                                                  ?.toString() ??
                                              row['currency']?.toString(),
                                        ))),
                                      ]);
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ].addToEnd(const SizedBox(height: 24.0)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
