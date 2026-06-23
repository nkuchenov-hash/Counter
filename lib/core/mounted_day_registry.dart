/// Tracks which day content bodies are mounted in the widget tree (P0S).
abstract final class MountedDayRegistry {
  static final Map<String, bool> _mounted = <String, bool>{};
  static final Map<String, int> _mountGen = <String, int>{};
  static int _generation = 0;

  static String _key(String screen, String dateKey) => '$screen|$dateKey';

  static void beginWindow(String screen) {
    _generation++;
    _mountGen[screen] = _generation;
  }

  static void markMounted(String screen, String dateKey) {
    _mounted[_key(screen, dateKey)] = true;
  }

  static bool isMounted(String screen, String dateKey) =>
      _mounted[_key(screen, dateKey)] ?? false;

  static int mountedCountIn(String screen, Iterable<String> dateKeys) {
    var n = 0;
    for (final k in dateKeys) {
      if (isMounted(screen, k)) n++;
    }
    return n;
  }

  static void clearScreen(String screen) {
    _mounted.removeWhere((k, _) => k.startsWith('$screen|'));
  }
}
