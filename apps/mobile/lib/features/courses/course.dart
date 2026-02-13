import 'package:hive/hive.dart';

class Course extends HiveObject {
  String id;
  String name;
  String memo;
  List<String> tags;

  Course({
    required this.id,
    required this.name,
    this.memo = '',
    List<String>? tags,
  }) : tags = tags ?? [];
}

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 3;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return Course(
      id: (fields[0] as String?) ?? '',
      name: (fields[1] as String?) ?? '',
      memo: (fields[2] as String?) ?? '',
      tags: (fields[3] is List)
          ? (fields[3] as List).whereType<String>().toList()
          : <String>[],
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.memo)
      ..writeByte(3)
      ..write(obj.tags);
  }
}
