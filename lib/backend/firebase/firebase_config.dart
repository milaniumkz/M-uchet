/// Compatibility entry point retained for the frontend migration.
/// No Firebase project is configured or initialized in this source copy.
Future<void> initFirebase() async {
  throw StateError(
    'M-uchet: новый backend ещё не подключён. '
    'Запуск прежнего Firebase backend отключён. '
    'См. BACKEND_MIGRATION.md.',
  );
}
