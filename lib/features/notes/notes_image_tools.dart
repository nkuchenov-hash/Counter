import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clipboard/clipboard.dart';

// Android originals live in app-private, account-scoped storage. The existing
// image block stores only an opaque identifier, never a device path or bytes.
const _localImageChannel = MethodChannel('counter/notes_local_images');
const _localImagePrefix = 'lifeos-local-image:v1:';
bool get _useLocalImages => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool isLocalNotesImage(String? value) => value?.startsWith(_localImagePrefix) ?? false;
String _localImageOwner() {
  final owner = DatabaseService.instance.currentProfileId?.trim() ?? '';
  if (owner.isEmpty) throw StateError('image_owner_missing');
  return owner;
}
Future<String> _storeLocalNotesImage({String? path, Uint8List? bytes,
    required String name}) async {
  final id = await _localImageChannel.invokeMethod<String>('store', {
    'owner': _localImageOwner(), 'path': path, 'bytes': bytes, 'name': name,
  });
  if (id == null || id.isEmpty) throw StateError('image_store_failed');
  return '$_localImagePrefix$id';
}
Future<Uint8List?> readNotesImagePreview(String? value) async {
  if (value == null) return null;
  if (!isLocalNotesImage(value)) return decodeNotesImageDataUrl(value);
  if (!_useLocalImages) return null;
  try {
    return await _localImageChannel.invokeMethod<Uint8List>('preview', {
      'owner': _localImageOwner(), 'id': value.substring(_localImagePrefix.length),
    });
  } on PlatformException {
    return null;
  } on StateError {
    return null;
  }
}

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
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif', 'avif', 'tif', 'tiff'],
            mimeTypes: ['image/*'],
            uniformTypeIdentifiers: ['public.image'],
          ),
        ],
      );
    case NotesImageSourceChoice.gallery:
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: _useLocalImages ? null : 1600,
        maxHeight: _useLocalImages ? null : 1600,
        imageQuality: _useLocalImages ? null : 85,
      );
    case NotesImageSourceChoice.camera:
      file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: _useLocalImages ? null : 1600,
        maxHeight: _useLocalImages ? null : 1600,
        imageQuality: _useLocalImages ? null : 85,
      );
  }
  if (file == null) return null;
  if (_useLocalImages) {
    final ref = await _storeLocalNotesImage(path: file.path, name: file.name);
    return NotesPickedImage(dataUrl: ref, fileName: file.name);
  }
  return prepareNotesImage(
    await file.readAsBytes(),
    fileName: file.name,
    mimeType: file.mimeType,
  );
}

/// Store supported small originals. For any decodable oversized image,
/// progressively normalize/rescale until the inline asset budget is met.
/// File size alone is never a reason to reject the user's selection.
Future<NotesPickedImage> prepareNotesImage(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  int maxAssetBytes = kLifeOsNotesMaxAssetBytes,
}) async {
  if (bytes.isEmpty) throw StateError('image_empty');
  if (maxAssetBytes < 1024) throw ArgumentError.value(maxAssetBytes);
  var data = bytes;
  final originalType = _knownNotesImageType(bytes);
  var type = originalType ?? notesImageMimeType(fileName, mimeType);
  if (data.lengthInBytes > maxAssetBytes || originalType == null) {
    data = await _resizeNotesImageToFit(data, maxAssetBytes);
    type = 'image/png';
  }
  return NotesPickedImage(
    dataUrl: 'data:$type;base64,${base64Encode(data)}',
    fileName: fileName,
  );
}

// Sniff the actual encoding instead of trusting an Android provider's
// extension/MIME metadata. Unknown but decodable formats are normalized.
String? _knownNotesImageType(Uint8List data) {
  if (data.length >= 8 &&
      data[0] == 137 && data[1] == 80 && data[2] == 78 && data[3] == 71 &&
      data[4] == 13 && data[5] == 10 && data[6] == 26 && data[7] == 10) {
    return 'image/png';
  }
  if (data.length >= 3 && data[0] == 255 && data[1] == 216 && data[2] == 255) {
    return 'image/jpeg';
  }
  if (data.length >= 12 &&
      String.fromCharCodes(data.take(4)) == 'RIFF' &&
      String.fromCharCodes(data.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  if (data.length >= 6 &&
      (String.fromCharCodes(data.take(6)) == 'GIF87a' ||
       String.fromCharCodes(data.take(6)) == 'GIF89a')) {
    return 'image/gif';
  }
  if (data.length >= 2 && data[0] == 66 && data[1] == 77) {
    return 'image/bmp';
  }
  return null;
}

Future<Uint8List> _resizeNotesImageToFit(Uint8List bytes, int budget) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      // Try the original dimensions when already small, stripping excessive
      // metadata, then keep reducing. A valid 480px (or smaller) image must
      // never fall through the loop without even attempting to encode it.
      var limit = longest > 1600 ? 1600 : longest;
      while (limit >= 1) {
        final scale = limit / longest;
        final width = (descriptor.width * scale).round().clamp(1, limit).toInt();
        final height = (descriptor.height * scale).round().clamp(1, limit).toInt();
        final codec = await descriptor.instantiateCodec(
          targetWidth: width,
          targetHeight: height,
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final data = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data != null && data.lengthInBytes <= budget) {
              return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
        if (limit == 1) break;
        limit = (limit * 0.75).floor().clamp(1, limit - 1).toInt();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
  throw StateError('image_encode_failed');
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
}) async {
  final bytes = await readNotesImagePreview(dataUrl);
  if (!context.mounted || bytes == null) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => NotesImageCropPage(dataUrl: 'data:image/png;base64,${base64Encode(bytes)}'),
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
      final ByteData? data;
      try {
        data = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (data == null) throw StateError('crop_encode_failed');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final result = _useLocalImages
          ? await _storeLocalNotesImage(bytes: bytes, name: 'crop.png')
          : (await prepareNotesImage(bytes, fileName: 'crop.png')).dataUrl;
      if (!mounted) return;
      Navigator.of(context).pop(result);
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
      content: AppTextField(
        controller: controller,
        autofocus: true,
        variant: AppTextFieldVariant.multiline,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        hintText: t(loc, 'notes_image_caption_hint'),
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
  if (isLocalNotesImage(dataUrl)) {
    if (!_useLocalImages) throw StateError('image_local_only');
    final path = await _localImageChannel.invokeMethod<String>('original', {
      'owner': _localImageOwner(), 'id': dataUrl.substring(_localImagePrefix.length),
    });
    if (path == null) throw StateError('image_local_missing');
    final extension = path.split('.').last;
    return FileSaver.instance.saveAs(
      name: 'life_os_note_${DateTime.now().millisecondsSinceEpoch}',
      filePath: path, fileExtension: extension, mimeType: MimeType.other,
    );
  }
  final bytes = await notesImagePngBytes(dataUrl);
  return FileSaver.instance.saveAs(
    name: 'life_os_note_${DateTime.now().millisecondsSinceEpoch}',
    bytes: bytes,
    fileExtension: 'png',
    mimeType: MimeType.png,
  );
}

Future<Uint8List> notesImagePngBytes(String dataUrl) async {
  final bytes = await readNotesImagePreview(dataUrl);
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

