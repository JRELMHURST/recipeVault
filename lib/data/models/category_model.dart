import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class CategoryModel implements Comparable<CategoryModel> {
  /// Stable, unique key. Keep lowercased for comparisons.
  @HiveField(0)
  final String id;

  /// Display name (what users see).
  @HiveField(1)
  final String name;

  /// Prefer `const` to keep instances canonical in memory where possible.
  const CategoryModel({required this.id, required this.name})
    : assert(id != '', 'Category id must not be empty'),
      assert(name != '', 'Category name must not be empty');

  /// JSON (Map) constructor. Safe against legacy/partial payloads.
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['name'] ?? '').toString().trim();
    final rawName = (json['name'] ?? '').toString().trim();

    // Normalise: id is a stable key; use lower-case, hyphenated fallback.
    final id = _normaliseId(rawId.isNotEmpty ? rawId : rawName);
    final name = rawName.isNotEmpty ? rawName : rawId;

    if (id.isEmpty || name.isEmpty) {
      throw ArgumentError('Invalid CategoryModel JSON: $json');
    }
    return CategoryModel(id: id, name: name);
  }

  /// Legacy migration helper: some old boxes stored a plain String name.
  factory CategoryModel.fromLegacyString(String legacyName) {
    final name = legacyName.trim();
    final id = _normaliseId(name);
    if (id.isEmpty || name.isEmpty) {
      throw ArgumentError('Invalid legacy category name: "$legacyName"');
    }
    return CategoryModel(id: id, name: name);
  }

  /// Map for Firestore/local save.
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  /// Immutable update.
  CategoryModel copyWith({String? id, String? name}) =>
      CategoryModel(id: id ?? this.id, name: name ?? this.name);

  /// Sort by user-facing name (case-insensitive), then by id for stability.
  @override
  int compareTo(CategoryModel other) {
    final c = name.toLowerCase().compareTo(other.name.toLowerCase());
    return c != 0 ? c : id.compareTo(other.id);
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CategoryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // ---- internals ----

  static String _normaliseId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    // Lowercase, replace whitespace with hyphens, collapse repeats.
    final hyphened = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    // Remove leading/trailing hyphens just in case.
    return hyphened.replaceAll(RegExp('^-+|-+\$'), '');
  }
}
