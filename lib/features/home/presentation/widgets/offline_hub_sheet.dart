import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

class OfflineHubSheet extends StatelessWidget {
  final VoidCallback onSyncPressed;

  const OfflineHubSheet({super.key, required this.onSyncPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offline Vault', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('Use these tools when you have no internet', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
          
          const SizedBox(height: 32),
          
          // Action Grid
          Row(
            children: [
              Expanded(
                child: _HubTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan Proof',
                  subtitle: 'Claim an offline payment',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/scan-qr');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HubTile(
                  icon: Icons.call_received_rounded,
                  title: 'Request',
                  subtitle: 'Generate offline QR',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/receive-money');
                  },
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _HubTile(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Radio Transfer',
                  subtitle: 'Send money via Bluetooth',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/radio');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HubTile(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Sync Ledger',
                  subtitle: 'Settle offline transactions',
                  color: const Color(0xFFEAB308),
                  onTap: () {
                    Navigator.pop(context);
                    onSyncPressed();
                  },
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
