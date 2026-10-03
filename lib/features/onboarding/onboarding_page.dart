import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/scan/scan_launcher.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';
import 'package:pantrypal/shared/services/notification_service.dart';
import 'package:pantrypal/shared/widgets/added_summary.dart';

/// First launch, built around one goal: real food in the app within a minute.
///
///   1. Welcome — the promise, in one screen.
///   2. Fill your kitchen — receipt, fridge photo, or tap what you have.
///   3. Your head start — what to use first, what it's worth, what to cook.
///   4. Reminders — asked for with a real example from their own food.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  List<PantryItem> _added = [];
  List<Recipe> _recipes = [];
  bool _busy = false;

  static const _fill = 1, _result = 2, _reminders = 3;

  static const _stepNames = ['welcome', 'fill', 'result', 'reminders'];

  @override
  void initState() {
    super.initState();
    Analytics.track('onboarding_step', {'step': 'welcome'});
  }

  void _goTo(int page) {
    Analytics.track('onboarding_step', {'step': _stepNames[page]});
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _fillWith(Future<List<PantryItem>> Function(BuildContext) how,
      {required String method}) async {
    if (_busy) return;
    Analytics.track('onboarding_fill_choice', {'method': method});
    setState(() => _busy = true);
    final items = await how(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (items.isEmpty) {
      Analytics.track('onboarding_fill_backed_out', {'method': method});
      return; // user backed out — stay on this step
    }
    final recipes = await AddedSummarySheet.loadRecipes(context);
    if (!mounted) return;
    setState(() {
      _added = items;
      _recipes = recipes;
    });
    _goTo(_result);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    Analytics.track('onboarding_completed', {'added': _added.length});
    Analytics.instance.flush();
    widget.onDone();
  }

  Future<void> _enableReminders() async {
    final granted = await NotificationService.instance.requestPermission();
    Analytics.track('notification_permission', {'granted': granted, 'where': 'onboarding'});
    await _finish();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onNext: () => _goTo(_fill)),
          _FillPage(
            busy: _busy,
            onReceipt: () => _fillWith(ScanLauncher.receipt, method: 'receipt'),
            onFridge: () => _fillWith(ScanLauncher.fridge, method: 'fridge'),
            onTap: () => _fillWith((c) => ScanLauncher.tapPicker(c), method: 'tap'),
            onSkip: () {
              Analytics.track('onboarding_fill_skipped');
              _goTo(_reminders);
            },
          ),
          _ResultPage(
            added: _added,
            recipes: _recipes,
            onNext: () => _goTo(_reminders),
          ),
          _RemindersPage(
            example: PantryInsights.useFirst(_added).firstOrNull,
            onAllow: _enableReminders,
            onSkip: _finish,
          ),
        ],
      ),
    );
  }
}

// ── 1. Welcome ────────────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.kitchen_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Know what to eat\nbefore it goes off.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Snap a receipt. PantryPal sorts your food, shows what to use first and what to cook tonight.',
                    style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.85), height: 1.55),
                  ),
                  const Spacer(),
                  const _Step(emoji: '📸', text: 'Receipt to pantry in seconds'),
                  const SizedBox(height: 10),
                  const _Step(emoji: '⏰', text: 'See what to use first'),
                  const SizedBox(height: 10),
                  const _Step(emoji: '🍳', text: 'Cook from what you have'),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Get started',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Free to start · No account needed',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String emoji, text;
  const _Step({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── 2. Fill your kitchen ──────────────────────────────────────────────────────

class _FillPage extends StatelessWidget {
  final bool busy;
  final VoidCallback onReceipt, onFridge, onTap, onSkip;
  const _FillPage({
    required this.busy,
    required this.onReceipt,
    required this.onFridge,
    required this.onTap,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What's in your kitchen?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick the fastest way. You can add the rest any time.',
              style: TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            _BigTile(
              emoji: '📸',
              title: 'Scan a receipt',
              subtitle: 'A whole shop added in about 10 seconds',
              badge: 'Fastest',
              primary: true,
              onTap: busy ? null : onReceipt,
            ),
            const SizedBox(height: 12),
            _BigTile(
              emoji: '🧊',
              title: 'Photo of your fridge',
              subtitle: 'AI spots what is inside',
              onTap: busy ? null : onFridge,
            ),
            const SizedBox(height: 12),
            _BigTile(
              emoji: '👆',
              title: 'Tap what you have',
              subtitle: 'No receipt? Pick from common foods',
              onTap: busy ? null : onTap,
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: busy ? null : onSkip,
                child: const Text('Skip for now', style: TextStyle(color: AppColors.inkMuted, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final String? badge;
  final bool primary;
  final VoidCallback? onTap;
  const _BigTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.ink;
    final sub = primary ? Colors.white.withValues(alpha: 0.85) : AppColors.inkMuted;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: primary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.all(primary ? 20 : 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: primary ? null : Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            child: Row(
              children: [
                Text(emoji, style: TextStyle(fontSize: primary ? 36 : 30)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                style: TextStyle(fontSize: primary ? 19 : 16, fontWeight: FontWeight.w800, color: fg)),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(badge!,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: sub)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3. Head start ─────────────────────────────────────────────────────────────

class _ResultPage extends StatelessWidget {
  final List<PantryItem> added;
  final List<Recipe> recipes;
  final VoidCallback onNext;
  const _ResultPage({required this.added, required this.recipes, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            const Text(
              'Your kitchen is set up',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: added.isEmpty
                    ? const SizedBox.shrink()
                    : AddedSummary(added: added, pantry: added, recipes: recipes),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 4. Reminders ──────────────────────────────────────────────────────────────

class _RemindersPage extends StatelessWidget {
  final PantryItem? example;
  final VoidCallback onAllow, onSkip;
  const _RemindersPage({required this.example, required this.onAllow, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final e = example;
    final title = e == null
        ? '🥛 Milk expires tomorrow'
        : '${foodEmoji(e.name, e.category)} ${e.name} — use it ${PantryInsights.shortWhen(e).toLowerCase()}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            const Text(
              'One nudge, right on time',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'A single evening reminder when something needs using — with a dinner idea. Never one per item.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.6),
            ),
            const SizedBox(height: 28),
            _NotifPreview(title: title, body: 'Tap for a dinner idea that uses it.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onAllow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Remind me', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSkip,
              child: const Text('Not now', style: TextStyle(color: AppColors.inkMuted, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifPreview extends StatelessWidget {
  final String title, body;
  const _NotifPreview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.kitchen_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
