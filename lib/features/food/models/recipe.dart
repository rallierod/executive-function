class Recipe {
  const Recipe({
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.sourceUrl,
    required this.sourceDomain,
    this.totalTime,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.imageUrl,
  });

  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String sourceUrl;
  final String sourceDomain;
  final String? totalTime;
  final String? prepTime;
  final String? cookTime;
  final String? servings;
  final String? imageUrl;

  factory Recipe.fromJsonLd(Map<String, dynamic> json, String sourceUrl) {
    final name = _asString(json['name']) ?? 'Untitled recipe';
    final ingredients = _asStringList(json['recipeIngredient']);
    final instructions = _parseInstructions(json['recipeInstructions']);
    final imageUrl = _extractImage(json['image']);
    final uri = Uri.tryParse(sourceUrl);

    return Recipe(
      title: name,
      ingredients: ingredients,
      steps: instructions,
      sourceUrl: sourceUrl,
      sourceDomain: uri?.host.isNotEmpty == true ? uri!.host : 'unknown source',
      totalTime: _asString(json['totalTime']),
      prepTime: _asString(json['prepTime']),
      cookTime: _asString(json['cookTime']),
      servings: _asString(json['recipeYield']),
      imageUrl: imageUrl,
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is List && value.isNotEmpty) {
      return _asString(value.first);
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map(_asString)
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _parseInstructions(dynamic value) {
    if (value is String) {
      return value
          .split(RegExp(r'\n+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    if (value is List) {
      final output = <String>[];
      for (final item in value) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            output.add(trimmed);
          }
          continue;
        }
        if (item is Map<String, dynamic>) {
          final text = _asString(item['text']) ?? _asString(item['name']);
          if (text != null && text.trim().isNotEmpty) {
            output.add(text.trim());
          }
        }
      }
      return output;
    }

    if (value is Map<String, dynamic>) {
      final text = _asString(value['text']) ?? _asString(value['name']);
      return text == null ? const [] : [text];
    }

    return const [];
  }

  static String? _extractImage(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List && value.isNotEmpty) {
      return _extractImage(value.first);
    }
    if (value is Map<String, dynamic>) {
      return _asString(value['url']) ?? _asString(value['contentUrl']);
    }
    return null;
  }
}
