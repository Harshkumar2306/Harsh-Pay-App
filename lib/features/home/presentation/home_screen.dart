import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_wallet.dart';
import '../../../core/db/models/offline_transaction.dart';
import '../../../../domain/entities/notification_entity.dart';
import '../../../../core/services/notification_service.dart';
import '../../transactions/presentation/transaction_history_tab.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../../presentation/widgets/animated_bouncy_button.dart';
import '../../../presentation/widgets/glass_container.dart';
import './widgets/offline_hub_sheet.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 5.seconds),
          ),
          SafeArea(bottom: false, child: _buildBody()),

          // Floating Glass Bottom Nav
          Positioned(
            bottom: 24, left: 20, right: 20,
            child: GlassContainer(
              blur: 20,
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.home_rounded, label: 'Home', isSelected: _currentIndex == 0, onTap: () => setState(() => _currentIndex = 0)),
                  _NavItem(icon: Icons.qr_code_scanner_rounded, label: 'Pay', isSelected: _currentIndex == 1, onTap: () => setState(() => _currentIndex = 1)),
                  _NavItem(icon: Icons.history_rounded, label: 'History', isSelected: _currentIndex == 2, onTap: () => setState(() => _currentIndex = 2)),
                  _NavItem(icon: Icons.person_rounded, label: 'Profile', isSelected: _currentIndex == 3, onTap: () => setState(() => _currentIndex = 3)),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return const _HomeTab();
      case 1: return const _PaymentsHub();
      case 2: return const TransactionHistoryTab();
      case 3: return const ProfileTab();
      default: return const _HomeTab();
    }
  }
}

