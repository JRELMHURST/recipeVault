import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    await Hive.openBox<String>(_customBoxName);
    await Hive.openBox<String>(_hiddenDefaultBox);
  }

  static Future<List<String>> getAllCategories() async {
    final box = Hive.box<String>(_customBoxName);
    return box.values.toList();
  }

  static Future<void> saveCategory(String category) async {
    if (_systemCategories.contains(category)) {
      return; // Skip saving system categories
    }

    final box = Hive.box<String>(_customBoxName);
    if (!box.values.contains(category)) {
      await box.add(category);
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
    if (_systemCategories.contains(category)) {
      return; // Prevent deletion of system categories
    }

    final box = Hive.box<String>(_customBoxName);
    final key = box.keys.firstWhere(
      (k) => box.get(k) == category,
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
    final box = Hive.box<String>(_customBoxName);
    await box.clear();

    for (final doc in snapshot.docs) {
      final name = doc['name'];
      if (name is String && !_systemCategories.contains(name)) {
        await box.add(name);
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
}
