import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clipboard/clipboard.dart';

enum NotesImageSourceChoice { files, gallery, camera }

class NotesPickedImage {
  const NotesPickedImage({required this.dataUrl, required this.fileName});

  final String dataUrl;
  final String fileName;
}

class NotesCaptionResult {
  const NotesCaptionResult(this.caption);

  final String? caption;
}

Future<NotesPickedImage?> pickNotesImage({
  required BuildContext context,
}) async {
  final source = await showNotesImageSourcePicker(context: context);
  if (source == null) return null;

  XFile? file;
  switch (source) {
    case NotesImageSourceChoice.files:
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
          ),
        ],
      );
    case NotesImageSourceChoice.gallery:
      file = await ImagePicker().pickImage(source: ImageSource.gallery);
    case NotesImageSourceChoice.camera:
      file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) throw StateError('image_empty');
  if (bytes.lengthInBytes > kLifeOsNotesMaxAssetBytes) {
    throw const NotesImageTooLargeException();
  }
  final mimeType = notesImageMimeType(file.name, file.mimeType);
  return NotesPickedImage(
    dataUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
    fileName: file.name,
  );
}

Future<NotesImageSourceChoice?> showNotesImageSourcePicker({
  required BuildContext context,
}) {
  final loc = currentLocale.value;
  final mobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final camera = mobile || kIsWeb;
  return showModalBottomSheet<NotesImageSourceChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                t(loc, 'notes_image_source_title'),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            _sourceTile(
              sheetContext,
              Icons.folder_open_rounded,
              t(loc, 'notes_image_source_files'),
              NotesImageSourceChoice.files,
            ),
            if (mobile)
              _sourceTile(
                sheetContext,
                Icons.photo_library_outlined,
                t(loc, 'notes_image_source_gallery'),
                NotesImageSourceChoice.gallery,
              ),
            if (camera)
              _sourceTile(
                sheetContext,
                Icons.photo_camera_outlined,
                t(loc, 'notes_image_source_camera'),
                NotesImageSourceChoice.camera,
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _sourceTile(
  BuildContext context,
  IconData icon,
  String label,
  NotesImageSourceChoice source,
) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(source),
  );
}

Future<String?> showNotesImageCropper({
  required BuildContext context,
  required String dataUrl,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => NotesImageCropPage(dataUrl: dataUrl),
    ),
  );
}

class NotesImageCropPage extends StatefulWidget {
  const NotesImageCropPage({super.key, required this.dataUrl});

  final String dataUrl;

  @override
  State<NotesImageCropPage> createState() => _NotesImageCropPageState();
}

class _NotesImageCropPageState extends State<NotesImageCropPage> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  late final Uint8List? _bytes = decodeNotesImageDataUrl(widget.dataUrl);
  bool _saving = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _cropBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('crop_not_ready');
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('crop_encode_failed');
      final bytes = data.buffer.asUint8List();
      if (bytes.lengthInBytes > kLifeOsNotesMaxAssetBytes) {
        throw const NotesImageTooLargeException();
      }
      if (!mounted) return;
      Navigator.of(context).pop('data:image/png;base64,${base64Encode(bytes)}');
    } on NotesImageTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(currentLocale.value, 'notes_v3_editor_image_too_large'),
          ),
        ),
      );
      setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_image_crop_failed')),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: t(loc, 'cancel'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t(loc, 'notes_image_crop_title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppButton.primary(
              label: t(loc, 'notes_image_crop_apply'),
              size: AppButtonSize.s,
              loading: _saving,
              onPressed: bytes == null ? null : _save,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: bytes == null
              ? Text(t(loc, 'notes_image_crop_failed'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth - 32;
                    final maxHeight = constraints.maxHeight - 88;
                    final size = maxWidth < maxHeight ? maxWidth : maxHeight;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RepaintBoundary(
                          key: _cropBoundaryKey,
                          child: ClipRect(
                            child: SizedBox.square(
                              dimension: size.clamp(180, 720).toDouble(),
                              child: ColoredBox(
                                color: Colors.black,
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  minScale: 1,
                                  maxScale: 6,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  boundaryMargin: const EdgeInsets.all(800),
                                  child: SizedBox.expand(
                                    child: Image.memory(
                                      bytes,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t(loc, 'notes_image_crop_hint'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

Future<NotesCaptionResult?> showNotesImageCaptionDialog({
  required BuildContext context,
  String? currentCaption,
}) {
  final loc = currentLocale.value;
  final controller = TextEditingController(text: currentCaption ?? '');
  return showDialog<NotesCaptionResult>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t(loc, 'notes_image_caption_title')),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: t(loc, 'notes_image_caption_hint'),
        ),
      ),
      actions: [
        AppButton.ghost(
          label: t(loc, 'cancel'),
          size: AppButtonSize.s,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppButton.primary(
          label: t(loc, 'save'),
          size: AppButtonSize.s,
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(
              dialogContext,
            ).pop(NotesCaptionResult(value.isEmpty ? null : value));
          },
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<void> copyNotesImage(String dataUrl) async {
  final bytes = await notesImagePngBytes(dataUrl);
  await FlutterClipboard.copyImage(bytes);
}

Future<String?> saveNotesImage(String dataUrl) async {
  final bytes = await notesImagePngBytes(dataUrl);
  return FileSaver.instance.saveAs(
    name: 'life_os_note_${DateTime.now().millisecondsSinceEpoch}',
    bytes: bytes,
    fileExtension: 'png',
    mimeType: MimeType.png,
  );
}

Future<Uint8List> notesImagePngBytes(String dataUrl) async {
  final bytes = decodeNotesImageDataUrl(dataUrl);
  if (bytes == null || bytes.isEmpty) throw StateError('image_decode_failed');
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  codec.dispose();
  if (data == null) throw StateError('image_encode_failed');
  return data.buffer.asUint8List();
}

Uint8List? decodeNotesImageDataUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final comma = value.indexOf(',');
  final encoded = value.startsWith('data:') && comma >= 0
      ? value.substring(comma + 1)
      : value;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

String notesImageMimeType(String name, [String? declared]) {
  final clean = declared?.trim().toLowerCase() ?? '';
  if (clean == 'image/png' || clean == 'image/jpeg' || clean == 'image/webp') {
    return clean;
  }
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class NotesImageTooLargeException implements Exception {
  const NotesImageTooLargeException();
}
