import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'uchet_widget.dart' show UchetWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UchetModel extends FlutterFlowModel<UchetWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel1;
  // Model for drawersUsers component.
  late DrawersUsersModel drawersUsersModel2;
  // Model for header component.
  late HeaderModel headerModel;
  // State field(s) for TabBar widget.
  TabController? tabBarController1;
  int get tabBarCurrentIndex1 =>
      tabBarController1 != null ? tabBarController1!.index : 0;
  int get tabBarPreviousIndex1 =>
      tabBarController1 != null ? tabBarController1!.previousIndex : 0;

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // State field(s) for osn widget.
  late ExpandableController osnExpandableController1;

  // State field(s) for nalog widget.
  late ExpandableController nalogExpandableController1;

  // State field(s) for osn widget.
  late ExpandableController osnExpandableController2;

  // State field(s) for nalog widget.
  late ExpandableController nalogExpandableController2;

  // State field(s) for TabBar widget.
  TabController? tabBarController2;
  int get tabBarCurrentIndex2 =>
      tabBarController2 != null ? tabBarController2!.index : 0;
  int get tabBarPreviousIndex2 =>
      tabBarController2 != null ? tabBarController2!.previousIndex : 0;

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
    tabBarController1?.dispose();
    expandableExpandableController.dispose();
    osnExpandableController1.dispose();
    nalogExpandableController1.dispose();
    osnExpandableController2.dispose();
    nalogExpandableController2.dispose();
    tabBarController2?.dispose();
  }
}
