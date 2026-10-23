import 'package:counter/features/viktor/viktor_chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Viktor editor grows for long pasted text, then scrolls',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Expanded(child: SizedBox()),
          ViktorChatComposer(
            controller: controller,
            onSend: () => sends++,
            onMicrophone: () {},
            inputEnabled: true,
            microphoneEnabled: true,
            sendEnabled: true,
            isListening: false,
          ),
        ]),
      ),
    ));
    final editor = find.byType(TextField);
    expect(tester.getSize(editor).height, lessThan(100));
    await tester.enterText(editor, List.filled(35, 'длинный запрос').join('\n'));
    await tester.pump();
    expect(tester.getSize(editor).height, lessThanOrEqualTo(218));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Отправить Виктору'));
    expect(sends, 1);
  });

  testWidgets('Viktor desktop Enter sends and Shift+Enter does not',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ViktorChatComposer(
          controller: controller,
          onSend: () => sends++,
          onMicrophone: () {},
          inputEnabled: true,
          microphoneEnabled: true,
          sendEnabled: true,
          isListening: false,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'План на завтра');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sends, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 1);
  });
}
