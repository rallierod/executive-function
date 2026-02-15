enum MealCategory { breakfast, lunch, dinner, snack }

extension MealCategoryLabel on MealCategory {
  String get label {
    switch (this) {
      case MealCategory.breakfast:
        return 'Breakfast';
      case MealCategory.lunch:
        return 'Lunch';
      case MealCategory.dinner:
        return 'Dinner';
      case MealCategory.snack:
        return 'Snack';
    }
  }
}

class PlannedMeal {
  const PlannedMeal({
    required this.category,
    required this.mealName,
    required this.requiredTasks,
    required this.plannedDate,
    this.sourceRecipeUrl,
  });

  final MealCategory category;
  final String mealName;
  final List<String> requiredTasks;
  final DateTime plannedDate;
  final String? sourceRecipeUrl;

  bool isForDate(DateTime date) {
    return plannedDate.year == date.year &&
        plannedDate.month == date.month &&
        plannedDate.day == date.day;
  }
}
