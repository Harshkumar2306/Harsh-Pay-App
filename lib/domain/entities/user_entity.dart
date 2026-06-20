import 'package:hive/hive.dart';
import '../../data/local/hive_type_ids.dart';

class UserEntity {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String? photoUrl;

  UserEntity({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.photoUrl,
  });
}

class UserEntityAdapter extends TypeAdapter<UserEntity> {
  @override
  final int typeId = HiveTypeIds.user;

  @override
  UserEntity read(BinaryReader reader) {
    return UserEntity(
      id: reader.readString(),
      phone: reader.readString(),
      name: reader.read() as String?,
      email: reader.read() as String?,
      photoUrl: reader.read() as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.phone);
    writer.write(obj.name);
    writer.write(obj.email);
    writer.write(obj.photoUrl);
  }
}
