from __future__ import annotations

from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one anchor, found {count}: {old[:140]!r}")
    write(path, content.replace(old, new, 1))


write(
    "lib/features/notes/notes_image_tools.dart",
    dedent(
        r'''import 'dart:convert';
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
import 'package:super_clipboard/super_clipboard.dart';

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
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
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
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject()
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
      Navigator.of(context).pop(
        'data:image/png;base64,${base64Encode(bytes)}',
      );
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
        SnackBar(content: Text(t(currentLocale.value, 'notes_image_crop_failed'))),
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
            Navigator.of(dialogContext).pop(
              NotesCaptionResult(value.isEmpty ? null : value),
            );
          },
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<void> copyNotesImage(String dataUrl) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) throw StateError('clipboard_unavailable');
  final bytes = await notesImagePngBytes(dataUrl);
  final item = DataWriterItem(suggestedName: 'life-os-note.png');
  item.add(Formats.png(bytes));
  await clipboard.write([item]);
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
  if (clean == 'image/png' ||
      clean == 'image/jpeg' ||
      clean == 'image/webp') {
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
'''
    ),
)

# Dependencies.
replace_once(
    "pubspec.yaml",
    "  audioplayers: ^6.8.1\n  tray_manager:",
    "  audioplayers: ^6.8.1\n  image_picker: ^1.2.3\n  super_clipboard: ^0.9.1\n  file_saver: ^0.4.0\n  tray_manager:",
)

# Android rich-image clipboard provider.
replace_once(
    "android/app/src/main/AndroidManifest.xml",
    "        <meta-data\n            android:name=\"flutterEmbedding\"",
    "        <provider\n            android:name=\"com.superlist.super_native_extensions.DataProvider\"\n            android:authorities=\"${applicationId}.SuperClipboardDataProvider\"\n            android:exported=\"true\"\n            android:grantUriPermissions=\"true\" />\n        <meta-data\n            android:name=\"flutterEmbedding\"",
)

# iOS picker permissions.
replace_once(
    "ios/Runner/Info.plist",
    "\t<key>NSFaceIDUsageDescription</key>\n\t<string>Unlock the app with Face ID</string>",
    "\t<key>NSFaceIDUsageDescription</key>\n\t<string>Unlock the app with Face ID</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>Select images to add to Life OS notes.</string>\n\t<key>NSCameraUsageDescription</key>\n\t<string>Take photos to add to Life OS notes.</string>",
)

# Editor tools menu adds all image actions.
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "  VoidCallback? onEditMedia,\n}) {",
    "  VoidCallback? onEditMedia,\n  VoidCallback? onCropImage,\n  VoidCallback? onEditImageCaption,\n  VoidCallback? onCopyImage,\n  VoidCallback? onSaveImage,\n}) {",
)
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "              onEditMedia,\n            ),\n          if (block.type == NoteBlockType.table",
    "              onEditMedia,\n            ),\n          if (block.type == NoteBlockType.image) ...[\n            if (onCropImage != null)\n              _sheetAction(\n                sheetContext,\n                Icons.crop_rounded,\n                'Crop',\n                onCropImage,\n              ),\n            if (onEditImageCaption != null)\n              _sheetAction(\n                sheetContext,\n                Icons.closed_caption_outlined,\n                'Add or edit caption',\n                onEditImageCaption,\n              ),\n            if (onCopyImage != null)\n              _sheetAction(\n                sheetContext,\n                Icons.copy_rounded,\n                'Copy image',\n                onCopyImage,\n              ),\n            if (onSaveImage != null)\n              _sheetAction(\n                sheetContext,\n                Icons.download_rounded,\n                'Save to device',\n                onSaveImage,\n              ),\n          ],\n          if (block.type == NoteBlockType.table",
)

