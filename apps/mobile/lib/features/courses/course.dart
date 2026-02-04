import 'package:hive/hive.dart';

class Course extends HiveObject {
  String id;
  String name;

  Course({required this.id, required this.name});
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
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }
}
