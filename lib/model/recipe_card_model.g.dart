// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_card_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeCardModelAdapter extends TypeAdapter<RecipeCardModel> {
  @override
  final int typeId = 0;

  @override
  RecipeCardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeCardModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      title: fields[2] as String,
      ingredients: (fields[3] as List).cast<String>(),
      instructions: (fields[4] as List).cast<String>(),
      createdAt: fields[5] as DateTime?,
      imageUrl: fields[6] as String?,
      categories: (fields[7] as List?)?.cast<String>(),
      isFavourite: fields[8] as bool,
      originalImageUrls: (fields[9] as List?)?.cast<String>(),
      hints: (fields[10] as List?)?.cast<String>(),
      translationUsed: fields[11] as bool,
      isGlobal: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeCardModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.instructions)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.imageUrl)
      ..writeByte(7)
      ..write(obj.categories)
      ..writeByte(8)
      ..write(obj.isFavourite)
      ..writeByte(9)
      ..write(obj.originalImageUrls)
      ..writeByte(10)
      ..write(obj.hints)
      ..writeByte(11)
      ..write(obj.translationUsed)
      ..writeByte(12)
      ..write(obj.isGlobal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeCardModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
