import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/sale/client/client_model.dart';
export '/sale/client/client_model.dart';

class ReceivablesWidget extends StatefulWidget {
  const ReceivablesWidget({super.key});

  static String routeName = 'receivables';
  static String routePath = '/receivables';

  @override
  State<ReceivablesWidget> createState() => _ReceivablesWidgetState();
}

class _ReceivablesWidgetState extends State<ReceivablesWidget> {
  late ClientModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClientModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
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
        body: SafeArea(
          top: true,
          child: Row(
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
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1170.0),
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (responsiveVisibility(
                            context: context,
                            tabletLandscape: false,
                            desktop: false,
                          ))
                            Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: FlutterFlowTheme.of(context).primary,
                                icon: Icon(
                                  Icons.menu,
                                  color: FlutterFlowTheme.of(context).info,
                                  size: 24.0,
                                ),
                                onPressed: () =>
                                    scaffoldKey.currentState!.openDrawer(),
                              ),
                            ),
                          Expanded(
                            child: HeaderWidget(
                              title: 'Дебиторская задолженность',
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: custom_widgets.SalesClientsWidget(
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ],
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
