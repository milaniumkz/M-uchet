import 'package:flutter/material.dart';

class AdminTableScroll extends StatelessWidget {
  final Widget child;

  const AdminTableScroll({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    if (isNarrow) {
      return child;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: child,
      ),
    );
  }
}
