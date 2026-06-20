import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/sync/screens/app_sync_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/payments/presentation/qr_scanner_screen.dart';
import '../../features/payments/presentation/receive_money_screen.dart';
import '../../features/payments/presentation/radio_transfer_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/sync',
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 16),
            const Text('Page not found', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => context.go('/home'),
              child: const Text('Go Home', style: TextStyle(color: Color(0xFF020817), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/sync',
        builder: (context, state) => const AppSyncScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/scan-qr',
        builder: (context, state) => const QRScannerScreen(),
      ),
      GoRoute(
        path: '/receive-money',
        builder: (context, state) => const ReceiveMoneyScreen(),
      ),
      GoRoute(
        path: '/radio',
        builder: (context, state) => const RadioTransferScreen(),
      ),
    ],
  );
}
