String accountMovementTitle({
  required String counterTitle,
  required String description,
  required String memo,
  required bool isPositive,
}) {
  final normalizedCounter = counterTitle.trim();
  if (normalizedCounter.isNotEmpty) return normalizedCounter;
  return isPositive ? 'Приход' : 'Расход';
}

String accountMovementDescription({
  required String description,
  required String memo,
  required bool isPositive,
}) {
  final raw = description.trim().isNotEmpty ? description.trim() : memo.trim();
  final normalized = raw.toLowerCase();
  if (normalized == 'проводка' || normalized == 'проводки') {
    return isPositive ? 'Приход' : 'Расход';
  }
  return raw;
}
