// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/user_design/user_design.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

class ResponsiveFrame extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double maxWidth;

  const ResponsiveFrame({
    Key? key,
    required this.child,
    this.backgroundColor = const Color(0xFFF7F8FA),
    this.maxWidth = 1360,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final design = UserDesignScope.maybeOf(context);
    final usesDefaultBackground = backgroundColor == const Color(0xFFF7F8FA);
    final resolvedBackground = usesDefaultBackground
        ? (design?.softSurfaceColor ?? theme.primaryBackground)
        : backgroundColor;
    return Container(
      color: resolvedBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > maxWidth ? maxWidth : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
