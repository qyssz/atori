import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/app_controller.dart';
import '../features/timetable/presentation/timetable_page.dart';
import '../features/grades/presentation/grades_page.dart';
import '../features/second_class/presentation/activity_page.dart';
import '../features/settings/presentation/settings_page.dart';

const mainPaths = ['/timetable', '/grades', '/second-class', '/profile'];
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: mainPaths[ref.read(repositoryProvider).initialTab],
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/timetable'),
      ShellRoute(
        builder: (context, state, child) => _MainShell(state.uri.path, child),
        routes: [
          GoRoute(path: '/timetable', builder: (_, _) => const TimetablePage()),
          GoRoute(path: '/grades', builder: (_, _) => const GradesPage()),
          GoRoute(
            path: '/second-class',
            builder: (_, _) => const ActivityListPage(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/course/edit/:id',
        builder: (_, s) => CourseEditorPage(s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/course/detail/:id',
        builder: (_, s) => CourseDetailPage(s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/grade/edit/:id',
        builder: (_, s) => GradeEditorPage(s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/grades/analysis',
        builder: (_, _) => const GradeAnalysisPage(),
      ),
      GoRoute(
        path: '/second-class/detail/:id',
        builder: (_, s) => ActivityDetailPage(s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/volunteer',
        builder: (_, _) => const ActivityListPage(volunteer: true),
      ),
      GoRoute(
        path: '/volunteer/detail/:id',
        builder: (_, s) =>
            ActivityDetailPage(s.pathParameters['id']!, volunteer: true),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/data', builder: (_, _) => const DataManagementPage()),
      GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/timetable'),
          child: const Text('返回课表'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class AtoriApp extends ConsumerWidget {
  const AtoriApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider).settings;
    ThemeData theme(Brightness brightness) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Color(settings.seedColor),
        brightness: brightness,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: brightness == Brightness.light
            ? const Color(0xFFF5F6FB)
            : const Color(0xFF111420),
        appBarTheme: AppBarTheme(
          backgroundColor: brightness == Brightness.light
              ? const Color(0xFFF5F6FB)
              : const Color(0xFF111420),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF1D2231),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: '亚托莉',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: switch (settings.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: child!,
          ),
        ),
      ),
    );
  }
}

class _MainShell extends ConsumerWidget {
  const _MainShell(this.path, this.child);
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: mainPaths.indexOf(path).clamp(0, 3),
      onDestinationSelected: (index) {
        context.go(mainPaths[index]);
        ref.read(repositoryProvider).saveTab(index).catchError((Object _) {});
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: '课表',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: '成绩',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: '第二课堂',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: '我的',
        ),
      ],
    ),
  );
}
