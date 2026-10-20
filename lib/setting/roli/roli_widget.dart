import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'roli_model.dart';
export 'roli_model.dart';

class RoliWidget extends StatefulWidget {
  const RoliWidget({super.key});

  static String routeName = 'roli';
  static String routePath = '/roli';

  @override
  State<RoliWidget> createState() => _RoliWidgetState();
}

class _RoliWidgetState extends State<RoliWidget> {
  late RoliModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  int _rolesRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RoliModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String get _companyId {
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') return active;
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    if (rawCompanyId.isNotEmpty && rawCompanyId != '__all__') {
      return rawCompanyId;
    }
    final ids = currentUserDocument?.companyIds ?? const [];
    for (final raw in ids) {
      final id = raw.toString().trim();
      if (id.isNotEmpty && id != '__all__') return id;
    }
    return currentUserUid;
  }

  Future<void> _showAddRoleDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить роль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название роли'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final description = descController.text.trim();
    nameController.dispose();
    descController.dispose();
    if (result != true || name.isEmpty) return;

    final companyId = _companyId;
    await FirebaseFirestore.instance.collection('roles').add({
      'type': 'role',
      'name': name,
      'description': description,
      'permissions': <String>['settings.roles'],
      'allowed_company_ids': <String>[companyId],
      'idCompany': companyId,
      'user_id': currentUserUid,
      'name_key': name.toLowerCase(),
      'source': 'manual',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() => _rolesRefreshVersion++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Роль добавлена. Откройте карточку роли для настройки прав.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
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
            model: _model.drawersUsersModel1,
            updateCallback: () => safeSetState(() {}),
            child: DrawersUsersWidget(),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddRoleDialog,
          icon: const Icon(Icons.add),
          label: const Text('Добавить роль'),
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
                  width: FFAppState().userSidebarCollapsed ? 88.0 : 270.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(0.0),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: wrapWithModel(
                    model: _model.drawersUsersModel2,
                    updateCallback: () => safeSetState(() {}),
                    child: DrawersUsersWidget(),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: 1170.0,
                    ),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
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
                                        buttonSize: 40.0,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primary,
                                        icon: Icon(
                                          Icons.menu,
                                          color:
                                              FlutterFlowTheme.of(context).info,
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
                                  children: [
                                    wrapWithModel(
                                      model: _model.headerModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: HeaderWidget(
                                        title: 'Роли',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                width: MediaQuery.sizeOf(context).width * 1.0,
                                height:
                                    MediaQuery.sizeOf(context).height * 0.82,
                                child: custom_widgets.SettingsRolesWidget(
                                  key: ValueKey(_rolesRefreshVersion),
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height:
                                      MediaQuery.sizeOf(context).height * 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
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
