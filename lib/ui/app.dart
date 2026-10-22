import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'design.dart';
import 'pages.dart';
import 'rewards_pages.dart';
import 'lesson_screen.dart';

class OrbitApp extends ConsumerStatefulWidget {
  const OrbitApp({super.key});
  @override
  ConsumerState<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends ConsumerState<OrbitApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    router = GoRouter(
      refreshListenable: app,
      redirect: (context, state) =>
          app.recoveringPassword && state.uri.path != '/profile'
          ? '/profile'
          : null,
      initialLocation: app.onboarded ? '/' : '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const OnboardingPage(step: 0),
        ),
        GoRoute(
          path: '/language',
          builder: (_, _) => const OnboardingPage(step: 1),
        ),
        GoRoute(
          path: '/level',
          builder: (_, _) => const OnboardingPage(step: 2),
        ),
        GoRoute(
          path: '/goal',
          builder: (_, _) => const OnboardingPage(step: 3),
        ),
        GoRoute(
          path: '/lesson/:id',
          builder: (_, state) => LessonScreen(
            lessonId: state.pathParameters['id']!,
            demo: state.uri.queryParameters['demo'] == '1',
          ),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              OrbitShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/rewards', builder: (_, _) => const RewardsPage()),
            GoRoute(
              path: '/inventory',
              builder: (_, _) => const InventoryPage(),
            ),
            GoRoute(path: '/crew', builder: (_, _) => const CrewPage()),
            GoRoute(path: '/', builder: (_, _) => const HomePage()),
            GoRoute(path: '/words', builder: (_, _) => const WordsPage()),
            GoRoute(path: '/review', builder: (_, _) => const ReviewPage()),
            GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
            GoRoute(
              path: '/achievements',
              builder: (_, _) => const AchievementsPage(),
            ),
            GoRoute(path: '/quests', builder: (_, _) => const QuestsPage()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
            GoRoute(path: '/offline', builder: (_, _) => const OfflinePage()),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Вернуться на орбиту'),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'KVESMOS',
    debugShowCheckedModeBanner: false,
    theme: orbitTheme(Brightness.light),
    darkTheme: orbitTheme(Brightness.dark),
    themeMode: ref.watch(appProvider).theme,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}

class OrbitShell extends StatelessWidget {
  final String location;
  final Widget child;
  const OrbitShell({super.key, required this.location, required this.child});
  @override
  Widget build(BuildContext context) {
    final index = location == '/'
        ? 0
        : ['/words', '/review'].contains(location)
        ? 1
        : location == '/rewards'
        ? 2
        : ['/stats', '/achievements', '/quests'].contains(location)
        ? 3
        : 4;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrbitRobot(size: 38),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'KVESMOS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Офлайн-уроки',
            onPressed: () => context.go('/offline'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) =>
            context.go(['/', '/words', '/rewards', '/stats', '/profile'][i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.travel_explore),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            label: 'Слова',
          ),
          NavigationDestination(
            icon: Icon(Icons.redeem_rounded),
            label: 'Сундуки',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_rounded),
            label: 'Прогресс',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
