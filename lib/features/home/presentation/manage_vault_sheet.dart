import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/db/models/offline_wallet.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class ManageVaultSheet extends StatefulWidget {
  final OfflineWallet wallet;
  final VoidCallback onSuccess;

  const ManageVaultSheet({
    super.key,
    required this.wallet,
    required this.onSuccess,
  });

  @override
  State<ManageVaultSheet> createState() => _ManageVaultSheetState();
}

class _ManageVaultSheetState extends State<ManageVaultSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleTransfer(bool toOffline) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _errorMessage = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount');
      return;
    }

    // Client-side validation
    if (toOffline && amount > widget.wallet.syncedBalance) {
      setState(() => _errorMessage = 'Insufficient Main Cloud Balance');
      return;
    }
    if (!toOffline && amount > widget.wallet.lockedOfflineBalance) {
      setState(() => _errorMessage = 'Insufficient Offline Vault Balance');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await ApiClient().transferToOfflineVault(
      clerkId: widget.wallet.clerkId,
      amount: amount,
      toOffline: toOffline,
    );

    if (!mounted) return;

    if (result != null && result['error'] == null) {
      // Success
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(toOffline ? 'Locked ₹$amount for offline use!' : 'Moved ₹$amount back to Cloud!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      // Error
      setState(() {
        _isLoading = false;
        _errorMessage = result?['error'] ?? 'Transfer failed. Check connection.';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manage Vault',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Move funds between your Main Cloud Account and your cryptographically secured Offline Vault.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            
            // Balances
            Row(
              children: [
                Expanded(
                  child: _BalanceCard(
                    title: 'Main Cloud',
                    amount: fmt.format(widget.wallet.syncedBalance),
                    icon: Icons.cloud_done_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceCard(
                    title: 'Offline Vault',
                    amount: fmt.format(widget.wallet.lockedOfflineBalance),
                    icon: Icons.lock_rounded,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Colors.white70, fontSize: 32, fontWeight: FontWeight.w900),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 32, fontWeight: FontWeight.w900),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              ),
            ),
            
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ).animate().shakeX(),

            const SizedBox(height: 24),

            // Buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTransfer(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Lock Offline',
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTransfer(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Move to Cloud',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _BalanceCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
