import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import 'dart:ui';
import '/index.dart';
import 'reg_page_director_widget.dart' show RegPageDirectorWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class RegPageDirectorModel extends FlutterFlowModel<RegPageDirectorWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_logoCompany = false;
  FFUploadedFile uploadedLocalFile_logoCompany =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_logoCompany = '';

  // State field(s) for name widget.
  FocusNode? nameFocusNode;
  TextEditingController? nameTextController;
  String? Function(BuildContext, String?)? nameTextControllerValidator;
  // State field(s) for bin widget.
  FocusNode? binFocusNode;
  TextEditingController? binTextController;
  String? Function(BuildContext, String?)? binTextControllerValidator;
  // State field(s) for YurAdres widget.
  FocusNode? yurAdresFocusNode;
  TextEditingController? yurAdresTextController;
  String? Function(BuildContext, String?)? yurAdresTextControllerValidator;
  // State field(s) for FioDirector widget.
  FocusNode? fioDirectorFocusNode;
  TextEditingController? fioDirectorTextController;
  String? Function(BuildContext, String?)? fioDirectorTextControllerValidator;
  // State field(s) for oced widget.
  List<String>? ocedValue;
  FormFieldController<List<String>>? ocedValueController;
  // State field(s) for CheckboxListTile widget.
  bool? checkboxListTileValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    nameFocusNode?.dispose();
    nameTextController?.dispose();

    binFocusNode?.dispose();
    binTextController?.dispose();

    yurAdresFocusNode?.dispose();
    yurAdresTextController?.dispose();

    fioDirectorFocusNode?.dispose();
    fioDirectorTextController?.dispose();
  }
}
