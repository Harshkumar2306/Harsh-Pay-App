import 'package:hive_flutter/hive_flutter.dart';
import 'models/offline_wallet.dart';
import 'models/offline_transaction.dart';

class HiveSetup {
  static const String walletBox = 'walletBox';
  static const String transactionsBox = 'transactionsBox';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(OfflineWalletAdapter());
    Hive.registerAdapter(OfflineTransactionAdapter());

    await Hive.openBox<OfflineWallet>(walletBox);
    await Hive.openBox<OfflineTransaction>(transactionsBox);
  }

  // ── Wallet ──────────────────────────────
  static OfflineWallet? getWallet() {
    final box = Hive.box<OfflineWallet>(walletBox);
    return box.isNotEmpty ? box.getAt(0) : null;
  }

  static Future<void> saveWallet(OfflineWallet wallet) async {
    final box = Hive.box<OfflineWallet>(walletBox);
    await box.clear();
    await box.add(wallet);
  }

  // ── Transactions ─────────────────────────
  static List<OfflineTransaction> getTransactions() {
    final box = Hive.box<OfflineTransaction>(transactionsBox);
    final list = box.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  static Future<void> saveTransaction(OfflineTransaction tx) async {
    final box = Hive.box<OfflineTransaction>(transactionsBox);
    await box.put(tx.txId, tx); // keyed by txId for idempotency
  }

  /// Merges cloud transactions into local Hive — won't duplicate existing txIds
  static Future<int> mergeCloudTransactions(List<dynamic> cloudTxs) async {
    final box = Hive.box<OfflineTransaction>(transactionsBox);
    int added = 0;
    for (final raw in cloudTxs) {
      final txId = raw['txId']?.toString() ?? '';
      if (txId.isEmpty) continue;
      if (box.containsKey(txId)) continue; // already exists

      final tx = OfflineTransaction(
        txId: txId,
        type: raw['type'] ?? 'debit',
        amount: (raw['amount'] as num).toDouble(),
        title: raw['title'] ?? 'Transaction',
        timestamp: raw['timestamp'] is int
            ? raw['timestamp'] as int
            : DateTime.now().millisecondsSinceEpoch,
        isSynced: true,
      );
      await box.put(txId, tx);
      added++;
    }
    return added;
  }
}
