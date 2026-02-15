import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/food/models/meal_plan.dart';
import '../../features/food/models/recipe.dart';
import 'app_data_store.dart';

class FirestoreAppDataStore implements AppDataStore {
  FirestoreAppDataStore({
    FirebaseFirestore? firestore,
    this.documentPath = 'app_state/default',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String documentPath;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.doc(documentPath);

  @override
  Future<AppDataSnapshot?> load() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final recipesRaw = data['recipes'];
    final plannedMealsRaw = data['plannedMeals'];

    final recipes = <Recipe>[];
    if (recipesRaw is List) {
      for (final item in recipesRaw) {
        if (item is Map<String, dynamic>) {
          recipes.add(Recipe.fromMap(item));
        } else if (item is Map) {
          recipes.add(Recipe.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final plannedMeals = <MealCategory, PlannedMeal>{};
    if (plannedMealsRaw is Map<String, dynamic>) {
      plannedMealsRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final meal = PlannedMeal.fromMap({
            ...value,
            if (!value.containsKey('category')) 'category': key,
          });
          plannedMeals[meal.category] = meal;
        } else if (value is Map) {
          final normalized = Map<String, dynamic>.from(value);
          final meal = PlannedMeal.fromMap({
            ...normalized,
            if (!normalized.containsKey('category')) 'category': key,
          });
          plannedMeals[meal.category] = meal;
        }
      });
    }

    return AppDataSnapshot(recipes: recipes, plannedMeals: plannedMeals);
  }

  @override
  Future<void> save({
    required List<Recipe> recipes,
    required Map<MealCategory, PlannedMeal> plannedMeals,
  }) async {
    final serializedMeals = <String, dynamic>{};
    plannedMeals.forEach((category, meal) {
      serializedMeals[category.key] = meal.toMap();
    });

    await _doc.set({
      'recipes': recipes.map((recipe) => recipe.toMap()).toList(),
      'plannedMeals': serializedMeals,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
