import 'package:flutter/material.dart';

import '../../features/closet/closet_screen.dart';
import '../../features/food/food_screen.dart';
import '../../features/food/models/breakfast_plan.dart';
import '../../features/money/money_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/today/today_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  BreakfastPlan? _todayBreakfastPlan;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      TodayScreen(breakfastPlan: _todayBreakfastPlan),
      const PlanScreen(),
      FoodScreen(
        breakfastPlan: _todayBreakfastPlan,
        onBreakfastPlanChanged: (plan) {
          setState(() {
            _todayBreakfastPlan = plan;
          });
        },
      ),
      const MoneyScreen(),
      const ClosetScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
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
