import 'package:flutter/material.dart';
import '/admin/component/admin_card.dart';

class AdminContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdminContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1360,
  });

  @override
  Widget build(BuildContext context) {
    final adminTheme = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F17),
      canvasColor: const Color(0xFF111827),
      cardColor: const Color(0xFF111827),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF111827),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFC9A15B),
        secondary: Color(0xFF60A5FA),
        surface: Color(0xFF111827),
        error: Color(0xFFEF4444),
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFFF8FAFC),
            displayColor: const Color(0xFFF8FAFC),
          ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF0F172A),
        labelStyle: TextStyle(color: Color(0xFFCBD5E1)),
        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFC9A15B)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: Color(0xFFE5E7EB)),
        headingRowColor: WidgetStatePropertyAll<Color>(Color(0xFF0F172A)),
        dataRowColor: WidgetStatePropertyAll<Color>(Color(0xFF111827)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
      dividerColor: const Color(0xFF334155),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > maxWidth
            ? maxWidth
            : constraints.maxWidth;
        final isNarrow = MediaQuery.sizeOf(context).width < 900;
        final padding = isNarrow
            ? const EdgeInsets.symmetric(horizontal: 12)
            : const EdgeInsets.symmetric(horizontal: 16);
        final cardPadding = isNarrow
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
            : const EdgeInsets.all(20);
        final cardMargin = isNarrow
            ? const EdgeInsets.only(top: 12, bottom: 20)
            : const EdgeInsets.only(top: 16, bottom: 24);
        return Theme(
          data: adminTheme,
          child: Align(
          alignment: const AlignmentDirectional(0.0, -1.0),
            child: SizedBox(
              width: contentWidth,
              child: Padding(
                padding: padding,
                child: AdminCard(
                  padding: cardPadding,
                  margin: cardMargin,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
