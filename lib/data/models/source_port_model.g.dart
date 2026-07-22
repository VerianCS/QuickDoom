// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_port_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SourcePortModelAdapter extends TypeAdapter<SourcePortModel> {
  @override
  final int typeId = 0;

  @override
  SourcePortModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SourcePortModel(
      id: fields[0] as String,
      name: fields[1] as String,
      executablePath: fields[2] as String,
      defaultArgs: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SourcePortModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.executablePath)
      ..writeByte(3)
      ..write(obj.defaultArgs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourcePortModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
