import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_wallet.dart';
import '../../../core/db/models/offline_transaction.dart';
import '../../../core/network/api_client.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  OfflineWallet? wallet;
  List<OfflineTransaction> transactions = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      wallet = HiveSetup.getWallet();
      transactions = HiveSetup.getTransactions();
    });
  }

  Future<void> _syncNow() async {
    if (wallet == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    final data = await ApiClient().fetchWalletData(wallet!.appSyncId);
    if (!mounted) return;
    if (data != null) {
      final updated = OfflineWallet(
        clerkId: data['clerkId'] ?? wallet!.clerkId,
        appSyncId: data['appSyncId'] ?? wallet!.appSyncId,
        name: data['name'] ?? wallet!.name,
        email: data['email'] ?? wallet!.email,
        syncedBalance: (data['syncedBalance'] as num?)?.toDouble() ?? wallet!.syncedBalance,
      );
      await HiveSetup.saveWallet(updated);

      // Also sync transaction history
      final cloudTxs = data['transactions'];
      if (cloudTxs is List && cloudTxs.isNotEmpty) {
        await HiveSetup.mergeCloudTransactions(cloudTxs);
      }

      if (!mounted) return;
      setState(() {
        wallet = updated;
        transactions = HiveSetup.getTransactions();
        _isSyncing = false;
      });
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Synced — ${transactions.length} transactions loaded'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (!mounted) return;
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
    final name = wallet?.name ?? 'User';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    final totalTx = transactions.length;
    final totalSpent = transactions.where((t) => t.type == 'debit').fold(0.0, (s, t) => s + t.amount);
    final totalReceived = transactions.where((t) => t.type == 'credit').fold(0.0, (s, t) => s + t.amount);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
        child: Column(
          children: [
            // ── Profile Card ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  // Avatar + Name
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    wallet?.email.isNotEmpty == true ? wallet!.email : 'Cloud Node Connected',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Balance Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          wallet != null ? fmt.format(wallet!.syncedBalance) : '₹ 0.00',
                          style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sync Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _syncNow,
                      icon: _isSyncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                          : const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync from Cloud'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats Row ──
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Total Transactions', value: '$totalTx', icon: Icons.receipt_long_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Total Spent', value: fmt.format(totalSpent), icon: Icons.north_east_rounded, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(label: 'Total Received', value: fmt.format(totalReceived), icon: Icons.south_west_rounded, color: AppColors.primary, fullWidth: true),
            const SizedBox(height: 20),

            // ── Security Info ──
            _SettingsTile(
              icon: Icons.vpn_key_rounded,
              title: 'App Sync ID',
              subtitle: wallet?.appSyncId != null
                  ? '${wallet!.appSyncId.substring(0, 12)}••••••'
                  : 'Not linked',
              onTap: () {
                if (wallet?.appSyncId != null) {
                  Clipboard.setData(ClipboardData(text: wallet!.appSyncId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App Sync ID copied'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
            ),
            _SettingsTile(
              icon: Icons.shield_rounded,
              title: 'Offline Encryption',
              subtitle: 'Hive AES-256 encrypted local database',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.qr_code_2_rounded,
              title: 'My QR Code',
              subtitle: 'Show QR to receive offline payments',
              onTap: () => context.push('/receive-money'),
            ),
            const SizedBox(height: 8),

            // ── Disconnect ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect & Re-link Device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Disconnect?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: const Text(
                        'This will remove all local wallet data. You can re-link anytime with your App Sync ID.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final box = Hive.box<OfflineWallet>(HiveSetup.walletBox);
                    await box.clear();
                    if (context.mounted) context.go('/sync');
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool fullWidth;

  const _StatCard({required this.label, required this.value, required this.icon, this.color, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 15), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
