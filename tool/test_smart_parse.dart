import 'package:counter/features/planning/smart_input_parser.dart';

void main() {
  for (final s in [
    'test 13.40',
    'test 13.4',
    'test 13.04',
    'вб 13.40',
    '13.40',
    'поход 13:40',
  ]) {
    final r = SmartInputParser.parseTitleForScheduledTime(s);
    print('$s -> ${r?.hour}:${r?.minute} / "${r?.cleanedTitle}"');
  }
}