# Page uses one platform-aware picker and real image operations.
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "import 'dart:convert';\n\n",
    "",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "import 'package:counter/features/notes/notes_glm_surface.dart';",
    "import 'package:counter/features/notes/notes_glm_surface.dart';\nimport 'package:counter/features/notes/notes_image_tools.dart';",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "import 'package:file_selector/file_selector.dart';\n",
    "",
)
old_pick = '''  Future<void> _pickImage({String? replaceBlockId}) async {
    if (widget.parityPreview) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > kLifeOsNotesMaxAssetBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(currentLocale.value, 'notes_v3_editor_image_too_large'),
            ),
          ),
        );
        return;
      }
      final dataUrl =
          'data:${_imageMimeType(file.name)};base64,${base64Encode(bytes)}';
      final mutation = replaceBlockId == null
          ? _editor.insertAfter(
              _editor.activeBlockId,
              NoteBlockType.image,
              imageData: dataUrl,
            )
          : _editor.updateMedia(replaceBlockId, imageData: dataUrl);
      _applyMutation(mutation);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_v3_editor_load_failed')),
        ),
      );
    }
  }
'''
new_pick = dedent(
    r'''  Future<void> _pickImage({String? replaceBlockId}) async {
    if (widget.parityPreview) return;
    try {
      final picked = await pickNotesImage(context: context);
      if (!mounted || picked == null) return;
      final mutation = replaceBlockId == null
          ? _editor.insertAfter(
              _editor.activeBlockId,
              NoteBlockType.image,
              imageData: picked.dataUrl,
            )
          : _editor.updateMedia(replaceBlockId, imageData: picked.dataUrl);
      _applyMutation(mutation);
    } on NotesImageTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(currentLocale.value, 'notes_v3_editor_image_too_large'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_v3_editor_load_failed')),
        ),
      );
    }
  }

  Future<void> _cropImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    final cropped = await showNotesImageCropper(
      context: context,
      dataUrl: dataUrl,
    );
    if (!mounted || cropped == null) return;
    _applyMutation(_editor.updateMedia(blockId, imageData: cropped));
  }

  Future<void> _editImageCaption(String blockId) async {
    final block = _editor.blockById(blockId);
    if (block == null || block.type != NoteBlockType.image) return;
    final result = await showNotesImageCaptionDialog(
      context: context,
      currentCaption: block.caption,
    );
    if (!mounted || result == null) return;
    _applyMutation(_editor.updateCaption(blockId, result.caption ?? ''));
  }

  Future<void> _copyImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    try {
      await copyNotesImage(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'notes_image_copied'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_image_copy_failed')),
        ),
      );
    }
  }

  Future<void> _saveImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    try {
      await saveNotesImage(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'notes_image_saved'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_image_save_failed')),
        ),
      );
    }
  }
'''
)
replace_once("lib/features/notes/note_editor_page.dart", old_pick, new_pick)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "        _ => null,\n      },\n    );",
    "        _ => null,\n      },\n      onCropImage: block.type == NoteBlockType.image\n          ? () => _cropImage(block.id)\n          : null,\n      onEditImageCaption: block.type == NoteBlockType.image\n          ? () => _editImageCaption(block.id)\n          : null,\n      onCopyImage: block.type == NoteBlockType.image\n          ? () => _copyImage(block.id)\n          : null,\n      onSaveImage: block.type == NoteBlockType.image\n          ? () => _saveImage(block.id)\n          : null,\n    );",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "\nString _imageMimeType(String name) {\n  final lower = name.toLowerCase();\n  if (lower.endsWith('.png')) return 'image/png';\n  if (lower.endsWith('.webp')) return 'image/webp';\n  return 'image/jpeg';\n}\n",
    "",
)

