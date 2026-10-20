import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'analitika_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/utils/app_money_format.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'analitika_admin_model.dart';

class AnalitikaAdminWidget extends StatefulWidget {
  const AnalitikaAdminWidget({super.key});

  static String routeName = 'analitikaAdmin';
  static String routePath = '/analitikaAdmin';

  @override
  State<AnalitikaAdminWidget> createState() => _AnalitikaAdminWidgetState();
}

class _AnalitikaAdminWidgetState extends State<AnalitikaAdminWidget> {
  late AnalitikaAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _rangeFilter = '30';
  String _search = '';

  Future<Map<String, int>> _loadCounts() async {
    final firestore = FirebaseFirestore.instance;
    final companiesSnap = await firestore.collection('companies').get();
    final usersSnap = await firestore.collection('users').get();
    Query tranzQuery = firestore.collection('tranzaction');
    if (_rangeFilter != 'all') {
      final days = _rangeFilter == '90'
          ? 90
          : _rangeFilter == '365'
              ? 365
              : 30;
      final since = DateTime.now().subtract(Duration(days: days));
      tranzQuery = tranzQuery.where('date', isGreaterThanOrEqualTo: since);
    }
    final tranzSnap = await tranzQuery.get();
    final warehousesSnap = await firestore.collection('warehouses').get();
    return {
      'companies': companiesSnap.size,
      'users': usersSnap.size,
      'transactions': tranzSnap.size,
      'warehouses': warehousesSnap.size,
    };
  }

