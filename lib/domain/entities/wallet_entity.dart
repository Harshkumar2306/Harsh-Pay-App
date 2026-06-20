import 'package:hive/hive.dart';
import '../../data/local/hive_type_ids.dart';

class WalletEntity {
  final String id;
  final String userId;
  final double syncedBalance;
  final double pendingDebit;
  final double pendingCredit;
  final double offlineLimit;
  final double offlineUsed;
  final String currency;
  final DateTime updatedAt;

  WalletEntity({
    required this.id,
    required this.userId,
    required this.syncedBalance,
    this.pendingDebit = 0.0,
    this.pendingCredit = 0.0,
    this.offlineLimit = 1000.0, // Default limit
    this.offlineUsed = 0.0,
    this.currency = 'INR',
    required this.updatedAt,
  });

  double get availableBalance => syncedBalance - pendingDebit + pendingCredit;
}

class WalletEntityAdapter extends TypeAdapter<WalletEntity> {
  @override
  final int typeId = HiveTypeIds.wallet;

  @override
  WalletEntity read(BinaryReader reader) {
    return WalletEntity(
      id: reader.readString(),
      userId: reader.readString(),
      syncedBalance: reader.readDouble(),
      pendingDebit: reader.readDouble(),
      pendingCredit: reader.readDouble(),
      offlineLimit: reader.readDouble(),
      offlineUsed: reader.readDouble(),
      currency: reader.readString(),
      updatedAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, WalletEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.userId);
    writer.writeDouble(obj.syncedBalance);
    writer.writeDouble(obj.pendingDebit);
    writer.writeDouble(obj.pendingCredit);
    writer.writeDouble(obj.offlineLimit);
    writer.writeDouble(obj.offlineUsed);
    writer.writeString(obj.currency);
    writer.writeString(obj.updatedAt.toIso8601String());
  }
}
