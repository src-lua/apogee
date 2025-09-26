// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskTemplateAdapter extends TypeAdapter<TaskTemplate> {
  @override
  final int typeId = 2;

  @override
  TaskTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskTemplate(
      name: fields[1] as String,
      coins: fields[2] as int,
      recurrencyType: fields[3] as RecurrencyType,
      customDays: (fields[4] as List?)?.cast<int>(),
      isActive: fields[5] as bool,
      startDate: fields[8] as DateTime?,
      endDate: fields[9] as DateTime?,
      id: fields[0] as String?,
      createdAt: fields[6] as DateTime?,
      lastGenerated: fields[7] as DateTime?,
      lastModified: fields[10] as DateTime?,
      streakData: fields[11] as TaskStreakData?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskTemplate obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.coins)
      ..writeByte(3)
      ..write(obj.recurrencyType)
      ..writeByte(4)
      ..write(obj.customDays)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastGenerated)
      ..writeByte(8)
      ..write(obj.startDate)
      ..writeByte(9)
      ..write(obj.endDate)
      ..writeByte(10)
      ..write(obj.lastModified)
      ..writeByte(11)
      ..write(obj.streakData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