  String _formatCount(int value) {
    return formatNumber(
      value,
      formatType: FormatType.decimal,
      decimalType: DecimalType.automatic,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return dateTimeFormat('dd/MM/yyyy', date,
        locale: FFLocalizations.of(context).languageCode);
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int rowNameCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aName = (a['name'] ?? a['id'] ?? '').toString().toLowerCase();
    final bName = (b['name'] ?? b['id'] ?? '').toString().toLowerCase();
    return aName.compareTo(bName);
  }

  Widget _summaryTile(String title, int value, IconData icon, Color color) {
    const tileBg = Color(0xFF0F172A);
    const tileBorder = Color(0xFF334155);
    const titleColor = Color(0xFFCBD5E1);
    const valueColor = Color(0xFFF8FAFC);
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
                      color: titleColor,
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
                      color: valueColor,
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
    _model = createModel(context, () => AnalitikaAdminModel());

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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: Drawer(
          elevation: 16.0,
          child: wrapWithModel(
            model: _model.drawersModel2,
            updateCallback: () => safeSetState(() {}),
            child: DrawersWidget(),
          ),
        ),
        body: SafeArea(
          top: true,
          child: Row(
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
                    color: Color(0xFF111D31),
                    borderRadius: BorderRadius.circular(0.0),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: wrapWithModel(
                    model: _model.drawersModel1,
                    updateCallback: () => safeSetState(() {}),
                    child: DrawersWidget(),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: AdminContentFrame(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 0.0),
                            child: AdminResponsiveRow(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (responsiveVisibility(
                                  context: context,
                                  tabletLandscape: false,
                                  desktop: false,
                                ))
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(5.0),
                                        child: FlutterFlowIconButton(
                                          borderRadius: 8.0,
                                          buttonSize: 36.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          icon: Icon(
                                            Icons.menu,
                                            color: FlutterFlowTheme.of(context)
                                                .info,
                                            size: 24.0,
                                          ),
                                          onPressed: () async {
                                            scaffoldKey.currentState!
                                                .openDrawer();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          '7os497k9' /* Аналитика */,
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
                                              fontSize: 16.0,
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
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 12.0, 16.0, 12.0),
                                  child: AdminResponsiveRow(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 50.0,
                                        height: 50.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .accent1,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 2.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2.0),
                                          child: AuthUserStreamWidget(
                                            builder: (context) => ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: CachedNetworkImage(
                                                fadeInDuration:
                                                    Duration(milliseconds: 500),
                                                fadeOutDuration:
                                                    Duration(milliseconds: 500),
                                                imageUrl: currentUserPhoto,
                                                width: 44.0,
                                                height: 44.0,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 0.0, 0.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AuthUserStreamWidget(
                                              builder: (context) => Text(
                                                currentUserDisplayName,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
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
                                              style:
                                                  FlutterFlowTheme.of(context)
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
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 8.0, 16.0, 0.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ChoiceChip(
                                  label: const Text('30 дней'),
                                  selected: _rangeFilter == '30',
                                  onSelected: (_) =>
                                      setState(() => _rangeFilter = '30'),
                                ),
                                ChoiceChip(
                                  label: const Text('90 дней'),
                                  selected: _rangeFilter == '90',
                                  onSelected: (_) =>
                                      setState(() => _rangeFilter = '90'),
                                ),
                                ChoiceChip(
                                  label: const Text('Год'),
                                  selected: _rangeFilter == '365',
                                  onSelected: (_) =>
                                      setState(() => _rangeFilter = '365'),
                                ),
                                ChoiceChip(
                                  label: const Text('Все время'),
                                  selected: _rangeFilter == 'all',
                                  onSelected: (_) =>
                                      setState(() => _rangeFilter = 'all'),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Поиск по названию/БИН/ИНН',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _search = val.trim()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdminCard(
                            child: FutureBuilder<Map<String, int>>(
                              future: _loadCounts(),
                              builder: (context, snapshot) {
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
                                    _summaryTile(
                                      'Складов',
                                      data['warehouses'] ?? 0,
                                      Icons.warehouse,
                                      const Color(0xFFFDF2F8),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                SizedBox(
                                  width: 520,
                                  child: AdminCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Последние компании',
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
                                              .collection('companies')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              return const Text(
                                                  'Ошибка загрузки компаний');
                                            }
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((doc) {
                                              final data =
                                                  Map<String, dynamic>.from(
                                                      doc.data() as Map);
                                              return {
                                                'id': doc.id,
                                                'name': (data['name'] ?? '')
                                                    .toString(),
                                                'bin': (data['bin'] ?? '')
                                                    .toString(),
                                                'ownerId':
                                                    (data['ownerId'] ?? '')
                                                        .toString(),
                                                'createdAt': _dateFrom(
                                                    data['createdAt'] ??
                                                        data['created_at']),
                                              };
                                            }).where((row) {
                                              if (_search.isEmpty) {
                                                return true;
                                              }
                                              final q = _search.toLowerCase();
                                              return row['name']
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(q) ||
                                                  row['bin']
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(q);
                                            }).toList()
                                              ..sort((a, b) {
                                                final aDate =
                                                    a['createdAt'] as DateTime?;
                                                final bDate =
                                                    b['createdAt'] as DateTime?;
                                                if (aDate == null &&
                                                    bDate == null) {
                                                  return rowNameCompare(a, b);
                                                }
                                                if (aDate == null) return 1;
                                                if (bDate == null) return -1;
                                                return bDate.compareTo(aDate);
                                              });
                                            final visibleItems =
                                                items.take(8).toList();
                                            if (visibleItems.isEmpty) {
                                              return const Text('Нет данных');
                                            }
                                            return AdminTableScroll(
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('Название')),
                                                  DataColumn(
                                                      label: Text('БИН/ИНН')),
                                                  DataColumn(
                                                      label: Text('Владелец')),
                                                  DataColumn(
                                                      label: Text('Создана')),
                                                ],
                                                rows: visibleItems.map((row) {
                                                  return DataRow(cells: [
                                                    DataCell(Text(row['name']
                                                        .toString())),
                                                    DataCell(Text(
                                                        row['bin'].toString())),
                                                    DataCell(Text(row['ownerId']
                                                        .toString())),
                                                    DataCell(Text(_formatDate(
                                                        row['createdAt']
                                                            as DateTime?))),
                                                  ]);
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 520,
                                  child: AdminCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Последние пользователи',
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
                                              .collection('users')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              return const Text(
                                                  'Ошибка загрузки пользователей');
                                            }
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((doc) {
                                              final data =
                                                  Map<String, dynamic>.from(
                                                      doc.data() as Map);
                                              return {
                                                'id': doc.id,
                                                'name':
                                                    (data['display_name'] ?? '')
                                                        .toString(),
                                                'phone':
                                                    (data['phone_number'] ?? '')
                                                        .toString(),
                                                'role': (data['role'] ?? '')
                                                    .toString(),
                                                'created': _dateFrom(
                                                    data['created_time'] ??
                                                        data['createdAt']),
                                              };
                                            }).where((row) {
                                              if (_search.isEmpty) {
                                                return true;
                                              }
                                              final q = _search.toLowerCase();
                                              return row['name']
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(q) ||
                                                  row['phone']
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(q);
                                            }).toList()
                                              ..sort((a, b) {
                                                final aDate =
                                                    a['created'] as DateTime?;
                                                final bDate =
                                                    b['created'] as DateTime?;
                                                if (aDate == null &&
                                                    bDate == null) {
                                                  return rowNameCompare(a, b);
                                                }
                                                if (aDate == null) return 1;
                                                if (bDate == null) return -1;
                                                return bDate.compareTo(aDate);
                                              });
                                            final visibleItems =
                                                items.take(8).toList();
                                            if (visibleItems.isEmpty) {
                                              return const Text('Нет данных');
                                            }
                                            return AdminTableScroll(
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('Имя')),
                                                  DataColumn(
                                                      label: Text('Телефон')),
                                                  DataColumn(
                                                      label: Text('Роль')),
                                                  DataColumn(
                                                      label: Text('Создан')),
                                                ],
                                                rows: visibleItems.map((row) {
                                                  return DataRow(cells: [
                                                    DataCell(Text(row['name']
                                                        .toString())),
                                                    DataCell(Text(row['phone']
                                                        .toString())),
                                                    DataCell(Text(row['role']
                                                        .toString())),
                                                    DataCell(Text(_formatDate(
                                                        row['created']
                                                            as DateTime?))),
                                                  ]);
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 1060,
                                  child: AdminCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          stream: (() {
                                            return FirebaseFirestore.instance
                                                .collection('tranzaction')
                                                .snapshots();
                                          })(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              return const Text(
                                                  'Ошибка загрузки транзакций');
                                            }
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((doc) {
                                              final data =
                                                  Map<String, dynamic>.from(
                                                      doc.data() as Map);
                                              return {
                                                'id': doc.id,
                                                'type': (data['type'] ?? '')
                                                    .toString(),
                                                'typeUchet':
                                                    (data['typeUchet'] ?? '')
                                                        .toString(),
                                                'summa':
                                                    (data['summa'] ?? 0) as num,
                                                'idCompany':
                                                    (data['idCompany'] ?? '')
                                                        .toString(),
                                                'date': _dateFrom(
                                                    data['date'] ??
                                                        data['created_at'] ??
                                                        data['createdAt']),
                                              };
                                            }).where((row) {
                                              if (_rangeFilter == 'all') {
                                                return true;
                                              }
                                              final date =
                                                  row['date'] as DateTime?;
                                              if (date == null) return false;
                                              final days = _rangeFilter == '90'
                                                  ? 90
                                                  : _rangeFilter == '365'
                                                      ? 365
                                                      : 30;
                                              final since = DateTime.now()
                                                  .subtract(
                                                      Duration(days: days));
                                              return !date.isBefore(since);
                                            }).toList()
                                              ..sort((a, b) {
                                                final aDate =
                                                    a['date'] as DateTime?;
                                                final bDate =
                                                    b['date'] as DateTime?;
                                                if (aDate == null &&
                                                    bDate == null) {
                                                  return 0;
                                                }
                                                if (aDate == null) return 1;
                                                if (bDate == null) return -1;
                                                return bDate.compareTo(aDate);
                                              });
                                            final visibleItems =
                                                items.take(10).toList();
                                            if (visibleItems.isEmpty) {
                                              return const Text('Нет данных');
                                            }
                                            return AdminTableScroll(
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('Дата')),
                                                  DataColumn(
                                                      label: Text('Тип')),
                                                  DataColumn(
                                                      label: Text('Учет')),
                                                  DataColumn(
                                                      label: Text('Сумма')),
                                                  DataColumn(
                                                      label: Text('Компания')),
                                                ],
                                                rows: visibleItems.map((row) {
                                                  return DataRow(cells: [
                                                    DataCell(Text(_formatDate(
                                                        row['date']
                                                            as DateTime?))),
                                                    DataCell(Text(row['type']
                                                        .toString())),
                                                    DataCell(Text(
                                                        row['typeUchet']
                                                            .toString())),
                                                    DataCell(Text(
                                                        formatMoneyWithCurrency(
                                                      row['summa'] as num,
                                                      currencyCode:
                                                          row['company_currency']
                                                                  ?.toString() ??
                                                              row['currency']
                                                                  ?.toString(),
                                                    ))),
                                                    DataCell(Text(
                                                        row['idCompany']
                                                            .toString())),
                                                  ]);
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ].addToEnd(SizedBox(height: 24.0)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
