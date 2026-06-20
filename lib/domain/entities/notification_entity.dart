import 'package:hive/hive.dart';
import '../../data/local/hive_type_ids.dart';

class NotificationEntity {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;

  NotificationEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationEntityAdapter extends TypeAdapter<NotificationEntity> {
  @override
  final int typeId = HiveTypeIds.notification;

  @override
  NotificationEntity read(BinaryReader reader) {
    return NotificationEntity(
      id: reader.readString(),
      userId: reader.readString(),
      title: reader.readString(),
      message: reader.readString(),
      timestamp: reader.readString(),
      isRead: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, NotificationEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.userId);
    writer.writeString(obj.title);
    writer.writeString(obj.message);
    writer.writeString(obj.timestamp);
    writer.writeBool(obj.isRead);
  }
}
