import 'package:flutter/foundation.dart'; // ✅ for debugPrint
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/model/category_model.dart';

class CategoryService {
  static const _customBoxName = 'customCategories';
  static const _hiddenDefaultBox = 'hiddenDefaultCategories';
  static const _systemCategories = ['Favourites', 'Translated'];
  static const _defaultCategories = [
    'Favourites',
    'Translated',
    'Breakfast',
    'Main',
    'Dessert',
  ];

  static Future<void> init() async {
    final customBox = await Hive.openBox(_customBoxName);
    await Hive.openBox<String>(_hiddenDefaultBox);

    // 🔁 Migrate legacy string-based values to CategoryModel
    final legacyKeys = customBox.keys
        .where((key) => customBox.get(key) is String)
        .toList();

    for (final key in legacyKeys) {
      final name = customBox.get(key) as String;
      await customBox.put(
        key,
        CategoryModel(id: key.toString(), name: name).toJson(),
      );
      debugPrint('🔁 Migrated legacy category "$name"');
    }
  }

  static Future<void> load() async {
    await getAllCategories();
    debugPrint('📂 CategoryService.load() called');
  }

  static Future<List<CategoryModel>> getAllCategories() async {
    final box = Hive.box(_customBoxName);

    return box.values
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveCategory(String category) async {
    if (_systemCategories.contains(category)) return;

    final box = Hive.box(_customBoxName);
    final alreadyExists = box.values.whereType<Map>().any(
      (e) => e['name'] == category,
    );

    if (!alreadyExists) {
      final categoryModel = CategoryModel(id: category, name: category);
      await box.add(categoryModel.toJson());
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories');
      await ref.doc(category).set({'name': category});
    }
  }

  static Future<void> deleteCategory(String category) async {
    if (_systemCategories.contains(category)) return;

    final box = Hive.box(_customBoxName);
    final key = box.keys.firstWhere(
      (k) => (box.get(k) as Map?)?['name'] == category,
      orElse: () => null,
    );
    if (key != null) {
      await box.delete(key);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories');
      await ref.doc(category).delete();
    }
  }

  static Future<void> syncFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories');

    final snapshot = await ref.get();
    final box = Hive.box(_customBoxName);
    await box.clear();

    for (final doc in snapshot.docs) {
      final name = doc['name'];
      if (name is String && !_systemCategories.contains(name)) {
        final categoryModel = CategoryModel(id: name, name: name);
        await box.add(categoryModel.toJson());
      }
    }
  }

  static Future<void> hideDefaultCategory(String category) async {
    if (!_defaultCategories.contains(category)) return;
    final box = Hive.box<String>(_hiddenDefaultBox);
    await box.put(category, category);
  }

  static Future<void> unhideDefaultCategory(String category) async {
    final box = Hive.box<String>(_hiddenDefaultBox);
    await box.delete(category);
  }

  static Future<List<String>> getHiddenDefaultCategories() async {
    final box = Hive.box<String>(_hiddenDefaultBox);
    return box.values.toList();
  }

  /// 🔄 Clear category cache from Hive (used on logout/reset)
  static Future<void> clearCache() async {
    try {
      if (Hive.isBoxOpen(_customBoxName)) {
        await Hive.box(_customBoxName).clear();
        debugPrint('🧹 Cleared $_customBoxName');
      }
      if (Hive.isBoxOpen(_hiddenDefaultBox)) {
        await Hive.box<String>(_hiddenDefaultBox).clear();
        debugPrint('🧹 Cleared $_hiddenDefaultBox');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category cache: $e');
    }
  }
}
