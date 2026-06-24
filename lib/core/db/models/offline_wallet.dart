import 'package:hive/hive.dart';

class OfflineWallet {
  final String clerkId;
  final String appSyncId;
  final String name;
  final String email;
  double syncedBalance;
  double lockedOfflineBalance;

  OfflineWallet({
    required this.clerkId,
    required this.appSyncId,
    required this.name,
    required this.email,
    required this.syncedBalance,
    this.lockedOfflineBalance = 0.0,
  });
}

class OfflineWalletAdapter extends TypeAdapter<OfflineWallet> {
  @override
  final int typeId = 0;

  @override
  OfflineWallet read(BinaryReader reader) {
    return OfflineWallet(
      clerkId: reader.readString(),
      appSyncId: reader.readString(),
      name: reader.readString(),
      email: reader.readString(),
      syncedBalance: reader.readDouble(),
      lockedOfflineBalance: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineWallet obj) {
    writer.writeString(obj.clerkId);
    writer.writeString(obj.appSyncId);
    writer.writeString(obj.name);
    writer.writeString(obj.email);
    writer.writeDouble(obj.syncedBalance);
    writer.writeDouble(obj.lockedOfflineBalance);
  }
}
