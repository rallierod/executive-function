import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/breakfast_plan.dart';
import 'models/recipe.dart';
import 'shopping_list_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({
    super.key,
    required this.breakfastPlan,
    required this.onBreakfastPlanChanged,
  });

  final BreakfastPlan? breakfastPlan;
  final ValueChanged<BreakfastPlan?> onBreakfastPlanChanged;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  late final TextEditingController _mealNameController;
  late final TextEditingController _tasksController;
  final TextEditingController _searchController = TextEditingController();

  final List<Recipe> _recipes = <Recipe>[];
  final Set<String> _selectedRecipeUrls = <String>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController();
    _tasksController = TextEditingController();
    _hydrateFromPlan(widget.breakfastPlan);
  }

  @override
  void didUpdateWidget(covariant FoodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breakfastPlan != widget.breakfastPlan) {
      _hydrateFromPlan(widget.breakfastPlan);
    }
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _tasksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _hydrateFromPlan(BreakfastPlan? plan) {
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

  void _saveBreakfastPlan() {
    final mealName = _mealNameController.text.trim();
    final tasks = _parseTasks(_tasksController.text);

    if (mealName.isEmpty || tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a meal name and at least one breakfast task.')),
      );
      return;
    }

    widget.onBreakfastPlanChanged(
      BreakfastPlan(
        mealName: mealName,
        requiredTasks: tasks,
        plannedDate: DateTime.now(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Breakfast plan saved for today.')),
    );
  }

  Future<void> _openImportRecipeSheet() async {
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _RecipeImportSheet(
          onImport: _importRecipeFromUrl,
        );
      },
    );

    if (recipe == null || !mounted) {
      return;
    }

    setState(() {
      final existingIndex = _recipes.indexWhere((item) => item.sourceUrl == recipe.sourceUrl);
      if (existingIndex >= 0) {
        _recipes[existingIndex] = recipe;
      } else {
        _recipes.insert(0, recipe);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${recipe.title}')),
    );
  }

  Future<Recipe> _importRecipeFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('Please enter a valid http/https URL.');
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch recipe page (${response.statusCode}).');
    }

    final html = response.body;
    final scripts = _extractJsonLdScripts(html);
    if (scripts.isEmpty) {
      throw Exception('No JSON-LD scripts found on this page.');
    }

    for (final script in scripts) {
      try {
        final decoded = jsonDecode(script);
        final recipeNode = _findRecipeNode(decoded);
        if (recipeNode != null) {
          return Recipe.fromJsonLd(recipeNode, uri.toString());
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('No Recipe schema found in JSON-LD.');
  }

  List<String> _extractJsonLdScripts(String html) {
    final regex = RegExp(
      r'''<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
      multiLine: true,
    );

    return regex
        .allMatches(html)
        .map((match) => (match.group(1) ?? '').trim())
        .where((block) => block.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _findRecipeNode(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final found = _findRecipeNode(item);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    if (node is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(node);
    if (_isRecipeType(map['@type'])) {
      return map;
    }

    final graph = map['@graph'];
    if (graph != null) {
      final found = _findRecipeNode(graph);
      if (found != null) {
        return found;
      }
    }

    for (final value in map.values) {
      final found = _findRecipeNode(value);
      if (found != null) {
        return found;
      }
    }

    return null;
  }

  bool _isRecipeType(dynamic typeField) {
    if (typeField is String) {
      return typeField.toLowerCase() == 'recipe';
    }
    if (typeField is List) {
      return typeField.any((item) => item.toString().toLowerCase() == 'recipe');
    }
    return false;
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

    final merged = <String>[];
    final seen = <String>{};
    for (final recipe in selected) {
      for (final ingredient in recipe.ingredients) {
        final normalized = ingredient.trim().toLowerCase();
        if (normalized.isEmpty || seen.contains(normalized)) {
          continue;
        }
        seen.add(normalized);
        merged.add(ingredient.trim());
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(items: merged),
      ),
    );
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
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: _generateShoppingList,
                  child: const Text('Generate List'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filteredRecipes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final recipe = filteredRecipes[index];
                  final isSelected = _selectedRecipeUrls.contains(recipe.sourceUrl);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleRecipeSelection(recipe),
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
                              Text(
                                recipe.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recipe.sourceDomain,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${recipe.ingredients.length} ingredients',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('Breakfast plan for Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _mealNameController,
              decoration: const InputDecoration(
                labelText: 'Breakfast meal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tasksController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Breakfast tasks (one per line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _saveBreakfastPlan,
                  child: const Text('Save Breakfast Plan'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    _mealNameController.clear();
                    _tasksController.clear();
                    widget.onBreakfastPlanChanged(null);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeImportSheet extends StatefulWidget {
  const _RecipeImportSheet({required this.onImport});

  final Future<Recipe> Function(String url) onImport;

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
      Navigator.of(context).pop(recipe);
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
