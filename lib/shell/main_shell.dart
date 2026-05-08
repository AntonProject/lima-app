import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lima/core/providers/sync_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/widgets/offline_banner.dart';
import 'nav_bar_layout.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  Timer? _offlineToastTimer;
  String _lastOfflineToastPath = '';
  bool _showOfflineToast = false;

  static const _tabPaths = [
    '/home',
    '/plan',
    '/visits',
    '/knowledge',
    '/profile',
  ];

  int _indexFromLocation(String location) {
    for (int i = _tabPaths.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabPaths[i])) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _offlineToastTimer?.cancel();
    super.dispose();
  }

  void _showTransientOfflineToast() {
    _offlineToastTimer?.cancel();
    if (mounted && !_showOfflineToast) {
      setState(() => _showOfflineToast = true);
    }
    _offlineToastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showOfflineToast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOfflineProvider, (previous, next) async {
      if (previous == true && next == false) {
        await ref.read(syncProvider.notifier).reconcileInBackground();
        _offlineToastTimer?.cancel();
        if (mounted && _showOfflineToast) {
          setState(() => _showOfflineToast = false);
        }
      }
    });

    final isOffline = ref.watch(isOfflineProvider);

    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}

    _currentIndex = _indexFromLocation(currentPath);
    final isHome = currentPath == '/home';
    final isTopLevelTab = _tabPaths.contains(currentPath);

    // Белые иконки статус-бара на синих экранах, тёмные на светлых
    final isLightStatusBar =
        currentPath == '/home' ||
        currentPath == '/profile' ||
        currentPath.contains('/detailing') ||
        currentPath.contains('/complete');
    SystemChrome.setSystemUIOverlayStyle(
      isLightStatusBar ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    final hideNavBar =
        currentPath.startsWith('/visits/pharmacy/detail/') &&
        currentPath.contains('/type');

    ref.listen<int>(offlineBannerPulseProvider, (_, _) {
      if (ref.read(isOfflineProvider) && currentPath != '/home') {
        _showTransientOfflineToast();
      }
    });

    if (isOffline && !isHome && _lastOfflineToastPath != currentPath) {
      _lastOfflineToastPath = currentPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !ref.read(isOfflineProvider)) return;
        _showTransientOfflineToast();
      });
    } else if (!isOffline || isHome) {
      _lastOfflineToastPath = isHome ? '/home' : '';
    }

    return PopScope(
      canPop: !isTopLevelTab,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !isTopLevelTab || isHome) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: OfflineBanner(visible: isOffline && isHome),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: OfflineBanner(
                visible: isOffline && !isHome && _showOfflineToast,
                compact: true,
              ),
            ),
            if (!hideNavBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _LimaNavBar(
                  currentIndex: _currentIndex,
                  onTap: (i) {
                    if (i < _tabPaths.length) {
                      final target = _tabPaths[i];
                      if (target == '/visits' &&
                          !currentPath.startsWith('/visits')) {
                        context.go(
                          '/visits?reset=${DateTime.now().millisecondsSinceEpoch}',
                        );
                        return;
                      }
                      context.go(target);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LimaNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _LimaNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalHeight = LimaNavBarLayout.totalBarHeight(context);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: LimaNavBarLayout.barHeight + bottomPad,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: 70 + bottomPad,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        border: Border(
                          top: BorderSide(color: AppColors.divider, width: 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 16,
                            spreadRadius: 0,
                            color: Colors.black.withValues(alpha: 0.14),
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.06),
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 16, 0, 16 + bottomPad),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _NavItem(
                          icon: LucideIcons.house,
                          activeIcon: LucideIcons.house,
                          label: 'Главная',
                          index: 0,
                          current: currentIndex,
                          onTap: onTap,
                        ),
                        _NavItem(
                          icon: LucideIcons.calendarDays,
                          activeIcon: LucideIcons.calendarDays,
                          label: 'План',
                          index: 1,
                          current: currentIndex,
                          onTap: onTap,
                        ),
                        _CenterNavItem(
                          index: 2,
                          current: currentIndex,
                          onTap: onTap,
                        ),
                        _NavItem(
                          icon: LucideIcons.bookmark,
                          activeIcon: LucideIcons.bookmark,
                          label: 'База',
                          index: 3,
                          current: currentIndex,
                          onTap: onTap,
                        ),
                        _NavItem(
                          icon: LucideIcons.user,
                          activeIcon: LucideIcons.user,
                          label: 'Профиль',
                          index: 4,
                          current: currentIndex,
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = isActive ? AppColors.primary : AppColors.hintText;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.iconBgBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(isActive ? activeIcon : icon, color: color, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterNavItem extends StatelessWidget {
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _CenterNavItem({
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryDark : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  spreadRadius: 0,
                  color: AppColors.primary.withValues(alpha: 0.45),
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isActive ? LucideIcons.mapPin : LucideIcons.mapPin,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Визиты',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}
