import 'package:flutter/material.dart';

class AdminResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const AdminResponsiveRow({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    if (!isNarrow) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }

    Widget unwrap(Widget child) {
      if (child is Expanded) return child.child;
      if (child is Flexible) return child.child;
      if (child is Spacer) return SizedBox(height: spacing);
      return child;
    }

    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(unwrap(children[i]));
      if (i != children.length - 1) {
        spaced.add(SizedBox(height: spacing));
      }
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaced,
    );
  }
}
