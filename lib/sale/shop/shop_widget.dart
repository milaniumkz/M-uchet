import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'shop_model.dart';
export 'shop_model.dart';

class ShopWidget extends StatefulWidget {
  const ShopWidget({super.key, this.embedded = false});

  final bool embedded;

  static String routeName = 'shop';
  static String routePath = '/shop';

  @override
  State<ShopWidget> createState() => _ShopWidgetState();
}

class _ShopWidgetState extends State<ShopWidget> {
  late ShopModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color get _tabSelectedColor => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.96)
      : const Color(0xFF1F2A37);

  Color get _tabUnselectedColor =>
      _isDarkTheme ? Colors.white.withValues(alpha: 0.68) : Colors.grey[600]!;

  bool get _salesTabsEnabled {
    final data = currentUserDocument?.snapshotData ?? const <String, dynamic>{};
    return data['onboarding_complete'] == true || data['data_locked'] == true;
  }

  List<Widget> _tabs(bool salesEnabled) {
    final tabs = <Widget>[
      const Tab(text: 'Магазины'),
      const Tab(text: 'Кассы'),
      const Tab(text: 'Кассиры'),
    ];
    if (salesEnabled) {
      tabs.addAll(const [
        Tab(text: 'Отчет кассиров'),
        Tab(text: 'Режим кассы'),
      ]);
    }
    return tabs;
  }

  List<Widget> _tabViews(BuildContext context, bool salesEnabled) {
    final views = <Widget>[
      custom_widgets.SalesShopsWidget(
        width: MediaQuery.sizeOf(context).width * 1.0,
        height: MediaQuery.sizeOf(context).height * 1.0,
      ),
      custom_widgets.SalesCashRegistersWidget(
        width: MediaQuery.sizeOf(context).width * 1.0,
        height: MediaQuery.sizeOf(context).height * 1.0,
      ),
      custom_widgets.SalesCashiersWidget(
        width: MediaQuery.sizeOf(context).width * 1.0,
        height: MediaQuery.sizeOf(context).height * 1.0,
      ),
    ];
    if (salesEnabled) {
      views.addAll([
        custom_widgets.SalesCashierReportsWidget(
          width: MediaQuery.sizeOf(context).width * 1.0,
          height: MediaQuery.sizeOf(context).height * 1.0,
        ),
        custom_widgets.SalesCashModeWidget(
          width: MediaQuery.sizeOf(context).width * 1.0,
          height: MediaQuery.sizeOf(context).height * 1.0,
        ),
      ]);
    }
    return views;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ShopModel());

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
    final salesEnabled = _salesTabsEnabled;
    final tabs = _tabs(salesEnabled);
    final tabViews = _tabViews(context, salesEnabled);
    if (widget.embedded) {
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              if (!salesEnabled)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Продажи станут доступны после завершения первичного ввода данных.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  labelColor: _tabSelectedColor,
                  unselectedLabelColor: _tabUnselectedColor,
                  indicatorColor: const Color(0xFF2563EB),
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: tabs,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: tabViews,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: widget.embedded
            ? null
            : Drawer(
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
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded &&
                  responsiveVisibility(
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
                              if (!widget.embedded &&
                                  responsiveVisibility(
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
                                        title: 'Магазины',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          DefaultTabController(
                            length: tabs.length,
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                if (!salesEnabled)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Продажи станут доступны после завершения первичного ввода данных.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: TabBar(
                                    labelColor: _tabSelectedColor,
                                    unselectedLabelColor: _tabUnselectedColor,
                                    indicatorColor: const Color(0xFF2563EB),
                                    dividerColor: Colors.transparent,
                                    overlayColor: WidgetStateProperty.all(
                                        Colors.transparent),
                                    tabs: tabs,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height:
                                      MediaQuery.sizeOf(context).height * 1.0,
                                  child: TabBarView(
                                    children: tabViews,
                                  ),
                                ),
                              ],
                            ),
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
