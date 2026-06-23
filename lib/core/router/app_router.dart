import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lima/core/i18n/app_i18n.dart';

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

String _routeLocation(
  String path, [
  Map<String, String> queryParameters = const {},
]) {
  final filteredQuery = Map<String, String>.from(queryParameters)
    ..removeWhere((_, value) => value.isEmpty);
  return Uri(
    path: path,
    queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
  ).toString();
}

/// Numeric path parameter, or null when missing/malformed (e.g. a deep link
/// like `/knowledge/drug/abc`) — callers fall back to [_RouteNotFoundScreen]
/// instead of crashing on `int.parse(...!)`.
int? _intParam(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '');

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen({this.fallbackLocation = '/home'});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(context.l10n.t('pageNotFound')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(fallbackLocation),
              child: Text(context.l10n.t('goBack')),
            ),
          ],
        ),
      ),
    );
  }
}

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
      if (isAuth && onLogin) return '/splash';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) => const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/history',
        redirect: (_, state) {
          final qp = state.uri.queryParameters;
          return Uri(
            path: '/visits/history',
            queryParameters: qp.isEmpty ? null : qp,
          ).toString();
        },
      ),
      GoRoute(
        path: '/history/visits',
        redirect: (_, state) {
          final qp = state.uri.queryParameters;
          return Uri(
            path: '/visits/history',
            queryParameters: qp.isEmpty ? null : qp,
          ).toString();
        },
      ),
      GoRoute(
        path: '/map',
        builder: (_, state) => _SystemBackFallback(
          fallbackLocation: '/visits',
          child: MapScreen(
            isPharmacy: state.uri.queryParameters['isPharmacy'] == 'true',
          ),
        ),
      ),
      GoRoute(
        path: '/basket',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/home',
          child: CartScreen(),
        ),
      ),
      GoRoute(
        path: '/drafts',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/home',
          child: CartScreen(),
        ),
      ),
      GoRoute(
        path: '/visits-schedule',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/plan',
          child: PlanScreen(),
        ),
      ),
      GoRoute(
        path: '/visit-summary',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/visits',
          child: VisitSummaryScreen(),
        ),
      ),
      GoRoute(
        path: '/sync',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/home',
          child: SyncScreen(),
        ),
      ),
      GoRoute(
        path: '/knowledge/drug/:drugId/materials',
        builder: (_, state) {
          final drugId = _intParam(state, 'drugId');
          if (drugId == null) {
            return const _RouteNotFoundScreen(fallbackLocation: '/knowledge');
          }
          return _SystemBackFallback(
            fallbackLocation: '/knowledge/drug/$drugId',
            child: MaterialViewerScreen(
              drugId: drugId,
              initialIndex:
                  int.tryParse(state.uri.queryParameters['index'] ?? '') ?? 0,
            ),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const _SystemBackFallback(
          fallbackLocation: '/home',
          child: NotificationsScreen(),
        ),
      ),

      // ── LPU doctor-select flow (без shell/навбара) ──────────────────────
      GoRoute(
        path: '/visits/lpu/detail/:orgId/doctors',
        builder: (_, state) {
          final orgId = _intParam(state, 'orgId');
          if (orgId == null) {
            return const _RouteNotFoundScreen(fallbackLocation: '/visits');
          }
          final orgName = state.uri.queryParameters['name'] ?? '';
          final preselect = int.tryParse(
            state.uri.queryParameters['preselect'] ?? '',
          );
          return _SystemBackFallback(
            fallbackLocation: _routeLocation('/visits/lpu/detail/$orgId', {
              'name': orgName,
            }),
            child: LpuDoctorSelectScreen(
              orgId: orgId,
              orgName: orgName,
              preselectedDoctorId: preselect,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':doctorId/detailing',
            builder: (_, state) {
              final orgId = _intParam(state, 'orgId');
              final doctorId = _intParam(state, 'doctorId');
              if (orgId == null || doctorId == null) {
                return const _RouteNotFoundScreen(fallbackLocation: '/visits');
              }
              final orgName = state.uri.queryParameters['orgName'] ?? '';
              return _SystemBackFallback(
                fallbackLocation: _routeLocation(
                  '/visits/lpu/detail/$orgId/doctors',
                  {'name': orgName},
                ),
                child: LpuDetailingScreen(
                  orgId: orgId,
                  doctorId: doctorId,
                  doctorName: state.uri.queryParameters['doctorName'] ?? '',
                  orgName: orgName,
                  doctorIds: state.uri.queryParameters['doctorIds'],
                  visitId: int.tryParse(
                    state.uri.queryParameters['visitId'] ?? '',
                  ),
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'complete',
                builder: (_, _) => const _SystemBackFallback(
                  fallbackLocation: '/visits',
                  child: LpuCompleteScreen(),
                ),
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
          GoRoute(
            path: '/home',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: _TopLevelTabBackGuard(child: HomeScreen()),
            ),
          ),
          GoRoute(
            path: '/plan',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: _TopLevelTabBackGuard(
                fallbackLocation: '/home',
                child: PlanScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/visits',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: _TopLevelTabBackGuard(
                fallbackLocation: '/home',
                child: VisitsHubScreen(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'lpu/detail/:orgId',
                builder: (_, state) {
                  final orgId = _intParam(state, 'orgId');
                  if (orgId == null) {
                    return const _RouteNotFoundScreen(
                      fallbackLocation: '/visits',
                    );
                  }
                  return LpuDetailScreen(
                    orgId: orgId,
                    orgName: state.uri.queryParameters['name'] ?? '',
                    orgAddress: state.uri.queryParameters['address'] ?? '',
                  );
                },
              ),
              GoRoute(
                path: 'pharmacy/detail/:pharmacyId',
                builder: (_, state) {
                  final pharmacyId = _intParam(state, 'pharmacyId');
                  if (pharmacyId == null) {
                    return const _RouteNotFoundScreen(
                      fallbackLocation: '/visits',
                    );
                  }
                  return PharmacyDetailScreen(
                    pharmacyId: pharmacyId,
                    pharmacyName: state.uri.queryParameters['name'] ?? '',
                  );
                },
                routes: [
                  GoRoute(
                    path: 'type',
                    builder: (_, state) {
                      final pharmacyId = _intParam(state, 'pharmacyId');
                      if (pharmacyId == null) {
                        return const _RouteNotFoundScreen(
                          fallbackLocation: '/visits',
                        );
                      }
                      return PharmacyTypeScreen(
                        pharmacyId: pharmacyId,
                        pharmacyName: state.uri.queryParameters['name'] ?? '',
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'order',
                        builder: (_, state) {
                          final pharmacyId = _intParam(state, 'pharmacyId');
                          if (pharmacyId == null) {
                            return const _RouteNotFoundScreen(
                              fallbackLocation: '/visits',
                            );
                          }
                          return PharmacyOrderScreen(
                            pharmacyId: pharmacyId,
                            pharmacyName:
                                state.uri.queryParameters['name'] ?? '',
                          );
                        },
                      ),
                      GoRoute(
                        path: 'stock',
                        builder: (_, state) {
                          final pharmacyId = _intParam(state, 'pharmacyId');
                          if (pharmacyId == null) {
                            return const _RouteNotFoundScreen(
                              fallbackLocation: '/visits',
                            );
                          }
                          return PharmacyStockScreen(
                            pharmacyId: pharmacyId,
                            pharmacyName:
                                state.uri.queryParameters['name'] ?? '',
                          );
                        },
                      ),
                      GoRoute(
                        path: 'circle',
                        builder: (_, state) {
                          final pharmacyId = _intParam(state, 'pharmacyId');
                          if (pharmacyId == null) {
                            return const _RouteNotFoundScreen(
                              fallbackLocation: '/visits',
                            );
                          }
                          return PharmaCircleScreen(
                            pharmacyId: pharmacyId,
                            pharmacyName:
                                state.uri.queryParameters['name'] ?? '',
                          );
                        },
                      ),
                      GoRoute(
                        path: 'bron',
                        builder: (_, state) {
                          final pharmacyId = _intParam(state, 'pharmacyId');
                          if (pharmacyId == null) {
                            return const _RouteNotFoundScreen(
                              fallbackLocation: '/visits',
                            );
                          }
                          return NewBronScreen(
                            pharmacyId: pharmacyId,
                            pharmacyName:
                                state.uri.queryParameters['name'] ?? '',
                          );
                        },
                      ),
                      GoRoute(
                        path: 'checkout',
                        builder: (_, state) {
                          final pharmacyId = _intParam(state, 'pharmacyId');
                          if (pharmacyId == null) {
                            return const _RouteNotFoundScreen(
                              fallbackLocation: '/visits',
                            );
                          }
                          final extra = state.extra;
                          final checkoutPayload = extra is Map<String, dynamic>
                              ? extra
                              : extra is Map
                              ? Map<String, dynamic>.from(extra)
                              : null;
                          return NewBronScreen(
                            pharmacyId: pharmacyId,
                            pharmacyName:
                                state.uri.queryParameters['name'] ?? '',
                            isCheckoutMode: true,
                            checkoutPayload: checkoutPayload,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/knowledge',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: _TopLevelTabBackGuard(
                fallbackLocation: '/home',
                child: KnowledgeScreen(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'drug/:drugId',
                builder: (_, state) {
                  final drugId = _intParam(state, 'drugId');
                  if (drugId == null) {
                    return const _RouteNotFoundScreen(
                      fallbackLocation: '/knowledge',
                    );
                  }
                  return DrugDetailScreen(drugId: drugId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: _TopLevelTabBackGuard(
                fallbackLocation: '/home',
                child: ProfileScreen(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'fav-doctors',
                builder: (_, _) => const FavDoctorsScreen(),
              ),
              GoRoute(
                path: 'fav-pharmacies',
                builder: (_, _) => const FavPharmaciesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _SystemBackFallback extends StatelessWidget {
  final String fallbackLocation;
  final Widget child;

  const _SystemBackFallback({
    required this.fallbackLocation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (context.canPop()) return false;
        context.go(fallbackLocation);
        return true;
      },
      child: child,
    );
  }
}

class _TopLevelTabBackGuard extends StatelessWidget {
  final String? fallbackLocation;
  final Widget child;

  const _TopLevelTabBackGuard({this.fallbackLocation, required this.child});

  @override
  Widget build(BuildContext context) {
    void goFallback() {
      final target = fallbackLocation;
      if (target != null) {
        context.go(target);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goFallback();
      },
      child: BackButtonListener(
        onBackButtonPressed: () async {
          goFallback();
          return true;
        },
        child: child,
      ),
    );
  }
}
