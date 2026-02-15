import '../models/recipe.dart';

class RecipeTextParser {
  static Recipe parse({
    required String rawText,
    required String sourceId,
    String sourceDomain = 'scanned recipe',
  }) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final title = lines.isEmpty ? 'Scanned recipe' : lines.first;
    final category = _detectCategory(rawText);
    final ingredients = _extractIngredients(lines);
    final steps = _extractSteps(lines);
    final allergens = _detectAllergens(rawText, ingredients);

    return Recipe(
      title: title,
      category: category,
      ingredients: ingredients,
      steps: steps,
      allergens: allergens,
      sourceUrl: sourceId,
      sourceDomain: sourceDomain,
    );
  }

  static String? _detectCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('breakfast')) {
      return 'Breakfast';
    }
    if (lower.contains('lunch')) {
      return 'Lunch';
    }
    if (lower.contains('dinner')) {
      return 'Dinner';
    }
    if (lower.contains('snack')) {
      return 'Snack';
    }
    return null;
  }

  static List<String> _extractIngredients(List<String> lines) {
    final startIndex = _indexOfHeading(lines, const [
      'ingredients',
      'ingredient',
    ]);
    final endIndex = _indexOfHeading(lines, const [
      'instructions',
      'directions',
      'method',
      'steps',
      'preparation',
    ]);

    if (startIndex != -1) {
      final start = startIndex + 1;
      final end = endIndex > start ? endIndex : lines.length;
      return _cleanList(lines.sublist(start, end));
    }

    final inferred = lines.where(_looksLikeIngredient).toList();
    return _cleanList(inferred);
  }

  static List<String> _extractSteps(List<String> lines) {
    final startIndex = _indexOfHeading(lines, const [
      'instructions',
      'directions',
      'method',
      'steps',
      'preparation',
    ]);

    if (startIndex != -1) {
      return _cleanList(lines.sublist(startIndex + 1));
    }

    final inferred = lines.where(_looksLikeStep).toList();
    return _cleanList(inferred);
  }

  static int _indexOfHeading(List<String> lines, List<String> headings) {
    for (var i = 0; i < lines.length; i++) {
      final normalized = lines[i].toLowerCase().replaceAll(':', '').trim();
      if (headings.any((h) => normalized == h)) {
        return i;
      }
    }
    return -1;
  }

  static bool _looksLikeIngredient(String line) {
    final lower = line.toLowerCase();
    return RegExp(r'^\d').hasMatch(lower) ||
        lower.contains('cup') ||
        lower.contains('tsp') ||
        lower.contains('tbsp') ||
        lower.contains('oz') ||
        lower.contains('lb');
  }

  static bool _looksLikeStep(String line) {
    return RegExp(r'^\d+[\)\.\-:]').hasMatch(line) ||
        line.toLowerCase().startsWith('step');
  }

  static List<String> _cleanList(List<String> input) {
    final deduped = <String>[];
    for (final raw in input) {
      final cleaned = raw
          .replaceFirst(RegExp(r'^[\-\*\u2022]\s*'), '')
          .replaceFirst(RegExp(r'^\d+[\)\.\-:]\s*'), '')
          .trim();
      if (cleaned.isEmpty || deduped.contains(cleaned)) {
        continue;
      }
      deduped.add(cleaned);
    }
    return deduped;
  }

  static List<String> _detectAllergens(String rawText, List<String> ingredients) {
    final haystack = '${rawText.toLowerCase()} ${ingredients.join(' ').toLowerCase()}';
    const terms = <String, List<String>>{
      'Milk': ['milk', 'butter', 'cream', 'cheese', 'yogurt'],
      'Egg': ['egg', 'eggs'],
      'Wheat/Gluten': ['wheat', 'flour', 'gluten'],
      'Soy': ['soy', 'soy sauce', 'tofu'],
      'Peanut': ['peanut'],
      'Tree Nut': ['almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'hazelnut'],
      'Fish': ['fish', 'salmon', 'tuna', 'cod'],
      'Shellfish': ['shrimp', 'crab', 'lobster', 'shellfish'],
      'Sesame': ['sesame', 'tahini'],
    };

    final detected = <String>[];
    terms.forEach((label, patterns) {
      if (patterns.any((p) => haystack.contains(p))) {
        detected.add(label);
      }
    });
    return detected;
  }
}
