import 'package:flutter/material.dart';

enum EditSection { budget, goods, transactions, other }

/// Editing is always available after initial setup and after period closure.
/// These compatibility entry points intentionally do not read legacy locks or
/// temporary editing deadlines. Authorization is checked separately by the
/// screen and by the server for the selected organization.
class EditingHelper {
  static bool isLocked({
    EditSection section = EditSection.other,
    BuildContext? context,
  }) => false;

  static bool canEdit({EditSection section = EditSection.other}) => true;

  static bool canEditExisting({EditSection section = EditSection.other}) => true;

  static bool guard(BuildContext context,
      {EditSection section = EditSection.other}) => true;

  static bool guardEdit(BuildContext context,
      {EditSection section = EditSection.other}) => true;
}
