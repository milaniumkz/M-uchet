import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'home_admin_widget.dart' show HomeAdminWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeAdminModel extends FlutterFlowModel<HomeAdminWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for drawers component.
  late DrawersModel drawersModel1;
  // Model for drawers component.
  late DrawersModel drawersModel2;

  @override
  void initState(BuildContext context) {
    drawersModel1 = createModel(context, () => DrawersModel());
    drawersModel2 = createModel(context, () => DrawersModel());
  }

  @override
  void dispose() {
    drawersModel1.dispose();
    drawersModel2.dispose();
  }
}
