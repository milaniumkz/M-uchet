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
import 'setting_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'setting_admin_model.dart';

class SettingAdminWidget extends StatefulWidget {
  const SettingAdminWidget({super.key});

  static String routeName = 'settingAdmin';
  static String routePath = '/settingAdmin';

  @override
  State<SettingAdminWidget> createState() => _SettingAdminWidgetState();
}

class _SettingAdminWidgetState extends State<SettingAdminWidget> {
  late SettingAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _currencyController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _ndsRateController = TextEditingController();
  final _kpnRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _timezoneController.dispose();
    _supportEmailController.dispose();
    _ndsRateController.dispose();
    _kpnRateController.dispose();
    _model.dispose();

    super.dispose();
  }

  Future<void> _openSettingsDialog(Map<String, dynamic> data) async {
    _currencyController.text = (data['default_currency'] ?? '').toString();
    _timezoneController.text = (data['timezone'] ?? '').toString();
    _supportEmailController.text = (data['support_email'] ?? '').toString();
    _ndsRateController.text = (data['nds_rate'] ?? '').toString();
    _kpnRateController.text = (data['kpn_rate'] ?? '').toString();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Глобальные настройки'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currencyController,
                  decoration: const InputDecoration(labelText: 'Валюта'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _timezoneController,
                  decoration: const InputDecoration(labelText: 'Часовой пояс'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _supportEmailController,
                  decoration:
                      const InputDecoration(labelText: 'Email поддержки'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ndsRateController,
                  decoration: const InputDecoration(labelText: 'НДС, %'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _kpnRateController,
                  decoration: const InputDecoration(
                    labelText: 'Налог на доходы/прибыль, %',
                  ),
                  keyboardType: TextInputType.number,
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
                await FirebaseFirestore.instance
                    .collection('app_settings')
                    .doc('global')
                    .set({
                  'default_currency': _currencyController.text.trim(),
                  'timezone': _timezoneController.text.trim(),
                  'support_email': _supportEmailController.text.trim(),
                  'nds_rate': num.tryParse(_ndsRateController.text.trim()) ?? 0,
                  'kpn_rate': num.tryParse(_kpnRateController.text.trim()) ?? 0,
                  'updated_at': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
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
                                          'cweybuge' /* Настройки */,
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
                          AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Глобальные настройки',
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
                                      .collection('app_settings')
                                      .doc('global')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    final data = Map<String, dynamic>.from(
                                      (snapshot.data?.data() as Map?) ??
                                          const {},
                                    );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Валюта: ${data['default_currency'] ?? '-'}'),
                                        Text(
                                            'Часовой пояс: ${data['timezone'] ?? '-'}'),
                                        Text(
                                            'Email поддержки: ${data['support_email'] ?? '-'}'),
                                        Text('НДС: ${data['nds_rate'] ?? 0}%'),
                                        Text(
                                            'Налог на доходы/прибыль: ${data['kpn_rate'] ?? 0}%'),
                                        const SizedBox(height: 12),
                                        FFButtonWidget(
                                          onPressed: () =>
                                              _openSettingsDialog(data),
                                          text: 'Изменить',
                                          options: FFButtonOptions(
                                            height: 36,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            textStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      color: Colors.white,
                                                    ),
                                          ),
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
                                  'Системные параметры',
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
                                AdminTableScroll(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Параметр')),
                                      DataColumn(label: Text('Значение')),
                                    ],
                                    rows: [
                                      DataRow(cells: [
                                        const DataCell(Text('Пользователь')),
                                        DataCell(Text(currentUserUid)),
                                      ]),
                                      DataRow(cells: [
                                        const DataCell(Text('Язык')),
                                        DataCell(Text(
                                            FFLocalizations.of(context)
                                                .languageCode)),
                                      ]),
                                    ],
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
