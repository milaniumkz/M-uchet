import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/money/component/add_tranzaction/add_tranzaction_widget.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'tranzaction_widget.dart' show TranzactionWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TranzactionModel extends FlutterFlowModel<TranzactionWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in tranzaction widget.
  List<TranzactionRecord>? tranzaction;
  // Stores action output result for [Custom Action - calculateTotalIncome] action in tranzaction widget.
  double? summaIncome;
  // Stores action output result for [Custom Action - calculateTotalDecome] action in tranzaction widget.
  double? decome;
  // Stores action output result for [Custom Action - calculateSumByTypeUchet] action in tranzaction widget.
  double? up;
  // Stores action output result for [Custom Action - calculateSumByTypeUchet] action in tranzaction widget.
  double? bu;
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
