import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/dashboard/presentation/pages/home_tab.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/pages/pantry_page.dart';
import 'package:pantrypal/features/pantry/presentation/pages/shopping_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tab.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tonight_page.dart';
import 'package:pantrypal/shared/services/notification_service.dart';

/// The shell: four tabs, each answering one question.
///   Use first → what needs eating?   Pantry → what do I have?
///   Cook      → what can I make?     Shop     → what am I missing?
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    context.read<PantryBloc>().add(PantryLoad());
    NotificationService.onNotificationTap = (_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const CookTonightPage()),
        );
      }
    };
  }

  @override
  void dispose() {
    NotificationService.onNotificationTap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onOpenPantry: () => setState(() => _tab = 1)),
          const PantryPage(),
          const CookTab(),
          const ShoppingPage(),
        ],
      ),
      // Adding food only makes sense where the food is shown.
      floatingActionButton: _tab <= 1
          ? FloatingActionButton.extended(
              onPressed: () => AddFlow.start(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add food', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        indicatorColor: AppColors.primarySurface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer, color: AppColors.primary),
            label: 'Use first',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen, color: AppColors.primary),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu, color: AppColors.primary),
            label: 'Cook',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.primary),
            label: 'Shop',
          ),
        ],
      ),
    );
  }
}
