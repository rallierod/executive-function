import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/closet/closet_screen.dart';
import '../../features/food/food_screen.dart';
import '../../features/food/models/meal_plan.dart';
import '../../features/food/models/recipe.dart';
import '../../features/money/money_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/today/today_screen.dart';
import '../data/app_data_store.dart';
import '../data/firestore_app_data_store.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  AppDataStore? _store;
  final Map<MealCategory, PlannedMeal> _todayMealPlans = <MealCategory, PlannedMeal>{};
  final List<Recipe> _recipes = <Recipe>[];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    if (Firebase.apps.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Firebase not connected yet. Running local-only for now.';
      });
      return;
    }

    _store ??= FirestoreAppDataStore();

    try {
      final snapshot = await _store!.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _todayMealPlans
          ..clear()
          ..addAll(snapshot?.plannedMeals ?? const <MealCategory, PlannedMeal>{});
        _recipes
          ..clear()
          ..addAll(snapshot?.recipes ?? const <Recipe>[]);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Firebase not connected yet. Running local-only for now.';
      });
    }
  }

  Future<void> _persistState() async {
    if (_store == null) {
      return;
    }

    try {
      await _store!.save(
        recipes: List<Recipe>.unmodifiable(_recipes),
        plannedMeals: Map<MealCategory, PlannedMeal>.unmodifiable(_todayMealPlans),
      );
    } catch (_) {
      // Keep app usable even before Firebase is fully configured.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = <Widget>[
      TodayScreen(plannedMeals: _todayMealPlans),
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
      const ClosetScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_loadError != null)
            MaterialBanner(
              content: Text(_loadError!),
              actions: [
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
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), label: 'Food'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Money'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: 'Closet'),
        ],
      ),
    );
  }
}
