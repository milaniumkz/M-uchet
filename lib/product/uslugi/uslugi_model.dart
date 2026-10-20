import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'uslugi_widget.dart' show UslugiWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UslugiModel extends FlutterFlowModel<UslugiWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel1;
  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel2;
  // Model for header component.
  late HeaderModel headerModel;

  @override
  void initState(BuildContext context) {
    drawersUsersModel1 = createModel(context, () => DrawersUsersModel());
    drawersUsersModel2 = createModel(context, () => DrawersUsersModel());
    headerModel = createModel(context, () => HeaderModel());
  }

  @override
  void dispose() {
    drawersUsersModel1.dispose();
    drawersUsersModel2.dispose();
    headerModel.dispose();
  }
}
