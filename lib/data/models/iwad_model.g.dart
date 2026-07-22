// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iwad_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IwadModelAdapter extends TypeAdapter<IwadModel> {
  @override
  final int typeId = 1;

  @override
  IwadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IwadModel(
      id: fields[0] as String,
      name: fields[1] as String,
      path: fields[2] as String,
      gameFamilyIndex: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, IwadModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.path)
      ..writeByte(3)
      ..write(obj.gameFamilyIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IwadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
