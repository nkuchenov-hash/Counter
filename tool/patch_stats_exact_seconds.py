from pathlib import Path

p = Path('lib/features/stats/day_stats_dashboard.dart')
s = p.read_text()

# Mobile overview mini timeline.
s = s.replace(
'''    final rangeMinutes = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inMinutes,
    );
    final middle = data.rangeStartWall.add(
      Duration(minutes: (rangeMinutes / 2).round()),
    );''',
'''    final rangeSeconds = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inSeconds,
    );
    final middle = data.rangeStartWall.add(
      Duration(seconds: (rangeSeconds / 2).round()),
    );'''
)
s = s.replace(
'''                    final start = session.startWall
                        .difference(data.rangeStartWall)
                        .inMinutes
                        .clamp(0, rangeMinutes);
                    final end = session.endWall
                        .difference(data.rangeStartWall)
                        .inMinutes
                        .clamp(0, rangeMinutes);
                    final top = start / rangeMinutes * (height - 16) + 5;
                    final h = (end - start) / rangeMinutes * (height - 16);''',
'''                    final start = session.startWall
                        .difference(data.rangeStartWall)
                        .inSeconds
                        .clamp(0, rangeSeconds);
                    final end = session.endWall
                        .difference(data.rangeStartWall)
                        .inSeconds
                        .clamp(0, rangeSeconds);
                    final top = start / rangeSeconds * (height - 16) + 5;
                    final h = (end - start) / rangeSeconds * (height - 16);'''
)

# Full zoomable Day view.
s = s.replace(
'''    final rangeMinutes = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inMinutes,
    );
    final gridHeight = rangeMinutes / 60 * hourHeight;''',
'''    final rangeSeconds = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inSeconds,
    );
    final gridHeight = rangeSeconds / 3600 * hourHeight;'''
)
s = s.replace(
'''.difference(data.rangeStartWall)
                                    .inMinutes /
                                60 *
                                hourHeight;''',
'''.difference(data.rangeStartWall)
                                    .inSeconds /
                                3600 *
                                hourHeight;'''
)
s = s.replace(
'''.difference(data.rangeStartWall)
                                      .inMinutes /
                                  60 *
                                  hourHeight;''',
'''.difference(data.rangeStartWall)
                                      .inSeconds /
                                  3600 *
                                  hourHeight;'''
)
s = s.replace(
'''                            final startMinutes = session.startWall
                                .difference(data.rangeStartWall)
                                .inMinutes
                                .clamp(0, rangeMinutes);
                            final endMinutes = session.endWall
                                .difference(data.rangeStartWall)
                                .inMinutes
                                .clamp(0, rangeMinutes);
                            final top = startMinutes / 60 * hourHeight;
                            final rawHeight =
                                (endMinutes - startMinutes) / 60 * hourHeight;''',
'''                            final startSeconds = session.startWall
                                .difference(data.rangeStartWall)
                                .inSeconds
                                .clamp(0, rangeSeconds);
                            final endSeconds = session.endWall
                                .difference(data.rangeStartWall)
                                .inSeconds
                                .clamp(0, rangeSeconds);
                            final top = startSeconds / 3600 * hourHeight;
                            final rawHeight =
                                (endSeconds - startSeconds) / 3600 * hourHeight;'''
)

p.write_text(s)