// ─────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))
                  .animate().fadeIn(duration: 200.ms).slideX(begin: -0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  OfflineWallet? wallet;
  List<OfflineTransaction> transactions = [];
  bool _isSyncing = false;
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _autoSync();

    final wBox = Hive.box<OfflineWallet>(HiveSetup.walletBox);
    final tBox = Hive.box<OfflineTransaction>(HiveSetup.transactionsBox);
    
    wBox.listenable().addListener(_loadLocal);
    tBox.listenable().addListener(_loadLocal);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (mounted && _isOnline != isConnected) {
        setState(() => _isOnline = isConnected);
        if (isConnected) _autoSync(); // Sync automatically when reconnecting!
      }
    });
  }

  @override
  void dispose() {
    final wBox = Hive.box<OfflineWallet>(HiveSetup.walletBox);
    final tBox = Hive.box<OfflineTransaction>(HiveSetup.transactionsBox);
    wBox.listenable().removeListener(_loadLocal);
    tBox.listenable().removeListener(_loadLocal);
    
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _loadLocal() {
    setState(() {
      wallet = HiveSetup.getWallet();
      transactions = HiveSetup.getTransactions();
    });
  }

  Future<void> _autoSync() async {
    if (wallet == null) return;

    // 1. Upload pending offline transactions FIRST
    final unsyncedTxs = transactions.where((tx) => !tx.isSynced).toList();
    if (unsyncedTxs.isNotEmpty) {
      final txMapList = unsyncedTxs.map((tx) => {
        'id': tx.txId,
        'amount': tx.amount,
        'type': tx.type,
        'title': tx.title,
        'timestamp': tx.timestamp,
      }).toList();

      final syncResult = await ApiClient().syncTransactions(wallet!.clerkId, txMapList);
      if (syncResult != null && syncResult['results'] != null) {
        final results = syncResult['results'] as List;
        
        for (var tx in unsyncedTxs) {
          // Find the result for this specific transaction
          final res = results.firstWhere(
            (r) => r['transactionId'] == tx.txId, 
            orElse: () => null
          );

          if (res != null && (res['status'] == 'SUCCESS' || res['status'] == 'ALREADY_PROCESSED')) {
            tx.isSynced = true;
            await HiveSetup.saveTransaction(tx);
          }
        }
      }
    }

    // 2. Fetch the latest truthful wallet data from the cloud
    final data = await ApiClient().fetchWalletData(wallet!.appSyncId);
    if (!mounted) return;
    if (data != null) {
      // 1. Update wallet balance
      final updated = OfflineWallet(
        clerkId: data['clerkId'] ?? wallet!.clerkId,
        appSyncId: data['appSyncId'] ?? wallet!.appSyncId,
        name: data['name'] ?? wallet!.name,
        email: data['email'] ?? wallet!.email,
        syncedBalance: (data['syncedBalance'] as num?)?.toDouble() ?? wallet!.syncedBalance,
      );
      await HiveSetup.saveWallet(updated);

      // 2. Merge cloud transaction history into Hive
      final cloudTxs = data['transactions'];
      if (cloudTxs is List && cloudTxs.isNotEmpty) {
        await HiveSetup.mergeCloudTransactions(cloudTxs);
      }

      if (!mounted) return;
      
      setState(() {
        wallet = updated;
        transactions = HiveSetup.getTransactions();
        _isOnline = true;
      });
    } else {
      if (!mounted) return;
      setState(() => _isOnline = false);
    }
  }

  Future<void> _manualSync() async {
    if (wallet == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    await _autoSync();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline ? '✅ Balance synced from cloud!' : '⚠️ Offline — using local data'),
          backgroundColor: _isOnline ? AppColors.primary : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      // Trigger a local push notification if online
      if (_isOnline) {
        NotificationService.showNotification(
          title: 'Sync Successful',
          message: 'Your wallet has been synced securely from the cloud.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentTxs = transactions.take(3).toList();
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (wallet?.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Good day,', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(
                        (wallet?.name ?? 'User').split(' ').first,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
              Row(
                children: [
                  // Online/Offline Badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOnline
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOnline ? AppColors.primary : Colors.orange,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 1, end: 0.3, duration: 1.seconds),
                        const SizedBox(width: 5),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _isOnline ? AppColors.primary : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sync Button
                  GestureDetector(
                    onTap: _isSyncing ? null : _manualSync,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _isSyncing
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, color: AppColors.primary, size: 20),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Wallet Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.walletGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOnline ? Icons.cloud_done_rounded : Icons.wifi_off_rounded,
                            color: _isOnline ? Colors.white : Colors.orange,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOnline ? 'Synced' : 'Offline',
                            style: TextStyle(
                              color: _isOnline ? Colors.white : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  wallet != null ? fmt.format(wallet!.syncedBalance) : '₹ 0.00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap sync to refresh from cloud',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shield_rounded, color: Colors.white70, size: 14),
                              SizedBox(width: 6),
                              Text('Hive Encrypted Local DB', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            wallet != null ? 'Active' : '—',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // ── Notifications Bell ──
                    ValueListenableBuilder(
                      valueListenable: Hive.box<NotificationEntity>(HiveSetup.notificationsBox).listenable(),
                      builder: (context, Box<NotificationEntity> box, _) {
                        final unreadCount = box.values.where((n) => !n.isRead).length;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                onPressed: () => context.push('/notifications'),
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, curve: Curves.easeOutBack),
          const SizedBox(height: 28),

          // ── Quick Actions ──
          const Text('Online Banking', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))
              .animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionBtn(
                icon: Icons.qr_code_scanner_rounded, 
                label: 'Scan & Pay', 
                onTap: () => context.push('/scan-qr')
              ),
              _ActionBtn(
                icon: Icons.send_rounded, 
                label: 'Send Money', 
                onTap: () => context.push('/send-money-online')
              ),
              _ActionBtn(
                icon: Icons.account_balance_rounded, 
                label: 'Bank Transfer', 
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Online Bank Transfer Coming Soon')));
                }
              ),
              if (!_isOnline) // UNLOCK OFFLINE VAULT WHEN OFFLINE!
                _ActionBtn(
                  icon: Icons.wifi_off_rounded, 
                  label: 'Offline Vault', 
                  iconColor: Colors.orange,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => OfflineHubSheet(onSyncPressed: _manualSync),
                    );
                  }
                )
              else
                _ActionBtn(
                  icon: Icons.lock_outline_rounded, 
                  label: 'Offline Vault', 
                  iconColor: AppColors.textSecondary.withValues(alpha: 0.5),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turn off internet to unlock offline tools')));
                  }
                ),
            ],
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 32),

          // ── Recent Transactions ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: () {},
                child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 8),

          if (recentTxs.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: AppColors.textSecondary, size: 40),
                    SizedBox(height: 12),
                    Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Offline payments will appear here', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 450.ms)
          else
            ...recentTxs.map((tx) => _TxTile(tx: tx)).toList()
                .animate(interval: 80.ms).fadeIn(delay: 450.ms).slideX(begin: 0.08),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  const _ActionBtn({
    required this.icon, 
    required this.label, 
    required this.onTap,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBouncyButton(
      onPressed: onTap,
      child: Column(
        children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final OfflineTransaction tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == 'credit';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.primary.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isCredit ? AppColors.primary : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMM, hh:mm a').format(date),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${isCredit ? '+' : '-'} ${fmt.format(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 15,
                color: isCredit ? AppColors.primary : Colors.redAccent,
              ),
            ),
            if (!tx.isSynced)
              const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Payments Hub Tab
// ─────────────────────────────────────────
class _PaymentsHub extends StatelessWidget {
  const _PaymentsHub();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transfer Money', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5))
                .animate().fadeIn().slideY(begin: -0.1),
            const SizedBox(height: 4),
            const Text('Choose a transfer method', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))
                .animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 32),
            _MethodCard(
              icon: Icons.send_rounded,
              title: 'Send Money Online',
              subtitle: 'Send money instantly using an email address',
              gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              onTap: () => context.push('/send-money-online'),
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _MethodCard(
              icon: Icons.qr_code_rounded,
              title: 'Scan QR Code',
              subtitle: 'Scan a friend\'s code to pay them offline instantly',
              gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
              onTap: () => context.push('/scan-qr'),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _MethodCard(
              icon: Icons.call_received_rounded,
              title: 'Receive Money',
              subtitle: 'Show your QR code for someone to scan and pay you',
              gradient: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
              onTap: () => context.push('/receive-money'),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _MethodCard(
              icon: Icons.wifi_tethering_rounded,
              title: 'Radio Transfer',
              subtitle: 'Bluetooth / Wi-Fi Direct — Coming in next update',
              gradient: [const Color(0xFF6B7280), const Color(0xFF4B5563)],
              isDisabled: true,
              onTap: () {},
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isDisabled;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: const Text('Soon', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              if (!isDisabled) const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
