import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/drawers/drawers_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/admin/design_admin/user_design_admin_panel.dart';
import '/user_design/user_design.dart';
import '/utils/access_rules.dart';

class DesignAdminWidget extends StatefulWidget {
  const DesignAdminWidget({super.key});

  static String routeName = 'designAdmin';
  static String routePath = '/designAdmin';

  @override
  State<DesignAdminWidget> createState() => _DesignAdminWidgetState();
}

class _DesignAdminWidgetState extends State<DesignAdminWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final companyId = resolveCurrentCompanyId();
    final userData =
        currentUserDocument?.snapshotData ?? const <String, dynamic>{};
    final canManageDesign = AccessRules.isAdminUserData(userData);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: const Drawer(child: DrawersWidget()),
        body: SafeArea(
          top: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.sizeOf(context).width >= 1024)
                Container(
                  width: 270,
                  height: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFF111D31)),
                  child: const DrawersWidget(),
                ),
              Expanded(
                child: AdminContentFrame(
                  child: !canManageDesign
                      ? const Center(
                          child: Text(
                              'Доступ к управлению дизайном есть только у админов'),
                        )
                      : companyId.isEmpty
                          ? const Center(child: Text('Компания не выбрана'))
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Дизайн пользователей',
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.interTight(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  UserDesignAdminPanel(companyId: companyId),
                                ],
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
