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
import 'tarif_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'tarif_admin_model.dart';

class TarifAdminWidget extends StatefulWidget {
  const TarifAdminWidget({super.key});

  static String routeName = 'tarifAdmin';
  static String routePath = '/tarifAdmin';

  @override
  State<TarifAdminWidget> createState() => _TarifAdminWidgetState();
}

class _TarifAdminWidgetState extends State<TarifAdminWidget> {
  late TarifAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _periodController = TextEditingController();
  final _maxCompaniesController = TextEditingController();
  final _featuresController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TarifAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _periodController.dispose();
    _maxCompaniesController.dispose();
    _featuresController.dispose();
    _model.dispose();

    super.dispose();
  }

  Future<void> _openTariffDialog({Map<String, dynamic>? existing}) async {
    if (existing != null) {
      _nameController.text = (existing['name'] ?? '').toString();
      _priceController.text =
          (existing['price'] ?? existing['amount'] ?? '').toString();
      _periodController.text = (existing['period'] ?? 'month').toString();
      _maxCompaniesController.text =
          (existing['max_companies'] ?? existing['maxCompanies'] ?? '')
              .toString();
      _featuresController.text = (existing['features'] is List)
          ? (existing['features'] as List).map((e) => e.toString()).join(', ')
          : (existing['features'] ?? '').toString();
    } else {
      _nameController.clear();
      _priceController.clear();
      _periodController.text = 'month';
      _maxCompaniesController.clear();
      _featuresController.clear();
    }
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Новый тариф' : 'Редактировать тариф'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Цена'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _periodController,
                  decoration:
                      const InputDecoration(labelText: 'Период (month/year)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maxCompaniesController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Лимит компаний'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _featuresController,
                  decoration:
                      const InputDecoration(labelText: 'Фичи (через запятую)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                final price = num.tryParse(_priceController.text.trim()) ?? 0;
                final maxCompanies =
                    int.tryParse(_maxCompaniesController.text.trim());
                final features = _featuresController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final data = <String, dynamic>{
                  'name': name,
                  'price': price,
                  'period': _periodController.text.trim(),
                  'max_companies': maxCompanies,
                  'features': features,
                  'updated_at': FieldValue.serverTimestamp(),
                };
                final ref = FirebaseFirestore.instance.collection('tariffs');
                if (existing == null) {
                  await ref.add({
                    ...data,
                    'created_at': FieldValue.serverTimestamp(),
                  });
                } else {
                  await ref.doc(existing['id']).update(data);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
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
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          '8u6wd75j' /* Тарифы */,
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
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 8.0, 16.0, 0.0),
                            child: AdminResponsiveRow(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Поиск по названию',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _search = val.trim()),
                                  ),
                                ),
                                FFButtonWidget(
                                  onPressed: () => _openTariffDialog(),
                                  text: 'Добавить тариф',
                                  options: FFButtonOptions(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Тарифы',
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
                                      .collection('tariffs')
                                      .orderBy('created_at', descending: true)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                          'Ошибка загрузки тарифов');
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
                                        'name': (data['name'] ?? '').toString(),
                                        'price': (data['price'] ??
                                                data['amount'] ??
                                                0)
                                            .toString(),
                                        'period':
                                            (data['period'] ?? '').toString(),
                                        'max_companies':
                                            (data['max_companies'] ??
                                                    data['maxCompanies'] ??
                                                    '')
                                                .toString(),
                                        'features': (data['features'] is List)
                                            ? (data['features'] as List)
                                                .map((e) => e.toString())
                                                .join(', ')
                                            : (data['features'] ?? '')
                                                .toString(),
                                      };
                                    }).where((row) {
                                      if (_search.isEmpty) return true;
                                      return row['name']
                                          .toString()
                                          .toLowerCase()
                                          .contains(_search.toLowerCase());
                                    }).toList();
                                    if (rows.isEmpty) {
                                      return const Text('Тарифы не найдены');
                                    }
                                    return AdminTableScroll(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Название')),
                                          DataColumn(label: Text('Цена')),
                                          DataColumn(label: Text('Период')),
                                          DataColumn(
                                              label: Text('Лимит компаний')),
                                          DataColumn(label: Text('Фичи')),
                                          DataColumn(label: Text('Действия')),
                                        ],
                                        rows: rows.map((row) {
                                          return DataRow(cells: [
                                            DataCell(
                                                Text(row['name'].toString())),
                                            DataCell(
                                                Text(row['price'].toString())),
                                            DataCell(
                                                Text(row['period'].toString())),
                                            DataCell(Text(row['max_companies']
                                                .toString())),
                                            DataCell(Text(
                                                row['features'].toString())),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                onPressed: () =>
                                                    _openTariffDialog(
                                                        existing: row),
                                              ),
                                            ),
                                          ]);
                                        }).toList(),
                                      ),
                                    );
                                  },
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
