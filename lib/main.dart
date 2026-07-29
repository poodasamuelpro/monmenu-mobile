// lib/main.dart — MonMenu Manager
// Supabase init + go_router + providers + auth guard
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/realtime_service.dart';
import 'providers/commandes_provider.dart';
import 'providers/dashboard_provider.dart';
import 'theme/app_theme.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/commandes/commandes_screen.dart';
import 'screens/commandes/commande_detail_screen.dart';
import 'screens/menu/menu_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/plans/plans_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation portrait uniquement ────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Supabase Init ──────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // ── Hive (cache local) ─────────────────────────────────────────────────────
  await Hive.initFlutter();

  runApp(const MonMenuApp());
}

class MonMenuApp extends StatefulWidget {
  const MonMenuApp({super.key});

  @override
  State<MonMenuApp> createState() => _MonMenuAppState();
}

class _MonMenuAppState extends State<MonMenuApp> {
  late final AuthService _authService;
  late final ApiService _apiService;
  late final RealtimeService _realtimeService;
  late final CommandesProvider _commandesProvider;
  late final DashboardProvider _dashboardProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _apiService = ApiService(_authService);
    _realtimeService = RealtimeService();
    _commandesProvider = CommandesProvider(_apiService, _realtimeService);
    _dashboardProvider = DashboardProvider(_apiService);

    // ── go_router ─────────────────────────────────────────────────────────────
    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _authService,
      redirect: (context, state) async {
        final isLoggedIn = _authService.isAuthenticated;
        final isAuthRoute = state.uri.path.startsWith('/login') ||
            state.uri.path.startsWith('/forgot-password');

        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/dashboard/commandes';
        return null;
      },
      routes: [
        // Auth
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),

        // Dashboard shell
        GoRoute(
          path: '/dashboard',
          redirect: (_, __) => '/dashboard/commandes',
        ),
        GoRoute(
          path: '/dashboard/commandes',
          builder: (_, __) => const CommandesScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => CommandeDetailScreen(
                commandeId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/dashboard/home',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/dashboard/menu',
          builder: (_, __) => const MenuScreen(),
        ),
        GoRoute(
          path: '/dashboard/stats',
          builder: (_, __) => const StatsScreen(),
        ),
        GoRoute(
          path: '/dashboard/livreurs',
          builder: (_, __) => const _PlaceholderScreen(title: 'Livreurs'),
        ),
        GoRoute(
          path: '/dashboard/qrcode',
          builder: (_, __) => const _PlaceholderScreen(title: 'QR Code'),
        ),
        GoRoute(
          path: '/dashboard/codes-promo',
          builder: (_, __) => const _PlaceholderScreen(title: 'Codes promo'),
        ),
        GoRoute(
          path: '/dashboard/restaurant',
          builder: (_, __) => const _PlaceholderScreen(title: 'Mon restaurant'),
        ),
        GoRoute(
          path: '/dashboard/apparence',
          builder: (_, __) => const _PlaceholderScreen(title: 'Apparence'),
        ),
        GoRoute(
          path: '/dashboard/plans',
          builder: (_, __) => const PlansScreen(),
        ),
        GoRoute(
          path: '/dashboard/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/dashboard/change-password',
          builder: (_, __) => const ChangePasswordScreen(),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Page introuvable: ${state.uri}'),
            ],
          ),
        ),
      ),
    );

    // Restaurer session au démarrage
    _authService.tryRestoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        Provider.value(value: _apiService),
        ChangeNotifierProvider.value(value: _realtimeService),
        ChangeNotifierProvider.value(value: _commandesProvider),
        ChangeNotifierProvider.value(value: _dashboardProvider),
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        builder: (context, child) {
          // Forcer la police system (pas de crash si Inter non disponible)
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }
}

// ── Placeholder pour les écrans non encore implémentés ────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      drawer: Builder(builder: (_) {
        try {
          return const SizedBox.shrink();
        } catch (_) {
          return const SizedBox.shrink();
        }
      }),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 36, color: AppColors.gray300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cette section sera disponible prochainement',
              style: TextStyle(fontSize: 13, color: AppColors.gray400),
            ),
          ],
        ),
      ),
    );
  }
}
