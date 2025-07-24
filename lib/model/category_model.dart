import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class CategoryModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  CategoryModel({required this.id, required this.name});

  /// ✅ Construct from Firestore or Map-based JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? json['name'], // Fallback to name if id is missing
      name: json['name'],
    );
  }

  /// 🔁 Convert back to Map for Firestore sync or local save
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
