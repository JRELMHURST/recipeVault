// lib/screens/recipe_vault/categories.dart

/// Keys used internally to represent categories.
/// UI layers will localise them into readable labels.
class CategoryKeys {
  static const all = 'All';
  static const fav = 'Favourites';
  static const translated = 'Translated';
  static const breakfast = 'Breakfast';
  static const main = 'Main';
  static const dessert = 'Dessert';

  /// All default system categories (except "All")
  static const defaults = <String>[fav, translated, breakfast, main, dessert];

  /// Convenience: full set including "All"
  static const allWithSystem = <String>[all, ...defaults];
}

/// Extension helpers for quick checks.
extension CategoryHelpers on String {
  /// Whether this category is one of the built-in defaults.
  bool get isDefaultCategory => CategoryKeys.defaults.contains(this);

  /// Whether this is the special "All" category.
  bool get isAllCategory => this == CategoryKeys.all;

  /// Whether this is system-defined (default or "All").
  bool get isSystemCategory => isDefaultCategory || isAllCategory;
}
