// Temporary real web-runtime capture entry for Notes v2 tool panels.

import 'package:flutter/material.dart';

import '../../test/notes/fixtures/notes_v2_tools_fixture.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
      ),
      home: const Scaffold(body: NotesV2ToolsFixture()),
    ),
  );
}
