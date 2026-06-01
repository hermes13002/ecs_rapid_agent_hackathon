/// simple incrementing id generator for circuit elements
abstract final class IdGenerator {
  static int _counter = 0;

  /// generates a unique string id
  static String next(String prefix) {
    _counter++;
    return '$prefix$_counter';
  }

  /// resets the counter (for testing or new project)
  static void reset() => _counter = 0;
}
