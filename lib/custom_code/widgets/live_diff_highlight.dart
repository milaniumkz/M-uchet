// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

class LiveDiffHighlight extends StatelessWidget {
  final Widget child;
  final dynamic timestamp;
  final Duration window;
  final Color? highlightColor;

  const LiveDiffHighlight({
    Key? key,
    required this.child,
    required this.timestamp,
    this.window = const Duration(seconds: 60),
    this.highlightColor,
  }) : super(key: key);

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dt = _toDate(timestamp);
    final now = DateTime.now();
    final isRecent = dt != null && now.difference(dt).abs() < window;
    final effectiveHighlightColor = highlightColor ??
        FlutterFlowTheme.of(context).warning.withValues(alpha: 0.14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isRecent ? effectiveHighlightColor : Colors.transparent,
      child: child,
    );
  }
}
