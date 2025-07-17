import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe_card_model.dart';

class RecipeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final String _globalCollection = 'global_recipes';

  static Future<List<RecipeCardModel>> getAllRecipes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userRecipeSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .get();

    final globalRecipeSnap = await _firestore
        .collection(_globalCollection)
        .get();

    final userRecipes = userRecipeSnap.docs
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();

    final globalRecipes = globalRecipeSnap.docs
        .map(
          (doc) => RecipeCardModel.fromJson({
            ...doc.data(),
            'isGlobal': true, // ✅ mark explicitly
          }),
        )
        .toList();

    return [...globalRecipes, ...userRecipes];
  }
}
