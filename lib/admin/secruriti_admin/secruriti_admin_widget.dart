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
import 'secruriti_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'secruriti_admin_model.dart';

class SecruritiAdminWidget extends StatefulWidget {
  const SecruritiAdminWidget({super.key});

  static String routeName = 'secruritiAdmin';
  static String routePath = '/secruritiAdmin';

  @override
  State<SecruritiAdminWidget> createState() => _SecruritiAdminWidgetState();
}

class _SecruritiAdminWidgetState extends State<SecruritiAdminWidget> {
  late SecruritiAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _search = '';
  bool _require2fa = false;
  int _sessionDays = 30;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SecruritiAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _saveSecuritySettings() async {
    await FirebaseFirestore.instance
        .collection('security_settings')
        .doc('global')
        .set({
      'require_2fa': _require2fa,
      'session_ttl_days': _sessionDays,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
                                          'xbobu53p' /* Безопастность */,
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
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Поиск по событию/пользователю',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Политики безопасности',
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
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('security_settings')
                                      .doc('global')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data!.data() != null) {
                                      final data = Map<String, dynamic>.from(
                                          snapshot.data!.data() as Map);
                                      _require2fa = data['require_2fa'] == true;
                                      final rawDays = data['session_ttl_days'];
                                      if (rawDays is num) {
                                        _sessionDays = rawDays.toInt();
                                      }
                                    }
                                    return Column(
                                      children: [
                                        SwitchListTile(
                                          value: _require2fa,
                                          onChanged: (val) {
                                            setState(() => _require2fa = val);
                                            _saveSecuritySettings();
                                          },
                                          title: const Text('Требовать 2FA'),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Text('TTL сессии (дней):'),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                initialValue:
                                                    _sessionDays.toString(),
                                                keyboardType:
                                                    TextInputType.number,
                                                onFieldSubmitted: (val) {
                                                  final parsed =
                                                      int.tryParse(val.trim());
                                                  if (parsed != null) {
                                                    setState(() =>
                                                        _sessionDays = parsed);
                                                    _saveSecuritySettings();
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Журнал событий',
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
                                      .collection('security_logs')
                                      .orderBy('created_at', descending: true)
                                      .limit(50)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                          'Ошибка загрузки журнала безопасности');
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
                                        'event':
                                            (data['event'] ?? '').toString(),
                                        'user': (data['user'] ?? '').toString(),
                                        'ip': (data['ip'] ?? '').toString(),
                                        'status':
                                            (data['status'] ?? '').toString(),
                                        'created':
                                            (data['created_at'] as Timestamp?)
                                                ?.toDate(),
                                      };
                                    }).where((row) {
                                      if (_search.isEmpty) return true;
                                      final q = _search.toLowerCase();
                                      return row['event']
                                              .toString()
                                              .toLowerCase()
                                              .contains(q) ||
                                          row['user']
                                              .toString()
                                              .toLowerCase()
                                              .contains(q);
                                    }).toList();
                                    if (rows.isEmpty) {
                                      return const Text('Событий нет');
                                    }
                                    return AdminTableScroll(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Дата')),
                                          DataColumn(label: Text('Событие')),
                                          DataColumn(
                                              label: Text('Пользователь')),
                                          DataColumn(label: Text('IP')),
                                          DataColumn(label: Text('Статус')),
                                        ],
                                        rows: rows.map((row) {
                                          final date =
                                              row['created'] as DateTime?;
                                          return DataRow(cells: [
                                            DataCell(Text(date == null
                                                ? '-'
                                                : dateTimeFormat(
                                                    'dd/MM/yyyy', date,
                                                    locale: FFLocalizations.of(
                                                            context)
                                                        .languageCode))),
                                            DataCell(
                                                Text(row['event'].toString())),
                                            DataCell(
                                                Text(row['user'].toString())),
                                            DataCell(
                                                Text(row['ip'].toString())),
                                            DataCell(
                                                Text(row['status'].toString())),
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
