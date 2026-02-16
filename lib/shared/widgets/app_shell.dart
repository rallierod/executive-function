import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../features/closet/closet_screen.dart';
import '../../features/food/food_screen.dart';
import '../../features/food/models/meal_plan.dart';
import '../../features/food/models/recipe.dart';
import '../../features/money/money_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/tasks/default_task_templates.dart';
import '../../features/today/today_screen.dart';
import '../../features/today/models/task_template.dart';
import '../data/app_data_store.dart';
import '../data/firestore_app_data_store.dart';
import '../../ui/widgets/screen_shell.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _customTasksPrefsKey = 'custom_task_templates_v1';
  int _selectedIndex = 0;
  AppDataStore? _store;
  final Map<MealCategory, PlannedMeal> _todayMealPlans =
      <MealCategory, PlannedMeal>{};
  final List<Recipe> _recipes = <Recipe>[];
  final List<TaskTemplate> _customTasks = <TaskTemplate>[];
  bool _isLoading = true;
  String? _loadError;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[AppShell] Firebase app not initialized. Local-only mode.');
      setState(() {
        _isLoading = false;
        _loadError = 'Firebase not connected yet. Running local-only for now.';
      });
      return;
    }

    _store ??= FirestoreAppDataStore();

    try {
      debugPrint('[AppShell] Loading app state from Firestore...');
      final snapshot = await _store!.load();
      final customTasks = await _loadCustomTasksFromPrefs();
      if (!mounted) {
        return;
      }
      final loadedRecipes = snapshot?.recipes.length ?? 0;
      final loadedMeals = snapshot?.plannedMeals.length ?? 0;
      debugPrint(
        '[AppShell] Load success. recipes=$loadedRecipes plannedMeals=$loadedMeals',
      );
      setState(() {
        _todayMealPlans
          ..clear()
          ..addAll(
            snapshot?.plannedMeals ?? const <MealCategory, PlannedMeal>{},
          );
        _recipes
          ..clear()
          ..addAll(snapshot?.recipes ?? const <Recipe>[]);
        _customTasks
          ..clear()
          ..addAll(customTasks);
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('[AppShell] Load failed: $e');
      final customTasks = await _loadCustomTasksFromPrefs();
      if (!mounted) {
        return;
      }
      setState(() {
        _customTasks
          ..clear()
          ..addAll(customTasks);
        _isLoading = false;
        _loadError = 'Firebase load failed: $e';
      });
    }
  }

  Future<List<TaskTemplate>> _loadCustomTasksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = defaultTaskTemplates();
    const migratedCareIds = <String>{
      'custom_morning_maydo_start_laundry',
      'custom_morning_maydo_empty_dishwasher',
      'custom_afternoon_maydo_counter_reset',
      'custom_evening_maydo_load_dishwasher',
      'custom_evening_maydo_tidy_bathroom',
    };
    final raw = prefs.getString(_customTasksPrefsKey);
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return defaults;
      }
      final loaded = decoded
          .whereType<Map>()
          .map((item) => TaskTemplate.fromMap(Map<String, dynamic>.from(item)))
          .where((task) => task.id.isNotEmpty && task.title.trim().isNotEmpty)
          .toList()
          .cast<TaskTemplate>();
      final byId = <String, TaskTemplate>{
        for (final task in defaults) task.id: task,
      };
      for (final task in loaded) {
        if (migratedCareIds.contains(task.id)) {
          byId[task.id] = task.copyWith(phase: DayPhase.care);
        } else {
          byId[task.id] = task;
        }
      }
      return byId.values.toList();
    } catch (_) {
      return defaults;
    }
  }

  Future<void> _saveCustomTasksToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _customTasks.map((task) => task.toMap()).toList();
    await prefs.setString(_customTasksPrefsKey, jsonEncode(encoded));
  }

  Future<void> _persistState() async {
    if (_store == null) {
      debugPrint('[AppShell] Save skipped. Store unavailable.');
      return;
    }

    try {
      debugPrint(
        '[AppShell] Saving app state... recipes=${_recipes.length} plannedMeals=${_todayMealPlans.length}',
      );
      await _store!.save(
        recipes: List<Recipe>.unmodifiable(_recipes),
        plannedMeals: Map<MealCategory, PlannedMeal>.unmodifiable(
          _todayMealPlans,
        ),
      );
      debugPrint('[AppShell] Save success.');
      if (mounted) {
        setState(() {
          _syncError = null;
        });
      }
    } catch (e) {
      debugPrint('[AppShell] Save failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _syncError = 'Firebase save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = <Widget>[
      TodayScreen(plannedMeals: _todayMealPlans, customTasks: _customTasks),
      const PlanScreen(),
      FoodScreen(
        plannedMeals: _todayMealPlans,
        initialRecipes: _recipes,
        onRecipesChanged: (recipes) {
          setState(() {
            _recipes
              ..clear()
              ..addAll(recipes);
          });
          _persistState();
        },
        onMealPlanChanged: (category, plan) {
          setState(() {
            if (plan == null) {
              _todayMealPlans.remove(category);
            } else {
              _todayMealPlans[category] = plan;
            }
          });
          _persistState();
        },
      ),
      const MoneyScreen(),
      TasksScreen(
        templates: _customTasks,
        onChanged: (tasks) {
          setState(() {
            _customTasks
              ..clear()
              ..addAll(tasks);
          });
          _saveCustomTasksToPrefs();
        },
      ),
      const ClosetScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenShell(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (_loadError != null)
              MaterialBanner(
                content: Text(_loadError!),
                actions: [
                  TextButton(onPressed: _loadState, child: const Text('Retry')),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loadError = null;
                      });
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            if (_syncError != null)
              MaterialBanner(
                content: Text(_syncError!),
                actions: [
                  TextButton(
                    onPressed: _persistState,
                    child: const Text('Retry Save'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _syncError = null;
                      });
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Money',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            label: 'Closet',
          ),
        ],
      ),
    );
  }
}
