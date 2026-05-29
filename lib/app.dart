import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:pantrypal/features/onboarding/onboarding_page.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PantryBloc>(create: (_) => sl<PantryBloc>()),
        BlocProvider<RecipeBloc>(create: (_) => sl<RecipeBloc>()),
        // Provided here so PaywallPage (pushed modally from _RootPage) can read it
        BlocProvider<SubscriptionCubit>(create: (_) => sl<SubscriptionCubit>()..load()),
      ],
      child: MaterialApp(
        title: 'PantryPal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _RootPage(),
      ),
    );
  }
}

class _RootPage extends StatefulWidget {
  const _RootPage();

  @override
  State<_RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<_RootPage> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    setState(() => _onboardingDone = done);
    if (done) _maybeShowPaywall();
  }

  Future<void> _maybeShowPaywall() async {
    final service = sl<SubscriptionService>();

    // Premium users never see the paywall
    if (await service.isPremium()) return;

    if (!mounted) return;
    final cubit = context.read<SubscriptionCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: const PaywallPage(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!_onboardingDone!) {
      return OnboardingPage(
        onDone: () {
          setState(() => _onboardingDone = true);
          _maybeShowPaywall();
        },
      );
    }
    return const DashboardPage();
  }
}
