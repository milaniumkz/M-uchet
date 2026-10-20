import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:async';
import 'dart:ui';
import '/index.dart';
import 'reg_page_widget.dart' show RegPageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

class RegPageModel extends FlutterFlowModel<RegPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for DropDown widget.
  String? dropDownValue1;
  FormFieldController<String>? dropDownValueController1;
  // State field(s) for emailAddress widget.
  FocusNode? emailAddressFocusNode1;
  TextEditingController? emailAddressTextController1;
  late MaskTextInputFormatter emailAddressMask1;
  String? Function(BuildContext, String?)? emailAddressTextController1Validator;
  // State field(s) for password widget.
  FocusNode? passwordFocusNode1;
  TextEditingController? passwordTextController1;
  late bool passwordVisibility1;
  String? Function(BuildContext, String?)? passwordTextController1Validator;
  // State field(s) for country widget.
  String? countryValue;
  FormFieldController<String>? countryValueController;
  // State field(s) for otrasl widget.
  String? otraslValue;
  FormFieldController<String>? otraslValueController;
  // State field(s) for tip widget.
  String? tipValue;
  FormFieldController<String>? tipValueController;
  // State field(s) for nalog widget.
  String? nalogValue;
  FormFieldController<String>? nalogValueController;
  // State field(s) for CheckboxListTile widget.
  bool? checkboxListTileValue;
  // Stores action output result for [Backend Call - API (token)] action in Button widget.
  ApiCallResponse? token;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  int? countUsers;
  // State field(s) for emailAddress widget.
  FocusNode? emailAddressFocusNode2;
  TextEditingController? emailAddressTextController2;
  late MaskTextInputFormatter emailAddressMask2;
  String? Function(BuildContext, String?)? emailAddressTextController2Validator;
  // State field(s) for id widget.
  FocusNode? idFocusNode;
  TextEditingController? idTextController;
  String? Function(BuildContext, String?)? idTextControllerValidator;
  // State field(s) for password widget.
  FocusNode? passwordFocusNode2;
  TextEditingController? passwordTextController2;
  late bool passwordVisibility2;
  String? Function(BuildContext, String?)? passwordTextController2Validator;
  // State field(s) for DropDown widget.
  String? dropDownValue2;
  FormFieldController<String>? dropDownValueController2;

  @override
  void initState(BuildContext context) {
    emailAddressMask1 = MaskTextInputFormatter(mask: '+7 ### ### ## ##');
    passwordVisibility1 = false;
    emailAddressMask2 = MaskTextInputFormatter(mask: '+7 ### ### ## ##');
    passwordVisibility2 = false;
  }

  @override
  void dispose() {
    emailAddressFocusNode1?.dispose();
    emailAddressTextController1?.dispose();

    passwordFocusNode1?.dispose();
    passwordTextController1?.dispose();

    emailAddressFocusNode2?.dispose();
    emailAddressTextController2?.dispose();

    idFocusNode?.dispose();
    idTextController?.dispose();

    passwordFocusNode2?.dispose();
    passwordTextController2?.dispose();
  }
}
