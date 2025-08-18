// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

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
  State<RecipeImageHeader> createState() => _RecipeImageHeaderState();
}

class _RecipeImageHeaderState extends State<RecipeImageHeader> {
  final ImagePicker _picker = ImagePicker();
  String? _heroImage;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages.isNotEmpty) {
      _heroImage = widget.initialImages.first;
    }
  }

  Future<void> _pickAndUpload() async {
    final t = AppLocalizations.of(context);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      final originalFile = File(picked.path);
      final croppedFile = await ImageProcessingService.cropImage(originalFile);
      if (croppedFile == null) {
        setState(() => _uploading = false);
        return;
      }

      final uploadedUrl = await widget.onImagePicked(croppedFile.path);
      if (!mounted) return;
      setState(() {
        _heroImage = uploadedUrl;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      // Soft error surface
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return ResponsiveWrapper(
      maxWidth: 720,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: _heroImage == null
            ? t.updateImage
            : t.updateImage, // reuse i18n key
        button: true,
        image: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickAndUpload,
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                      _EmptyState(t: t),

                    // Subtle upload overlay
                    if (_uploading)
                      Container(
                        color: Colors.black.withOpacity(0.35),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),

                    // Bottom hint
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _HintChip(text: t.updateImage),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations t;
  const _EmptyState({required this.t});

  @override
  Widget build(BuildContext context) {
    final disabled = Theme.of(context).disabledColor;
    return Container(
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.chefHat, size: 56, color: disabled),
          const SizedBox(height: 8),
          Text(
            t.updateImage, // reuse existing localization key
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String text;
  const _HintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
