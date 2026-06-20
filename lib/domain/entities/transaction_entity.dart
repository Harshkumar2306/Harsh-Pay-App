import 'package:hive/hive.dart';
import '../../data/local/hive_type_ids.dart';

class TransactionStatus {
  static const String pendingSync = 'PENDING_SYNC';
  static const String syncing = 'SYNCING';
  static const String success = 'SUCCESS';
  static const String failed = 'FAILED';
  static const String rejected = 'REJECTED';
}

class TransactionEntity {
  final String id;
  final String walletId;
  final double amount;
  final String type; // TransactionType.credit / debit
  final String title;
  final DateTime timestamp;
  final String status;
  final String? deviceId;
  final String? signature;
  final bool pendingSync;

  TransactionEntity({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    required this.title,
    required this.timestamp,
    this.status = TransactionStatus.pendingSync,
    this.deviceId,
    this.signature,
    this.pendingSync = true,
  });
}

class TransactionType {
  static const String credit = 'credit';
  static const String debit = 'debit';
}

class TransactionEntityAdapter extends TypeAdapter<TransactionEntity> {
  @override
  final int typeId = HiveTypeIds.transaction;

  @override
  TransactionEntity read(BinaryReader reader) {
    return TransactionEntity(
      id: reader.readString(),
      walletId: reader.readString(),
      amount: reader.readDouble(),
      type: reader.readString(),
      title: reader.readString(),
      timestamp: DateTime.parse(reader.readString()),
      status: reader.readString(),
      deviceId: reader.read() as String?,
      signature: reader.read() as String?,
      pendingSync: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, TransactionEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.walletId);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.type);
    writer.writeString(obj.title);
    writer.writeString(obj.timestamp.toIso8601String());
    writer.writeString(obj.status);
    writer.write(obj.deviceId);
    writer.write(obj.signature);
    writer.writeBool(obj.pendingSync);
  }
}
