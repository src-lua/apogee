// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_streak_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskStreakDataAdapter extends TypeAdapter<TaskStreakData> {
  @override
  final int typeId = 5;

  @override
  TaskStreakData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskStreakData(
      currentStreak: fields[0] as int,
      bestStreak: fields[1] as int,
      lastCompletedDate: fields[2] as DateTime?,
      totalCompletions: fields[3] as int,
      lastCalculated: fields[4] as DateTime?,
      currentStreakStartDate: fields[5] as DateTime?,
      needsRecalculation: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaskStreakData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.currentStreak)
      ..writeByte(1)
      ..write(obj.bestStreak)
      ..writeByte(2)
      ..write(obj.lastCompletedDate)
      ..writeByte(3)
      ..write(obj.totalCompletions)
      ..writeByte(4)
      ..write(obj.lastCalculated)
      ..writeByte(5)
      ..write(obj.currentStreakStartDate)
      ..writeByte(6)
      ..write(obj.needsRecalculation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStreakDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
