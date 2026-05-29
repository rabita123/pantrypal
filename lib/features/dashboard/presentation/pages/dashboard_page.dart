import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:pantrypal/features/pantry/presentation/pages/pantry_page.dart';
import 'package:pantrypal/features/pantry/presentation/pages/shopping_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipes_page.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/presentation/pages/scan_page.dart';
import 'package:pantrypal/features/scan/presentation/pages/barcode_scanner_page.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pantrypal/features/settings/settings_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tonight_page.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          PantryPage(),
          RecipesPage(),
          ShoppingPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showScanOptions,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBtn(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, current: _tab, onTap: () => setState(() => _tab = 0)),
            _NavBtn(icon: Icons.kitchen_outlined, activeIcon: Icons.kitchen, label: 'Pantry', index: 1, current: _tab, onTap: () => setState(() => _tab = 1)),
            const SizedBox(width: 72),
            _NavBtn(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Recipes', index: 2, current: _tab, onTap: () => setState(() => _tab = 2)),
            _NavBtn(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Shopping', index: 3, current: _tab, onTap: () => setState(() => _tab = 3)),
          ],
        ),
      ),
    );
  }

  void _showScanOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add to Pantry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkInk : AppColors.ink),
            ),
            const SizedBox(height: 16),
            _ScanOption(
              icon: Icons.qr_code_scanner,
              title: 'Scan Barcode',
              subtitle: 'Point at any product barcode for instant lookup',
              onTap: () {
                Navigator.pop(context);
                _openBarcodeScanner();
              },
            ),
            const SizedBox(height: 10),
            _ScanOption(
              icon: Icons.document_scanner_outlined,
              title: 'Scan Receipt',
              subtitle: 'Scan a grocery receipt to add multiple items',
              onTap: () {
                Navigator.pop(context);
                _openReceiptScan();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkScanAccess() async {
    final service = sl<SubscriptionService>();
    if (!await service.canScan()) {
      if (!mounted) return;
      final cubit = context.read<SubscriptionCubit>();
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => BlocProvider.value(value: cubit, child: const PaywallPage()),
        ),
      );
      throw _PaywallShown();
    }
  }

  void _openBarcodeScanner() async {
    try {
      await _checkScanAccess();
    } on _PaywallShown {
      return;
    }
    if (!mounted) return;
    final item = await Navigator.push<PantryItem>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (item != null) {
      final service = sl<SubscriptionService>();
      await service.incrementScanCount();
      if (!mounted) return;
      context.read<PantryBloc>().add(PantryAddItem(item));
      context.read<SubscriptionCubit>().load();
    }
  }

  void _openReceiptScan() async {
    try {
      await _checkScanAccess();
    } on _PaywallShown {
      return;
    }
    if (!mounted) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (added == true) {
      final service = sl<SubscriptionService>();
      await service.incrementScanCount();
      if (!mounted) return;
      context.read<SubscriptionCubit>().load();
      context.read<PantryBloc>().add(PantryLoad());
    }
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.activeIcon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: active ? AppColors.primary : AppColors.inkLight),
            Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.primary : AppColors.inkLight, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, state) {
          if (state is PantryLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is PantryLoaded) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, isDark)),
                SliverToBoxAdapter(child: _buildStats(state, isDark)),
                SliverToBoxAdapter(child: _buildCookTonight(context, isDark)),
                if (state.expiringItems.isNotEmpty)
                  SliverToBoxAdapter(child: _buildExpiringSection(context, state, isDark)),
                SliverToBoxAdapter(child: _buildWasteChart(state, isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          }
          return _buildEmptyState(context);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting 👋', style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
                const SizedBox(height: 4),
                Text('PantryPal', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkInk : AppColors.ink)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(PantryLoaded state, bool isDark) {
    final stats = state.stats;
    final total = (stats['total'] as int?) ?? 0;
    final expiring = (stats['expiringSoon'] as int?) ?? 0;
    final expired = (stats['expired'] as int?) ?? 0;
    final wasted = (stats['wasted'] as int?) ?? 0;
    // Safe cast: SQLite may return int or double for SUM
    final wastedVal = ((stats['wastedValue'] as num?) ?? 0).toDouble();

    // When items were wasted but have no price (barcode-scanned items),
    // show the count so the stat is still meaningful
    final wastedDisplay = wastedVal > 0
        ? '\$${wastedVal.toStringAsFixed(2)}'
        : wasted > 0
            ? '$wasted item${wasted == 1 ? '' : 's'}'
            : '\$0.00';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _StatCard(label: 'In pantry', value: '$total items', icon: Icons.kitchen_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              _StatCard(label: 'Expiring soon', value: '$expiring items', icon: Icons.timer_outlined, color: AppColors.expiringSoon),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(label: 'Expired', value: '$expired items', icon: Icons.warning_amber_outlined, color: AppColors.expired),
              const SizedBox(width: 10),
              _StatCard(label: 'Wasted', value: wastedDisplay, icon: Icons.money_off_outlined, color: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCookTonight(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CookTonightPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Text('🍳', style: TextStyle(fontSize: 32)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What can I cook tonight?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('See recipes you can make right now', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSection(BuildContext context, PantryLoaded state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.expiringSoonSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.expiringSoon),
                    const SizedBox(width: 5),
                    Text(
                      '${state.expiringItems.length} expiring this week',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.expiringSoon),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...state.expiringItems.take(4).map((item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PantryItemCard(
                item: item,
                onConsumed: () => context.read<PantryBloc>().add(PantryMarkConsumed(item.id)),
                onWasted: () => context.read<PantryBloc>().add(PantryMarkWasted(item.id)),
              ),
            )),
      ],
    );
  }

  Widget _buildWasteChart(PantryLoaded state, bool isDark) {
    final stats = state.stats;
    final consumed = (stats['consumed'] as int?) ?? 0;
    final wasted = (stats['wasted'] as int?) ?? 0;
    final total = consumed + wasted;
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consumption overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkInk : AppColors.ink)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: consumed.toDouble(),
                      color: AppColors.primary,
                      title: consumed > 0 ? '$consumed\nConsumed' : '',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: wasted.toDouble(),
                      color: AppColors.expiringSoon,
                      title: wasted > 0 ? '$wasted\nWasted' : '',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.kitchen_outlined, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('Your pantry is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Scan a grocery receipt to add items instantly.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkInk : AppColors.ink)),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _PaywallShown implements Exception {}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ScanOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkInk : AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
