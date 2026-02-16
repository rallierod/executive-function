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

extension MealCategoryCodec on MealCategory {
  String get key => name;

  static MealCategory fromKey(String value) {
    return MealCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => MealCategory.breakfast,
    );
  }
}

class PlannedMeal {
  const PlannedMeal({
    required this.category,
    required this.mealName,
    required this.requiredTasks,
    required this.plannedDate,
    this.sourceRecipeUrl,
    this.estimatedPrepMinutes,
    this.estimatedCookMinutes,
    this.estimatedGatherMinutes,
  });

  final MealCategory category;
  final String mealName;
  final List<String> requiredTasks;
  final DateTime plannedDate;
  final String? sourceRecipeUrl;
  final int? estimatedPrepMinutes;
  final int? estimatedCookMinutes;
  final int? estimatedGatherMinutes;

  bool isForDate(DateTime date) {
    return plannedDate.year == date.year &&
        plannedDate.month == date.month &&
        plannedDate.day == date.day;
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category.key,
      'mealName': mealName,
      'requiredTasks': requiredTasks,
      'plannedDate': plannedDate.toIso8601String(),
      'sourceRecipeUrl': sourceRecipeUrl,
      'estimatedPrepMinutes': estimatedPrepMinutes,
      'estimatedCookMinutes': estimatedCookMinutes,
      'estimatedGatherMinutes': estimatedGatherMinutes,
    };
  }

  factory PlannedMeal.fromMap(Map<String, dynamic> map) {
    final categoryRaw =
        map['category']?.toString() ?? MealCategory.breakfast.key;
    final requiredTasksRaw = map['requiredTasks'];
    return PlannedMeal(
      category: MealCategoryCodec.fromKey(categoryRaw),
      mealName: map['mealName']?.toString() ?? '',
      requiredTasks: requiredTasksRaw is List
          ? requiredTasksRaw
                .map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList()
          : const <String>[],
      plannedDate:
          DateTime.tryParse(map['plannedDate']?.toString() ?? '') ??
          DateTime.now(),
      sourceRecipeUrl: map['sourceRecipeUrl']?.toString(),
      estimatedPrepMinutes: int.tryParse(
        map['estimatedPrepMinutes']?.toString() ?? '',
      ),
      estimatedCookMinutes: int.tryParse(
        map['estimatedCookMinutes']?.toString() ?? '',
      ),
      estimatedGatherMinutes: int.tryParse(
        map['estimatedGatherMinutes']?.toString() ?? '',
      ),
    );
  }
}
