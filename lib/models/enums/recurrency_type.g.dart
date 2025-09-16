// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrency_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurrencyTypeAdapter extends TypeAdapter<RecurrencyType> {
  @override
  final int typeId = 1;

  @override
  RecurrencyType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecurrencyType.daily;
      case 1:
        return RecurrencyType.weekly;
      case 2:
        return RecurrencyType.monthly;
      case 3:
        return RecurrencyType.custom;
      case 4:
        return RecurrencyType.none;
      default:
        return RecurrencyType.daily;
    }
  }

  @override
  void write(BinaryWriter writer, RecurrencyType obj) {
    switch (obj) {
      case RecurrencyType.daily:
        writer.writeByte(0);
        break;
      case RecurrencyType.weekly:
        writer.writeByte(1);
        break;
      case RecurrencyType.monthly:
        writer.writeByte(2);
        break;
      case RecurrencyType.custom:
        writer.writeByte(3);
        break;
      case RecurrencyType.none:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrencyTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
