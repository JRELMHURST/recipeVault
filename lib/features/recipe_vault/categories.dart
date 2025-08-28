/// Keys used internally to represent categories.
/// UI layers must always localise them into readable labels.
class CategoryKeys {
  // System (non-deletable) — "all" is virtual
  static const all = 'all';
  static const fav = 'favourites';
  static const translated = 'translated';

  // Friendly starter categories (deletable by user)
  static const breakfast = 'breakfast';
  static const main = 'main';
  static const dessert = 'dessert';

  /// Only true system categories (exclude "all")
  static const systemOnly = <String>[fav, translated];

  /// Convenience: full set including "all"
  static const allSystem = <String>[all, ...systemOnly];

  /// Starter user categories you may auto-seed locally (deletable)
  static const starterUser = <String>[breakfast, main, dessert];
}

/// Extension helpers for quick checks.
extension CategoryHelpers on String {
  /// Normalises comparison to lowercase.
  String get _norm => toLowerCase();

  bool get isAllCategory => _norm == CategoryKeys.all;
  bool get isSystemCategory =>
      _norm == CategoryKeys.fav ||
      _norm == CategoryKeys.translated ||
      isAllCategory;
}
