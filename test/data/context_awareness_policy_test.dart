import 'package:counter/data/context/context_awareness_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native events are ordered and invalid entries discarded', () {
    final list = ContextAwarenessEvent.decode(
      '[{"id":"late","kind":"arrived_home","at":"2026-11-10T13:30:00Z"},'
      '{"id":"early","kind":"left_home","at":"2026-11-10T13:00:00Z"},'
      '{"id":"","kind":"moving","at":"bad"}]',
    );
    expect(list.map((e) => e.id), ['early', 'late']);
    expect(list.first.latitude, isNull);
  });

  test('stop coordinates are optional and parsed without inventing place names', () {
    final events = ContextAwarenessEvent.decode(
      '[{"id":"stop","kind":"stationary_away",'
      '"at":"2026-11-10T13:30:00Z","latitude":59.9,'
      '"longitude":30.3,"accuracy":45}]',
    );
    expect(events.single.latitude, 59.9);
    expect(events.single.longitude, 30.3);
    expect(events.single.accuracy, 45);
  });

  test('home-bound explicit titles only', () {
    expect(ContextTimelinePolicy.isHomeBoundTitle('Reading a book at home'), true);
    expect(ContextTimelinePolicy.isHomeBoundTitle('Читаю книгу дома'), true);
    expect(ContextTimelinePolicy.isHomeBoundTitle('Читаю книгу'), false);
    expect(ContextTimelinePolicy.isHomeBoundTitle('Working from a cafe'), false);
    expect(ContextTimelinePolicy.isHomeBoundTitle('Домашние дела'), false);
  });

  test('departure closes any running record, regardless of title', () {
    final departed = DateTime.utc(2026, 11, 10, 13, 0);
    Map<String, dynamic> row(String title) => {
      'title': title,
      'status': 'running',
      'start_time': DateTime.utc(2026, 11, 10, 12, 30).toIso8601String(),
      'end_time': null,
    };
    expect(ContextTimelinePolicy.canEndOnDeparture(row('Reading at home'), departed), true);
    expect(ContextTimelinePolicy.canEndOnDeparture(row('Reading'), departed), true);
    expect(ContextTimelinePolicy.canEndOnDeparture(row('Work on project'), departed), true);
    expect(ContextTimelinePolicy.canEndOnDeparture(row('Reading at home'), departed.subtract(const Duration(hours: 1))), false);
    expect(ContextTimelinePolicy.canEndOnDeparture({...row('Reading at home'), 'end_time': departed.toIso8601String()}, departed), false);
  });

  test('travel inference does not claim bus, metro or restaurant', () {
    expect(ContextTimelinePolicy.titleForTravel('vehicle', russian: false), 'Vehicle trip');
    expect(ContextTimelinePolicy.titleForTravel('walking', russian: true), 'Пешком');
    expect(ContextTimelinePolicy.isAutoTravelTitle('Метро'), true);
    expect(ContextTimelinePolicy.isAutoTravelTitle('Bus'), true);
    expect(ContextTimelinePolicy.transportTitles(russian: true), contains('Автобус'));
    expect(ContextTimelinePolicy.visitTitle(russian: true), 'Вне дома');
  });
}
