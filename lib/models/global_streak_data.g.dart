// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_streak_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GlobalStreakDataAdapter extends TypeAdapter<GlobalStreakData> {
  @override
  final int typeId = 6;

  @override
  GlobalStreakData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GlobalStreakData(
      currentLoggingStreak: fields[0] as int,
      bestLoggingStreak: fields[1] as int,
      lastLoggedDate: fields[2] as DateTime?,
      totalLoggedDays: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GlobalStreakData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.currentLoggingStreak)
      ..writeByte(1)
      ..write(obj.bestLoggingStreak)
      ..writeByte(2)
      ..write(obj.lastLoggedDate)
      ..writeByte(3)
      ..write(obj.totalLoggedDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalStreakDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
