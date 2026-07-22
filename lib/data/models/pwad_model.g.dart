// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pwad_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PwadModelAdapter extends TypeAdapter<PwadModel> {
  @override
  final int typeId = 2;

  @override
  PwadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PwadModel(
      id: fields[0] as String,
      path: fields[1] as String,
      isEnabled: fields[2] as bool,
      loadOrder: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PwadModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.isEnabled)
      ..writeByte(3)
      ..write(obj.loadOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PwadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
