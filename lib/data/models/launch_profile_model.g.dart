// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LaunchProfileModelAdapter extends TypeAdapter<LaunchProfileModel> {
  @override
  final int typeId = 3;

  @override
  LaunchProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LaunchProfileModel(
      id: fields[0] as String,
      name: fields[1] as String,
      sourcePortId: fields[2] as String,
      iwadId: fields[3] as String,
      pwadModels: (fields[4] as List).cast<PwadModel>(),
      customArgs: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LaunchProfileModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sourcePortId)
      ..writeByte(3)
      ..write(obj.iwadId)
      ..writeByte(4)
      ..write(obj.pwadModels)
      ..writeByte(5)
      ..write(obj.customArgs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
