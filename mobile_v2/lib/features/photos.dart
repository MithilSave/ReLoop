import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/query.dart';
import '../ui/widgets.dart';

class PickedPhoto {
  final Uint8List bytes;
  final String name;
  final String mime;
  const PickedPhoto(this.bytes, this.name, this.mime);
}

/// A photo whose SHA-256 has been recorded by the backend as a document.
class RegisteredDoc {
  final String id;
  final String sha;
  final String name;
  final Uint8List? bytes;
  const RegisteredDoc(this.id, this.sha, this.name, [this.bytes]);
}

String _mimeFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic') || n.endsWith('.heif')) return 'image/heic';
  if (n.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

/// Asks whether to use the camera or the gallery, then returns the chosen image.
/// On desktop, where there is no camera source, the gallery (file chooser) is used directly.
Future<PickedPhoto?> pickPhoto(BuildContext context) async {
  final picker = ImagePicker();
  ImageSource? source;
  final hasCamera = Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;
  if (hasCamera) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.c.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return null;
  } else {
    source = ImageSource.gallery;
  }
  try {
    final x = await picker.pickImage(source: source, maxWidth: 2048, imageQuality: 88);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final name = x.name.isNotEmpty ? x.name : 'photo.jpg';
    return PickedPhoto(bytes, name, x.mimeType ?? _mimeFor(name));
  } catch (e) {
    toast('Could not open the ${source == ImageSource.camera ? 'camera' : 'photo picker'}: $e', error: true);
    return null;
  }
}

/// Picks a photo and records its SHA-256 with the backend. The image bytes stay on the device:
/// the backend's file storage is a stub, so only the hash is recorded.
Future<RegisteredDoc?> pickAndRegister(BuildContext context, String docType) async {
  final p = await pickPhoto(context);
  if (p == null) return null;
  try {
    final r = await Api.registerDocument(p.bytes, docType, p.mime);
    return RegisteredDoc(r.id, r.sha, p.name, p.bytes);
  } catch (e) {
    final err = toApiError(e);
    toast('Could not register the photo. ${err.message}', error: true);
    return null;
  }
}

/// Dashed "choose a file" box.
class PhotoBox extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool busy;
  final bool hasError;
  final double height;
  const PhotoBox({super.key, required this.text, this.onTap, this.busy = false, this.hasError = false, this.height = 46});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: hasError ? c.bad : c.line2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.photo_camera_outlined, size: 16, color: c.fg2),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.fg2), overflow: TextOverflow.ellipsis)),
          Icon(Icons.upload_outlined, size: 15, color: c.accent),
        ]),
      ),
    );
  }
}