# Localization.
en = dedent(
    r'''  'notes_image_source_title': 'Add image',
  'notes_image_source_files': 'Choose from files',
  'notes_image_source_gallery': 'Choose from gallery',
  'notes_image_source_camera': 'Take a photo',
  'notes_image_crop_title': 'Crop image',
  'notes_image_crop_apply': 'Apply',
  'notes_image_crop_hint': 'Pinch to zoom and drag to position the image.',
  'notes_image_crop_failed': 'Could not crop this image.',
  'notes_image_caption_title': 'Image caption',
  'notes_image_caption_hint': 'Add a caption…',
  'notes_image_copied': 'Image copied',
  'notes_image_copy_failed': 'Could not copy the image.',
  'notes_image_saved': 'Image saved',
  'notes_image_save_failed': 'Could not save the image.',
'''
)
ru = dedent(
    r'''  'notes_image_source_title': 'Добавить изображение',
  'notes_image_source_files': 'Выбрать из файлов',
  'notes_image_source_gallery': 'Выбрать из галереи',
  'notes_image_source_camera': 'Сделать фото',
  'notes_image_crop_title': 'Кадрирование',
  'notes_image_crop_apply': 'Применить',
  'notes_image_crop_hint': 'Масштабируйте и перемещайте изображение внутри рамки.',
  'notes_image_crop_failed': 'Не удалось обрезать изображение.',
  'notes_image_caption_title': 'Подпись к изображению',
  'notes_image_caption_hint': 'Добавьте подпись…',
  'notes_image_copied': 'Изображение скопировано',
  'notes_image_copy_failed': 'Не удалось скопировать изображение.',
  'notes_image_saved': 'Изображение сохранено',
  'notes_image_save_failed': 'Не удалось сохранить изображение.',
'''
)
replace_once(
    "lib/l10n/langs/en.dart",
    "  'notes_audio_title': 'Audio recording',",
    en + "\n  'notes_audio_title': 'Audio recording',",
)
replace_once(
    "lib/l10n/langs/ru.dart",
    "  'notes_audio_title': 'Аудиозапись',",
    ru + "\n  'notes_audio_title': 'Аудиозапись',",
)

# Exact structure inventory.
replace_once(
    "docs/APP_STRUCTURE.md",
    "| `notes/notes_audio_controller.dart` | Cross-platform in-memory PCM recorder, WAV codec, byte playback, recorder/transcript modal orchestration |\n| `notes/notes_editor_document_controller.dart`",
    "| `notes/notes_audio_controller.dart` | Cross-platform in-memory PCM recorder, WAV codec, byte playback, recorder/transcript modal orchestration |\n| `notes/notes_image_tools.dart` | Shared file/gallery/camera picker, crop surface, caption dialog, rich-image clipboard, and save-to-device helpers |\n| `notes/notes_editor_document_controller.dart`",
)
replace_once(
    "docs/APP_STRUCTURE.md",
    "`drawing_canvas_page.dart`, `notes_audio_controller.dart`, `notes_editor_document_controller.dart`,",
    "`drawing_canvas_page.dart`, `notes_audio_controller.dart`, `notes_image_tools.dart`, `notes_editor_document_controller.dart`,",
)

# Keep exactly three tests; extend the existing core test with data-url helpers.
replace_once(
    "test/notes_canonical_components_test.dart",
    "import 'package:counter/features/notes/notes_editor_document_controller.dart';",
    "import 'package:counter/features/notes/notes_editor_document_controller.dart';\nimport 'package:counter/features/notes/notes_image_tools.dart';",
)
replace_once(
    "test/notes_canonical_components_test.dart",
    "      final legacy = NoteBlock(\n        id: 'legacy-reference',",
    "      expect(\n        decodeNotesImageDataUrl('data:image/png;base64,AQID'),\n        Uint8List.fromList([1, 2, 3]),\n      );\n      expect(notesImageMimeType('photo.webp'), 'image/webp');\n\n      final legacy = NoteBlock(\n        id: 'legacy-reference',",
)
replace_once(
    "test/notes_canonical_components_test.dart",
    "import 'dart:convert';",
    "import 'dart:convert';\nimport 'dart:typed_data';",
)

print('Notes image phase patched successfully.')
