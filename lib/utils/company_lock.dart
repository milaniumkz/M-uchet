/// Kept for existing callers. Completing setup never locks editing.
class CompanyLock {
  static void invalidate(String companyId) {}
  static Future<bool> isLocked(String companyId) async => false;
  static Future<bool> isLockedForCurrentUser() async => false;
}
