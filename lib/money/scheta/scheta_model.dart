import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/add_schet/add_schet_widget.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/edit_schet/edit_schet_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'scheta_widget.dart' show SchetaWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SchetaModel extends FlutterFlowModel<SchetaWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel1;
  // Model for header component.
  late HeaderModel headerModel;
  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel2;

  @override
  void initState(BuildContext context) {
    drawersUsersModel1 = createModel(context, () => DrawersUsersModel());
    headerModel = createModel(context, () => HeaderModel());
    drawersUsersModel2 = createModel(context, () => DrawersUsersModel());
  }

  @override
  void dispose() {
    drawersUsersModel1.dispose();
    headerModel.dispose();
    drawersUsersModel2.dispose();
  }
}
