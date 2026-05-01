import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/plan/screens/plan_screen.dart';
import '../../features/visits/screens/visits_hub_screen.dart';
import '../../features/visits/screens/lpu/lpu_detail_screen.dart';
import '../../features/visits/screens/lpu/lpu_doctor_select_screen.dart';
import '../../features/visits/screens/lpu/lpu_detailing_screen.dart';
import '../../features/visits/screens/lpu/lpu_complete_screen.dart';
import '../../features/visits/screens/pharmacy/pharmacy_detail_screen.dart';
import '../../features/visits/screens/pharmacy/pharmacy_type_screen.dart';
import '../../features/visits/screens/pharmacy/pharmacy_order_screen.dart';
import '../../features/visits/screens/pharmacy/pharmacy_stock_screen.dart';
import '../../features/visits/screens/pharmacy/pharma_circle_screen.dart';
import '../../features/knowledge/screens/knowledge_screen.dart';
import '../../features/knowledge/screens/drug_detail_screen.dart';
import '../../features/knowledge/screens/material_viewer_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/fav_pharmacies_screen.dart';
import '../../features/visits/screens/history_screen.dart';
import '../../features/visits/screens/map_screen.dart';
import '../../features/visits/screens/new_bron_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/profile/screens/fav_doctors_screen.dart';
import '../../features/offline/screens/sync_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/visits/screens/visit_summary_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../shell/main_shell.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    debugPrint('[ROUTER_NOTIFIER] init');
    _ref.listen<AuthState>(authProvider, (prev, next) {
      debugPrint('[ROUTER_NOTIFIER] auth changed: ${next.status}');
      notifyListeners();
    });
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final _routerNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  debugPrint('[ROUTER] creating router');
  final notifier = ref.read(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: _routerNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final onSplash = state.matchedLocation == '/splash';
      if (onSplash) return null;

      final authState = ref.read(authProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoading =
          authState.status == AuthStatus.loading ||
          authState.status == AuthStatus.initial;
      final onLogin = state.matchedLocation == '/login';

      if (isLoading) return null;
      if (!isAuth && !onLogin) return '/login';
      if (isAuth && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/history',
        redirect: (_, state) {
          final qp = state.uri.queryParameters;
          return Uri(path: '/visits/history', queryParameters: qp.isEmpty ? null : qp).toString();
        },
      ),
      GoRoute(
        path: '/history/visits',
        redirect: (_, state) {
          final qp = state.uri.queryParameters;
          return Uri(path: '/visits/history', queryParameters: qp.isEmpty ? null : qp).toString();
        },
      ),
      GoRoute(
        path: '/map',
        builder: (_, state) => MapScreen(
          isPharmacy: state.uri.queryParameters['isPharmacy'] == 'true',
        ),
      ),
      GoRoute(path: '/basket', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/drafts', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/visits-schedule', builder: (_, __) => const PlanScreen()),
      GoRoute(path: '/visit-summary', builder: (_, __) => const VisitSummaryScreen()),
      GoRoute(path: '/sync', builder: (_, __) => const SyncScreen()),
      GoRoute(
        path: '/knowledge/drug/:drugId/materials',
        builder: (_, state) => MaterialViewerScreen(
          drugId: int.parse(state.pathParameters['drugId']!),
          initialIndex: int.tryParse(state.uri.queryParameters['index'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // ── LPU doctor-select flow (без shell/навбара) ──────────────────────
      GoRoute(
        path: '/visits/lpu/detail/:orgId/doctors',
        builder: (_, state) => LpuDoctorSelectScreen(
          orgId: int.parse(state.pathParameters['orgId']!),
          orgName: state.uri.queryParameters['name'] ?? '',
        ),
        routes: [
          GoRoute(
            path: ':doctorId/detailing',
            builder: (_, state) => LpuDetailingScreen(
              orgId: int.parse(state.pathParameters['orgId']!),
              doctorId: int.parse(state.pathParameters['doctorId']!),
              doctorName: state.uri.queryParameters['doctorName'] ?? '',
              orgName: state.uri.queryParameters['orgName'] ?? '',
              doctorIds: state.uri.queryParameters['doctorIds'],
              visitId: int.tryParse(state.uri.queryParameters['visitId'] ?? ''),
            ),
            routes: [
              GoRoute(
                path: 'complete',
                builder: (_, __) => const LpuCompleteScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Main shell with bottom nav (ShellRoute avoids StatefulShellRoute iOS crash) ──
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          debugPrint('[ROUTER] ShellRoute builder');
          return MainShell(child: child);
        },
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/plan', pageBuilder: (_, _) => const NoTransitionPage(child: PlanScreen())),
          GoRoute(
            path: '/visits',
            pageBuilder: (_, _) => const NoTransitionPage(child: VisitsHubScreen()),
            routes: [
              GoRoute(
                path: 'lpu/detail/:orgId',
                builder: (_, state) => LpuDetailScreen(
                  orgId: int.parse(state.pathParameters['orgId']!),
                  orgName: state.uri.queryParameters['name'] ?? '',
                  orgAddress: state.uri.queryParameters['address'] ?? '',
                ),
              ),
              GoRoute(
                path: 'pharmacy/detail/:pharmacyId',
                builder: (_, state) => PharmacyDetailScreen(
                  pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                  pharmacyName: state.uri.queryParameters['name'] ?? '',
                ),
                routes: [
                  GoRoute(
                    path: 'type',
                    builder: (_, state) => PharmacyTypeScreen(
                      pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                      pharmacyName: state.uri.queryParameters['name'] ?? '',
                    ),
                    routes: [
                      GoRoute(
                        path: 'order',
                        builder: (_, state) => PharmacyOrderScreen(
                          pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                          pharmacyName: state.uri.queryParameters['name'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'stock',
                        builder: (_, state) => PharmacyStockScreen(
                          pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                          pharmacyName: state.uri.queryParameters['name'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'circle',
                        builder: (_, state) => PharmaCircleScreen(
                          pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                          pharmacyName: state.uri.queryParameters['name'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'bron',
                        builder: (_, state) => NewBronScreen(
                          pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                          pharmacyName: state.uri.queryParameters['name'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'checkout',
                        builder: (_, state) => NewBronScreen(
                          pharmacyId: int.parse(state.pathParameters['pharmacyId']!),
                          pharmacyName: state.uri.queryParameters['name'] ?? '',
                          isCheckoutMode: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'history',
                builder: (_, __) => const HistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/knowledge',
            pageBuilder: (_, _) => const NoTransitionPage(child: KnowledgeScreen()),
            routes: [
              GoRoute(
                path: 'drug/:drugId',
                builder: (_, state) => DrugDetailScreen(
                  drugId: int.parse(state.pathParameters['drugId']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, _) => const NoTransitionPage(child: ProfileScreen()),
            routes: [
              GoRoute(path: 'fav-doctors', builder: (_, __) => const FavDoctorsScreen()),
              GoRoute(path: 'fav-pharmacies', builder: (_, __) => const FavPharmaciesScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
