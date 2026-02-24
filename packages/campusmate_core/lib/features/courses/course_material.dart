import 'package:hive/hive.dart';

class CourseMaterial extends HiveObject {
  String courseId;
  String fileName;
  String localPath;
  int addedAtMillis;

  CourseMaterial({
    required this.courseId,
    required this.fileName,
    required this.localPath,
    required DateTime addedAt,
  }) : addedAtMillis = addedAt.millisecondsSinceEpoch;

  CourseMaterial.hive({
    required this.courseId,
    required this.fileName,
    required this.localPath,
    required this.addedAtMillis,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMillis);
}

/// ✅ 수동 TypeAdapter (generator 필요 없음)
class CourseMaterialAdapter extends TypeAdapter<CourseMaterial> {
  @override
  final int typeId = 2;

  @override
  CourseMaterial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }

    return CourseMaterial.hive(
      courseId: (fields[0] as String?) ?? '',
      fileName: (fields[1] as String?) ?? '',
      localPath: (fields[2] as String?) ?? '',
      addedAtMillis: (fields[3] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CourseMaterial obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.courseId)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.addedAtMillis);
  }
}
