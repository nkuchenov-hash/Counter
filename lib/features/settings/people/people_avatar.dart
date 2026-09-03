import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class PeopleAvatar extends StatelessWidget {
  const PeopleAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.dataUri = '',
    this.bytes,
    this.radius = 24,
  });

  final String name;
  final String imageUrl;
  final String dataUri;
  final Uint8List? bytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final provider = _provider();
    final initials = _initials(name);
    return CircleAvatar(
      radius: radius,
      backgroundImage: provider,
      child: provider == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }

  ImageProvider<Object>? _provider() {
    final local = bytes;
    if (local != null && local.isNotEmpty) return MemoryImage(local);
    final embedded = _dataUriBytes(dataUri);
    if (embedded != null && embedded.isNotEmpty) return MemoryImage(embedded);
    final url = imageUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    return null;
  }

  Uint8List? _dataUriBytes(String raw) {
    final value = raw.trim();
    if (!value.startsWith('data:image/') || !value.contains(';base64,')) {
      return null;
    }
    try {
      return base64Decode(value.substring(value.indexOf(';base64,') + 8));
    } catch (_) {
      return null;
    }
  }

  String _initials(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}
