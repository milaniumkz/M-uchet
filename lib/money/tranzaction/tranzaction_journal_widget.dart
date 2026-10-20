import '/money/tranzaction/tranzaction_widget.dart';
import 'package:flutter/material.dart';

class TranzactionJournalWidget extends StatelessWidget {
  const TranzactionJournalWidget({super.key, this.initialFilters});

  static String routeName = 'tranzactionJournal';
  static String routePath = '/tranzactionJournal';
  final Map<String, String>? initialFilters;

  @override
  Widget build(BuildContext context) {
    return TranzactionWidget(mode: 'journal', initialFilters: initialFilters);
  }
}
