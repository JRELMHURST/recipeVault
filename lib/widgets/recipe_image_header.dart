// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/services/image_processing_service.dart';

typedef OnImagePicked = Future<String> Function(String localPath);

class RecipeImageHeader extends StatefulWidget {
  final OnImagePicked onImagePicked;
  final List<String> initialImages;

  const RecipeImageHeader({
    super.key,
    required this.onImagePicked,
    this.initialImages = const [],
  });

  @override
  State<RecipeImageHeader> createState() => RecipeImageHeaderState();
}

class RecipeImageHeaderState extends State<RecipeImageHeader> {
  final ImagePicker _picker = ImagePicker();
  String? _heroImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages.isNotEmpty) {
      _heroImage = widget.initialImages.first;
    }
  }

  Future<void> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked == null) return;

    final originalFile = File(picked.path);
    final croppedFile = await ImageProcessingService.cropImage(originalFile);
    if (croppedFile == null) return;

    final uploadedUrl = await widget.onImagePicked(croppedFile.path);
    setState(() => _heroImage = uploadedUrl);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_heroImage != null)
              Image(
                image: _heroImage!.startsWith('http')
                    ? NetworkImage(_heroImage!)
                    : FileImage(File(_heroImage!)) as ImageProvider,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: Colors.grey[100],
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.chefHat,
                      size: 48,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+ Add photo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
