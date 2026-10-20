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
import 'users_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'users_admin_model.dart';

class UsersAdminWidget extends StatefulWidget {
  const UsersAdminWidget({super.key});

  static String routeName = 'usersAdmin';
  static String routePath = '/usersAdmin';

  @override
  State<UsersAdminWidget> createState() => _UsersAdminWidgetState();
}

class _UsersAdminWidgetState extends State<UsersAdminWidget> {
  late UsersAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _roleController = TextEditingController();
  bool _blocked = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UsersAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _roleController.dispose();
    _model.dispose();

    super.dispose();
  }

  Future<void> _openUserDialog(Map<String, dynamic> user) async {
    _roleController.text = (user['role'] ?? '').toString();
    _blocked = user['bloc'] == true;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Редактировать пользователя'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('UID: ${user['id']}'),
                const SizedBox(height: 8),
                TextField(
                  controller: _roleController,
                  decoration: const InputDecoration(labelText: 'Роль'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _blocked,
                  onChanged: (val) => setState(() => _blocked = val),
                  title: const Text('Заблокирован'),
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
                    .collection('users')
                    .doc(user['id'].toString())
                    .update({
                  'role': _roleController.text.trim(),
                  'bloc': _blocked,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return dateTimeFormat('dd/MM/yyyy', date,
        locale: FFLocalizations.of(context).languageCode);
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
                  child: Visibility(
                    visible: responsiveVisibility(
                      context: context,
                      phone: false,
                      tablet: false,
                    ),
                    child: wrapWithModel(
                      model: _model.drawersModel1,
                      updateCallback: () => safeSetState(() {}),
                      child: DrawersWidget(),
                    ),
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
                                          '6ii2zua9' /* Пользователи */,
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
                                      hintText: 'Поиск по имени/телефону',
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
                                  'Пользователи',
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
                                      .orderBy('created_time', descending: true)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                          'Ошибка загрузки пользователей');
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
                                        'name': (data['display_name'] ?? '')
                                            .toString(),
                                        'phone': (data['phone_number'] ?? '')
                                            .toString(),
                                        'role': (data['role'] ?? '').toString(),
                                        'companyIds': (data['companyIds']
                                                as List<dynamic>?)
                                            ?.length
                                            .toString(),
                                        'activeCompanyId':
                                            (data['activeCompanyId'] ?? '')
                                                .toString(),
                                        'bloc': data['bloc'] == true,
                                        'created':
                                            (data['created_time'] as Timestamp?)
                                                ?.toDate(),
                                      };
                                    }).where((row) {
                                      if (_search.isEmpty) return true;
                                      final q = _search.toLowerCase();
                                      return row['name']
                                              .toString()
                                              .toLowerCase()
                                              .contains(q) ||
                                          row['phone']
                                              .toString()
                                              .toLowerCase()
                                              .contains(q);
                                    }).toList();
                                    if (rows.isEmpty) {
                                      return const Text(
                                          'Пользователи не найдены');
                                    }
                                    return AdminTableScroll(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Имя')),
                                          DataColumn(label: Text('Телефон')),
                                          DataColumn(label: Text('Роль')),
                                          DataColumn(label: Text('Компаний')),
                                          DataColumn(label: Text('Активная')),
                                          DataColumn(label: Text('Блок')),
                                          DataColumn(label: Text('Создан')),
                                          DataColumn(label: Text('Действия')),
                                        ],
                                        rows: rows.map((row) {
                                          return DataRow(cells: [
                                            DataCell(
                                                Text(row['name'].toString())),
                                            DataCell(
                                                Text(row['phone'].toString())),
                                            DataCell(
                                                Text(row['role'].toString())),
                                            DataCell(Text(
                                              ((row['companyIds'] is List)
                                                      ? (row['companyIds']
                                                              as List)
                                                          .length
                                                      : (row['companyIds'] ??
                                                          0))
                                                  .toString(),
                                            )),
                                            DataCell(Text(row['activeCompanyId']
                                                .toString())),
                                            DataCell(Text(row['bloc'] == true
                                                ? 'Да'
                                                : 'Нет')),
                                            DataCell(Text(_formatDate(
                                                row['created'] as DateTime?))),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                onPressed: () =>
                                                    _openUserDialog(row),
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
