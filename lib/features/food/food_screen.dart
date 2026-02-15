import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models/meal_plan.dart';
import 'models/recipe.dart';
import 'services/photo_recipe_import_service.dart';
import 'services/recipe_import_service.dart';
import 'shopping_list_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({
    super.key,
    required this.plannedMeals,
    required this.onMealPlanChanged,
    required this.initialRecipes,
    required this.onRecipesChanged,
  });

  final Map<MealCategory, PlannedMeal> plannedMeals;
  final void Function(MealCategory category, PlannedMeal? plan) onMealPlanChanged;
  final List<Recipe> initialRecipes;
  final ValueChanged<List<Recipe>> onRecipesChanged;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  late final TextEditingController _mealNameController;
  late final TextEditingController _tasksController;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  MealCategory _selectedCategory = MealCategory.breakfast;

  final List<Recipe> _recipes = <Recipe>[];
  final Set<String> _selectedRecipeUrls = <String>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController();
    _tasksController = TextEditingController();
    _recipes
      ..clear()
      ..addAll(widget.initialRecipes);
    _hydrateFromSelectedPlan();
  }

  @override
  void didUpdateWidget(covariant FoodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plannedMeals != widget.plannedMeals) {
      _hydrateFromSelectedPlan();
    }
    if (oldWidget.initialRecipes != widget.initialRecipes) {
      _recipes
        ..clear()
        ..addAll(widget.initialRecipes);
    }
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _tasksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  PlannedMeal? get _selectedPlan => widget.plannedMeals[_selectedCategory];

  void _hydrateFromSelectedPlan() {
    final plan = _selectedPlan;
    _mealNameController.text = plan?.mealName ?? '';
    _tasksController.text = plan == null ? '' : plan.requiredTasks.join('\n');
  }

  List<String> _parseTasks(String input) {
    final raw = input
        .split(RegExp(r'[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final deduped = <String>[];
    for (final item in raw) {
      if (!deduped.contains(item)) {
        deduped.add(item);
      }
    }
    return deduped;
  }

  void _saveMealPlan() {
    final mealName = _mealNameController.text.trim();
    final tasks = _parseTasks(_tasksController.text);

    if (mealName.isEmpty || tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a meal name and at least one task.')),
      );
      return;
    }

    widget.onMealPlanChanged(
      _selectedCategory,
      PlannedMeal(
        category: _selectedCategory,
        mealName: mealName,
        requiredTasks: tasks,
        plannedDate: DateTime.now(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedCategory.label} plan saved for today.')),
    );
  }

  Future<void> _openImportRecipeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _RecipeImportSheet(
          onImport: _importRecipeFromUrl,
          onImported: _handleImportedRecipe,
        );
      },
    );
  }

  void _handleImportedRecipe(Recipe recipe) {
    if (!mounted) {
      return;
    }
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      final existingIndex = _recipes.indexWhere((item) => item.sourceUrl == recipe.sourceUrl);
      if (existingIndex >= 0) {
        _recipes[existingIndex] = recipe;
      } else {
        _recipes.insert(0, recipe);
      }
    });
    widget.onRecipesChanged(List<Recipe>.unmodifiable(_recipes));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${recipe.title} (${_recipes.length} total)')),
    );
  }

  Future<Recipe> _importRecipeFromUrl(String url) async {
    return RecipeImportService.importRecipe(url);
  }

  Future<void> _importRecipeFromPhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo OCR is currently mobile-only.'),
        ),
      );
      return;
    }

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning photo...')),
      );

      final recipe = await PhotoRecipeImportService.importFromImagePath(image.path);
      if (!mounted) {
        return;
      }
      _handleImportedRecipe(recipe);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo import failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  void _toggleRecipeSelection(Recipe recipe) {
    setState(() {
      if (_selectedRecipeUrls.contains(recipe.sourceUrl)) {
        _selectedRecipeUrls.remove(recipe.sourceUrl);
      } else {
        _selectedRecipeUrls.add(recipe.sourceUrl);
      }
    });
  }

  Future<void> _openRecipeDetails(Recipe recipe) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RecipeDetailsSheet(
        recipe: recipe,
        isSelected: _selectedRecipeUrls.contains(recipe.sourceUrl),
        onToggleSelected: () => _toggleRecipeSelection(recipe),
        onPlanMeal: (category) => _planRecipeForCategory(recipe, category),
        onRecipeUpdated: _updateRecipe,
      ),
    );
  }

  void _updateRecipe(Recipe recipe) {
    setState(() {
      final index = _recipes.indexWhere((item) => item.sourceUrl == recipe.sourceUrl);
      if (index >= 0) {
        _recipes[index] = recipe;
      } else {
        _recipes.insert(0, recipe);
      }
    });
    widget.onRecipesChanged(List<Recipe>.unmodifiable(_recipes));
  }

  void _planRecipeForCategory(Recipe recipe, MealCategory category) {
    final tasks = _buildMealTasksFromRecipe(recipe, category);
    widget.onMealPlanChanged(
      category,
      PlannedMeal(
        category: category,
        mealName: recipe.title,
        requiredTasks: tasks,
        plannedDate: DateTime.now(),
        sourceRecipeUrl: recipe.sourceUrl,
      ),
    );

    if (_selectedCategory == category) {
      _mealNameController.text = recipe.title;
      _tasksController.text = tasks.join('\n');
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planned ${recipe.title} for ${category.label.toLowerCase()} today.')),
    );
  }

  List<String> _buildMealTasksFromRecipe(Recipe recipe, MealCategory category) {
    final tasks = <String>[
      ...recipe.ingredients.map((item) => 'Ingredient: ${item.trim()}'),
    ];

    if (recipe.steps.isNotEmpty) {
      final stepTasks = recipe.steps.take(4).map(_toTaskLabel).where((e) => e.isNotEmpty);
      tasks.addAll(stepTasks);
    } else if (recipe.ingredients.isNotEmpty) {
      tasks.add('Prep ingredients');
      tasks.add('Cook ${recipe.title}');
    } else {
      tasks.add('Cook ${recipe.title}');
    }

    tasks.add('Serve ${category.label.toLowerCase()}');
    return tasks.toSet().toList();
  }

  String _toTaskLabel(String step) {
    var text = step.trim();
    if (text.isEmpty) {
      return '';
    }
    if (text.length > 56) {
      text = '${text.substring(0, 56).trim()}...';
    }
    return text[0].toUpperCase() + text.substring(1);
  }

  void _generateShoppingList() {
    final selected = _recipes
        .where((recipe) => _selectedRecipeUrls.contains(recipe.sourceUrl))
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one recipe first.')),
      );
      return;
    }

    final aggregates = <String, _IngredientAggregate>{};
    for (final recipe in selected) {
      for (final ingredient in recipe.ingredients) {
        final parsed = _parseIngredient(ingredient);
        final key = parsed.key;
        if (key.isEmpty) {
          continue;
        }
        final aggregate = aggregates.putIfAbsent(
          key,
          () => _IngredientAggregate(displayName: parsed.name),
        );
        aggregate.add(parsed);
      }
    }

    final merged = <String>[];
    for (final aggregate in aggregates.values) {
      if (aggregate.amountsByUnit.isEmpty) {
        final count = aggregate.unquantifiedCount;
        merged.add(count > 1 ? '${aggregate.displayName} (x$count)' : aggregate.displayName);
        continue;
      }

      aggregate.amountsByUnit.forEach((unit, amount) {
        final amountLabel = _formatQuantity(amount);
        final unitLabel = _formatUnitLabel(unit, amount);
        var line = '$amountLabel $unitLabel ${aggregate.displayName}';
        if (aggregate.unquantifiedCount > 0) {
          line = '$line (+${aggregate.unquantifiedCount} item)';
        }
        merged.add(line);
      });
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(items: merged),
      ),
    );
  }

  _ParsedIngredient _parseIngredient(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const _ParsedIngredient.empty();
    }

    final match = RegExp(
      r'^\s*(\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:\.\d+)?)\s*([A-Za-z]+)?\s*(.*)$',
    ).firstMatch(raw);

    double? amount;
    String? unit;
    String name = raw;

    if (match != null) {
      amount = _parseQuantity(match.group(1)!);
      unit = _normalizeUnit(match.group(2));
      name = match.group(3)?.trim() ?? raw;
      if (name.toLowerCase().startsWith('of ')) {
        name = name.substring(3).trim();
      }
      if (name.isEmpty) {
        name = raw;
      }
    }

    final normalizedName = _normalizeIngredientName(name);
    final key = _ingredientKeyFromName(normalizedName);
    if (key.isEmpty) {
      return const _ParsedIngredient.empty();
    }

    return _ParsedIngredient(
      key: key,
      name: normalizedName,
      amount: amount,
      unit: unit,
    );
  }

  double? _parseQuantity(String raw) {
    final input = raw.trim();
    if (input.contains(' ')) {
      final parts = input.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final whole = double.tryParse(parts[0]) ?? 0;
        final fraction = _parseFraction(parts[1]) ?? 0;
        return whole + fraction;
      }
    }

    final fraction = _parseFraction(input);
    if (fraction != null) {
      return fraction;
    }
    return double.tryParse(input);
  }

  double? _parseFraction(String input) {
    final parts = input.split('/');
    if (parts.length != 2) {
      return null;
    }
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }

  String _normalizeIngredientName(String input) {
    var value = input.trim();
    value = value.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String _ingredientKeyFromName(String input) {
    var value = input.toLowerCase().trim();
    value = value.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (value.endsWith('es') && value.length > 4) {
      value = value.substring(0, value.length - 2);
    } else if (value.endsWith('s') && value.length > 3) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String? _normalizeUnit(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final value = raw.toLowerCase().trim();
    const unitMap = <String, String>{
      'cup': 'cup',
      'cups': 'cup',
      'tbsp': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tsp': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'lb': 'lb',
      'lbs': 'lb',
      'pound': 'lb',
      'pounds': 'lb',
      'g': 'g',
      'gram': 'g',
      'grams': 'g',
      'kg': 'kg',
      'ml': 'ml',
      'l': 'l',
      'can': 'can',
      'cans': 'can',
      'clove': 'clove',
      'cloves': 'clove',
      'slice': 'slice',
      'slices': 'slice',
      'package': 'package',
      'packages': 'package',
      'packet': 'packet',
      'packets': 'packet',
    };

    return unitMap[value];
  }

  String _formatQuantity(double value) {
    const denominators = <int>[2, 3, 4, 8];
    final whole = value.floor();
    final fractional = value - whole;

    if (fractional.abs() < 0.02) {
      return whole.toString();
    }

    int bestNum = 0;
    int bestDen = 1;
    var bestDiff = 9999.0;
    for (final den in denominators) {
      final num = (fractional * den).round();
      if (num <= 0 || num >= den) {
        continue;
      }
      final diff = (fractional - (num / den)).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestNum = num;
        bestDen = den;
      }
    }

    if (bestNum > 0 && bestDiff <= 0.04) {
      if (whole > 0) {
        return '$whole $bestNum/$bestDen';
      }
      return '$bestNum/$bestDen';
    }

    final label = value.toStringAsFixed(2);
    return label.replaceFirst(RegExp(r'\.00$'), '').replaceFirst(RegExp(r'0$'), '');
  }

  String _formatUnitLabel(String unit, double amount) {
    if ((amount - 1).abs() < 0.02) {
      return unit;
    }
    switch (unit) {
      case 'cup':
        return 'cups';
      case 'tbsp':
        return 'tbsp';
      case 'tsp':
        return 'tsp';
      case 'oz':
        return 'oz';
      case 'lb':
        return 'lb';
      case 'g':
        return 'g';
      case 'kg':
        return 'kg';
      case 'ml':
        return 'ml';
      case 'l':
        return 'l';
      default:
        return '${unit}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = _recipes
        .where((recipe) {
          if (_searchQuery.trim().isEmpty) {
            return true;
          }
          final q = _searchQuery.toLowerCase();
          return recipe.title.toLowerCase().contains(q) ||
              recipe.sourceDomain.toLowerCase().contains(q);
        })
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Import recipes and generate a basic shopping list.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _openImportRecipeSheet,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Import Recipe'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _importRecipeFromPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Import Photo'),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: _generateShoppingList,
                  child: const Text('Generate List'),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Imported recipes: ${filteredRecipes.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    if (filteredRecipes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No recipes yet. Tap Import Recipe to add one.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredRecipes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          final isSelected = _selectedRecipeUrls.contains(recipe.sourceUrl);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openRecipeDetails(recipe),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 160),
                                opacity: isSelected ? 0.75 : 1,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (recipe.imageUrl != null)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 10),
                                              child: _RecipeImageThumb(
                                                imageUrl: recipe.imageUrl!,
                                                size: 56,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              recipe.title,
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _toggleRecipeSelection(recipe),
                                            icon: Icon(
                                              isSelected
                                                  ? Icons.remove_shopping_cart_outlined
                                                  : Icons.add_shopping_cart_outlined,
                                              size: 16,
                                            ),
                                            label: Text(
                                              isSelected ? 'Selected' : 'Select',
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        recipe.sourceDomain,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      if (recipe.category != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Category: ${recipe.category}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      if (recipe.allergens.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Allergens: ${recipe.allergens.join(', ')}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        '${recipe.ingredients.length} ingredients',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to view details',
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    Text('Meal plan for Today', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: MealCategory.values.map((category) {
                        return ChoiceChip(
                          label: Text(category.label),
                          selected: _selectedCategory == category,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                              _hydrateFromSelectedPlan();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedPlan == null
                          ? 'Choose a recipe and plan it, or enter tasks manually.'
                          : 'Current ${_selectedCategory.label}: ${_selectedPlan!.mealName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mealNameController,
                      decoration: const InputDecoration(
                        labelText: 'Meal name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tasksController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '${_selectedCategory.label} tasks (one per line)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _saveMealPlan,
                          child: const Text('Save Meal Plan'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            _mealNameController.clear();
                            _tasksController.clear();
                            widget.onMealPlanChanged(_selectedCategory, null);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientAggregate {
  _IngredientAggregate({required this.displayName});

  final String displayName;
  final Map<String, double> amountsByUnit = <String, double>{};
  int unquantifiedCount = 0;

  void add(_ParsedIngredient ingredient) {
    if (ingredient.amount != null && ingredient.unit != null) {
      final current = amountsByUnit[ingredient.unit!] ?? 0;
      amountsByUnit[ingredient.unit!] = current + ingredient.amount!;
      return;
    }
    unquantifiedCount += 1;
  }
}

class _ParsedIngredient {
  const _ParsedIngredient({
    required this.key,
    required this.name,
    this.amount,
    this.unit,
  });

  const _ParsedIngredient.empty()
      : key = '',
        name = '',
        amount = null,
        unit = null;

  final String key;
  final String name;
  final double? amount;
  final String? unit;
}

class _RecipeImageThumb extends StatelessWidget {
  const _RecipeImageThumb({
    required this.imageUrl,
    this.size = 56,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _ImageFallback(size: size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return _ImageFallback(size: size, isLoading: true);
          },
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    required this.size,
    this.isLoading = false,
  });

  final double size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.restaurant_menu_outlined,
              size: size * 0.38,
              color: colorScheme.onSurfaceVariant,
            ),
    );
  }
}

class _RecipeDetailsSheet extends StatefulWidget {
  const _RecipeDetailsSheet({
    required this.recipe,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onPlanMeal,
    required this.onRecipeUpdated,
  });

  final Recipe recipe;
  final bool isSelected;
  final VoidCallback onToggleSelected;
  final ValueChanged<MealCategory> onPlanMeal;
  final ValueChanged<Recipe> onRecipeUpdated;

  @override
  State<_RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<_RecipeDetailsSheet> {
  late MealCategory _selectedPlanCategory;
  late String? _recipeCategory;

  @override
  void initState() {
    super.initState();
    _recipeCategory = widget.recipe.category;
    _selectedPlanCategory = _inferCategory(widget.recipe.category) ?? MealCategory.breakfast;
  }

  MealCategory? _inferCategory(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.toLowerCase();
    if (value.contains('breakfast')) {
      return MealCategory.breakfast;
    }
    if (value.contains('lunch')) {
      return MealCategory.lunch;
    }
    if (value.contains('dinner')) {
      return MealCategory.dinner;
    }
    if (value.contains('snack')) {
      return MealCategory.snack;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.recipe.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      widget.recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const _ImageFallback(size: 120),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(widget.recipe.title, style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(widget.recipe.sourceDomain, style: textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Category: ${_recipeCategory ?? 'Uncategorized'}',
                style: textTheme.bodyMedium,
              ),
              if (widget.recipe.allergens.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Allergens: ${widget.recipe.allergens.join(', ')}', style: textTheme.bodyMedium),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.recipe.totalTime != null) Chip(label: Text('Total ${widget.recipe.totalTime}')),
                  if (widget.recipe.prepTime != null) Chip(label: Text('Prep ${widget.recipe.prepTime}')),
                  if (widget.recipe.cookTime != null) Chip(label: Text('Cook ${widget.recipe.cookTime}')),
                  if (widget.recipe.servings != null) Chip(label: Text('Serves ${widget.recipe.servings}')),
                ],
              ),
              const SizedBox(height: 14),
              Text('Ingredients', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              if (widget.recipe.ingredients.isEmpty)
                Text('No ingredients found.', style: textTheme.bodyMedium)
              else
                ...widget.recipe.ingredients.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- $item', style: textTheme.bodyMedium),
                  ),
                ),
              const SizedBox(height: 14),
              Text('Instructions', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              if (widget.recipe.steps.isEmpty)
                Text('No instructions found.', style: textTheme.bodyMedium)
              else
                ...widget.recipe.steps.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${entry.key + 1}. ${entry.value}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text('Recipe category', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((category) {
                  return category;
                }).map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: (_recipeCategory ?? '').toLowerCase() == category.toLowerCase(),
                    onSelected: (selected) {
                      if (!selected) {
                        return;
                      }
                      setState(() {
                        _recipeCategory = category;
                      });
                      widget.onRecipeUpdated(widget.recipe.copyWith(category: category));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('Plan as', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MealCategory.values.map((category) {
                  return ChoiceChip(
                    label: Text(category.label),
                    selected: _selectedPlanCategory == category,
                    onSelected: (_) {
                      setState(() {
                        _selectedPlanCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => widget.onPlanMeal(_selectedPlanCategory),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text('Plan ${_selectedPlanCategory.label}'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: widget.onToggleSelected,
                    icon: Icon(
                      widget.isSelected
                          ? Icons.remove_shopping_cart_outlined
                          : Icons.add_shopping_cart_outlined,
                    ),
                    label: Text(
                      widget.isSelected
                          ? 'Remove from List'
                          : 'Add to Shopping List',
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeImportSheet extends StatefulWidget {
  const _RecipeImportSheet({
    required this.onImport,
    required this.onImported,
  });

  final Future<Recipe> Function(String url) onImport;
  final ValueChanged<Recipe> onImported;

  @override
  State<_RecipeImportSheet> createState() => _RecipeImportSheetState();
}

class _RecipeImportSheetState extends State<_RecipeImportSheet> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Please paste a recipe URL.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipe = await widget.onImport(url);
      if (!mounted) {
        return;
      }
      widget.onImported(recipe);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import Recipe', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Recipe URL',
                hintText: 'https://example.com/recipe',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _import(),
            ),
            const SizedBox(height: 10),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _import,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
