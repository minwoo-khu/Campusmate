// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoItemAdapter extends TypeAdapter<TodoItem> {
  @override
  final int typeId = 1;

  @override
  TodoItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TodoItem(
        id: fields[0] as String,
        title: fields[1] as String,
        completed: fields[3] as bool,
        notificationId: fields[5] as int?,
        repeatRule: TodoRepeatX.fromStorage(fields[6] as String?),
      )
      ..dueAtMillis = fields[2] as int?
      ..remindAtMillis = fields[4] as int?;
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.dueAtMillis)
      ..writeByte(3)
      ..write(obj.completed)
      ..writeByte(4)
      ..write(obj.remindAtMillis)
      ..writeByte(5)
      ..write(obj.notificationId)
      ..writeByte(6)
      ..write(obj.repeat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
