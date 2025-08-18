/// Keys used internally to represent categories.
/// UI layers will localise them into readable labels.
class CategoryKeys {
  // System (non-deletable) — "All" is virtual
  static const all = 'All';
  static const fav = 'Favourites';
  static const translated = 'Translated';

  // Friendly names you may want to seed as *user* categories
  static const breakfast = 'Breakfast';
  static const main = 'Main';
  static const dessert = 'Dessert';

  /// Only true system categories (exclude "All")
  static const systemOnly = <String>[fav, translated];

  /// Convenience: full set including "All"
  static const allSystem = <String>[all, ...systemOnly];

  /// Starter user categories you may auto-seed locally (deletable)
  static const starterUser = <String>[breakfast, main, dessert];
}

/// Extension helpers for quick checks.
extension CategoryHelpers on String {
  bool get isAllCategory => this == CategoryKeys.all;
  bool get isSystemCategory =>
      this == CategoryKeys.fav ||
      this == CategoryKeys.translated ||
      isAllCategory;
}
