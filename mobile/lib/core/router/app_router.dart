import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/otp_verify_screen.dart';
import '../../presentation/shell/main_shell.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/device_config/device_config_screen.dart';
import '../../presentation/device_config/device_detail_screen.dart';
import '../../presentation/add_device/add_device_screen.dart';
import '../../presentation/add_device/provisioning/soft_ap_flow.dart';
import '../../presentation/automation/automation_screen.dart';
import '../../presentation/automation/scene_editor.dart';
import '../../presentation/automation/scheduler_screen.dart';
import '../../presentation/automation/agent_chat_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/settings/floor_room_manager.dart';
import '../../presentation/settings/home_sharing_screen.dart';
import '../../presentation/settings/permission_matrix_screen.dart';
import '../../presentation/settings/profile_screen.dart';
import '../../presentation/settings/webview_screen.dart';


final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/otp-verify');

      if (isOnSplash) return null;

      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return null;
      }

      if (authState.isAuthenticated && isOnAuth) return '/dashboard';
      if (!authState.isAuthenticated && !isOnAuth) return '/login';

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpVerifyScreen(
            contact: extra['contact'] as String? ?? '',
            isEmail: extra['is_email'] as bool? ?? true,
            purpose: extra['purpose'] as String? ?? 'reset_password',
            name: extra['name'] as String?,
          );
        },
      ),

      // Add Device (outside shell so it overlays)
      GoRoute(
        path: '/add-device',
        builder: (context, state) => const AddDeviceScreen(),
        routes: [
          GoRoute(
            path: 'provisioning',
            builder: (context, state) => const SoftApFlowScreen(),
          ),
        ],
      ),

      // Main Shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Dashboard
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Tab 1: Device Config
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/devices',
                builder: (context, state) => const DeviceConfigScreen(),
                routes: [
                  GoRoute(
                    path: ':deviceId',
                    builder: (context, state) => DeviceDetailScreen(
                      deviceId: state.pathParameters['deviceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tab 2: Placeholder for FAB (maps to dashboard)
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/fab-placeholder',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),

          // Tab 3: Automation
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/automation',
                builder: (context, state) => const AutomationScreen(),
                routes: [
                  GoRoute(
                    path: 'scene/:id',
                    builder: (context, state) => SceneEditorScreen(
                      automationId: state.pathParameters['id'] == 'new'
                          ? null
                          : state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'scheduler/:deviceId',
                    builder: (context, state) {
                      final switchIndex = int.tryParse(
                              state.uri.queryParameters['switchIndex'] ?? '1') ??
                          1;
                      return SchedulerScreen(
                        deviceId: state.pathParameters['deviceId']!,
                        switchIndex: switchIndex,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const AgentChatScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Tab 4: Settings
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'floors-rooms',
                    builder: (context, state) => const FloorRoomManagerScreen(),
                  ),
                  GoRoute(
                    path: 'home-sharing',
                    builder: (context, state) => const HomeSharingScreen(),
                  ),
                  GoRoute(
                    path: 'permissions/:memberId',
                    builder: (context, state) => PermissionMatrixScreen(
                      memberId: state.pathParameters['memberId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'webview',
                    builder: (context, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return WebViewScreen(
                        url: extra['url'] as String? ?? 'https://neurotouch.in',
                        title: extra['title'] as String? ?? 'Neuro Touch',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
