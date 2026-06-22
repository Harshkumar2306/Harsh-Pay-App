import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/db/models/offline_transaction.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final OfflineTransaction tx;

  const TransactionDetailsSheet({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == 'credit';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);

    String displayTitle = tx.title;
    String? note;

    if (tx.title.contains('::NOTE::')) {
      final parts = tx.title.split('::NOTE::');
      displayTitle = parts[0];
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        note = parts[1].trim();
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.primary.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isCredit ? AppColors.primary : Colors.redAccent,
              size: 32,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            '${isCredit ? '+' : '-'} ${fmt.format(tx.amount)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isCredit ? AppColors.primary : Colors.redAccent,
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            isCredit ? 'Payment Received' : 'Payment Sent',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 40),
          _buildDetailRow('Title', displayTitle, delay: 300),
          const SizedBox(height: 24),
          _buildDetailRow('Date & Time', DateFormat('dd MMM yyyy, hh:mm a').format(date), delay: 350),
          const SizedBox(height: 24),
          _buildDetailRow('Transaction ID', tx.txId, delay: 400),
          const SizedBox(height: 24),
          _buildDetailRow('Status', tx.isSynced ? 'Successful' : 'Pending Sync', delay: 450, 
            valueColor: tx.isSynced ? AppColors.primary : Colors.orange),
          if (note != null) ...[
            const SizedBox(height: 24),
            _buildDetailRow('Note', note, delay: 500, isNote: true),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {required int delay, Color? valueColor, bool isNote = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: isNote ? FontWeight.normal : FontWeight.w600,
              fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(begin: 0.1);
  }
}
