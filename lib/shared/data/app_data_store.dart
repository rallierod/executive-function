import '../../features/food/models/meal_plan.dart';
import '../../features/food/models/recipe.dart';

class AppDataSnapshot {
  const AppDataSnapshot({required this.recipes, required this.plannedMeals});

  final List<Recipe> recipes;
  final Map<MealCategory, PlannedMeal> plannedMeals;
}

abstract class AppDataStore {
  Future<AppDataSnapshot?> load();

  Future<void> save({
    required List<Recipe> recipes,
    required Map<MealCategory, PlannedMeal> plannedMeals,
  });
}
