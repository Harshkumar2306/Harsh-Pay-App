import 'package:hive/hive.dart';

class OfflineTransaction {
  final String txId;
  final String type; // 'credit' or 'debit'
  final double amount;
  final String title;
  final int timestamp;
  final bool isSynced;

  OfflineTransaction({
    required this.txId,
    required this.type,
    required this.amount,
    required this.title,
    required this.timestamp,
    required this.isSynced,
  });
}

class OfflineTransactionAdapter extends TypeAdapter<OfflineTransaction> {
  @override
  final int typeId = 1;

  @override
  OfflineTransaction read(BinaryReader reader) {
    return OfflineTransaction(
      txId: reader.readString(),
      type: reader.readString(),
      amount: reader.readDouble(),
      title: reader.readString(),
      timestamp: reader.readInt(),
      isSynced: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineTransaction obj) {
    writer.writeString(obj.txId);
    writer.writeString(obj.type);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.title);
    writer.writeInt(obj.timestamp);
    writer.writeBool(obj.isSynced);
  }
}
