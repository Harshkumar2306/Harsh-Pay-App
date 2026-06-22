import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_transaction.dart';
import './widgets/transaction_details_sheet.dart';

class TransactionHistoryTab extends StatefulWidget {
  const TransactionHistoryTab({super.key});

  @override
  State<TransactionHistoryTab> createState() => _TransactionHistoryTabState();
}

class _TransactionHistoryTabState extends State<TransactionHistoryTab> {
  int _selectedFilter = 0; // 0: All, 1: Credit, 2: Debit, 3: Pending
  final List<String> _filters = ['All', 'Credit', 'Debit', 'Pending'];
  List<OfflineTransaction> allTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadLocal();
    Hive.box<OfflineTransaction>(HiveSetup.transactionsBox).listenable().addListener(_loadLocal);
  }

  void _loadLocal() {
    setState(() {
      allTransactions = HiveSetup.getTransactions();
    });
  }

  @override
  void dispose() {
    Hive.box<OfflineTransaction>(HiveSetup.transactionsBox).listenable().removeListener(_loadLocal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    List<OfflineTransaction> filteredTransactions = allTransactions;
    if (_selectedFilter == 1) {
      filteredTransactions = allTransactions.where((t) => t.type == 'credit').toList();
    } else if (_selectedFilter == 2) {
      filteredTransactions = allTransactions.where((t) => t.type == 'debit').toList();
    } else if (_selectedFilter == 3) {
      filteredTransactions = allTransactions.where((t) => !t.isSynced).toList();
    }
    
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

    return Column(
      children: [
        // App Bar equivalent
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Filters
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedFilter == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _filters[index],
                    style: TextStyle(
                      color: isSelected ? AppColors.background : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Transaction List
        Expanded(
          child: filteredTransactions.isEmpty 
          ? const Center(child: Text('No transactions found', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 120),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                final isCredit = tx.type == 'credit';
                final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
                      
                String displayTitle = tx.title;
                if (tx.title.contains('::NOTE::')) {
                  displayTitle = tx.title.split('::NOTE::')[0];
                }

                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TransactionDetailsSheet(tx: tx),
                    );
                  },
                  child: Container(
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
                            Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(date),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(
                            '${isCredit ? '+' : '-'} ${formatter.format(tx.amount)}',
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
                  ),
                );
              },
            ),
        ),
      ],
    );
  }
}
