import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_wallet.dart';

class AppSyncScreen extends StatefulWidget {
  const AppSyncScreen({super.key});

  @override
  State<AppSyncScreen> createState() => _AppSyncScreenState();
}

class _AppSyncScreenState extends State<AppSyncScreen> {
  final TextEditingController _syncIdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check if already synced – skip to home
    final existing = HiveSetup.getWallet();
    if (existing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/home');
      });
    }
  }

  @override
  void dispose() {
    _syncIdController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    final syncId = _syncIdController.text.trim();
    if (syncId.isEmpty) {
      setState(() => _errorMessage = 'Please enter your App Sync ID');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await ApiClient().fetchWalletData(syncId);

    if (!mounted) return;

    if (data != null) {
      final wallet = OfflineWallet(
        clerkId: data['clerkId'] ?? syncId,
        appSyncId: data['appSyncId'] ?? syncId,
        name: data['name'] ?? 'User',
        email: data['email'] ?? '',
        syncedBalance: (data['syncedBalance'] as num?)?.toDouble() ?? 0.0,
      );

      // Wipe any leftover ghost data from previous accounts before syncing the new one
      final box = Hive.box<OfflineWallet>(HiveSetup.walletBox);
      await box.clear();
      final txBox = Hive.box<OfflineTransaction>(HiveSetup.transactionsBox);
      await txBox.clear();

      await HiveSetup.saveWallet(wallet);
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      context.go('/home');
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'Invalid App Sync ID or Network Error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 120,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Branding
                      Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 20),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(text: 'Harsh'),
                                TextSpan(
                                  text: 'Pay',
                                  style: TextStyle(color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                          const SizedBox(height: 8),
                          const Text(
                            'Offline-First Payments',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                        ],
                      ),

                      const SizedBox(height: 52),

                      // Card
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Link Your Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Find your App Sync ID in the Security Profile on harsh-bank.vercel.app',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Text Field — tap focus immediately
                            GestureDetector(
                              onTap: () {
                                FocusScope.of(context).requestFocus(_focusNode);
                              },
                              child: TextField(
                                controller: _syncIdController,
                                focusNode: _focusNode,
                                autofocus: false,
                                enableInteractiveSelection: true,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'user_xxxxxxxxxxxxxxxx',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14),
                                    child: Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                ),
                                onSubmitted: (_) => _handleSync(),
                              ),
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn().shakeX(),
                            ],

                            const SizedBox(height: 20),

                            // Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSync,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            'Link & Initialize',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),

                      const SizedBox(height: 32),

                      // Info Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Your data is stored encrypted on-device',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ).animate().fadeIn(delay: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
