class BreakfastPlan {
  const BreakfastPlan({
    required this.mealName,
    required this.requiredTasks,
    required this.plannedDate,
  });

  final String mealName;
  final List<String> requiredTasks;
  final DateTime plannedDate;

  bool isForDate(DateTime date) {
    return plannedDate.year == date.year &&
        plannedDate.month == date.month &&
        plannedDate.day == date.day;
  }
}
