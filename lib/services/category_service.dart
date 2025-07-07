import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryService {
  static const _boxName = 'customCategories';
  static const _systemCategories = ['Favourites', 'Translated'];

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static Future<List<String>> getAllCategories() async {
    final box = Hive.box<String>(_boxName);
    return box.values.toList();
  }

  static Future<void> saveCategory(String category) async {
    if (_systemCategories.contains(category)) {
      return; // Skip saving system categories
    }

    final box = Hive.box<String>(_boxName);
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

    final box = Hive.box<String>(_boxName);
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
    final box = Hive.box<String>(_boxName);
    await box.clear(); // Optional: reset local categories

    for (final doc in snapshot.docs) {
      final name = doc['name'];
      if (name is String && !_systemCategories.contains(name)) {
        await box.add(name);
      }
    }
  }
}
