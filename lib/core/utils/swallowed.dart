import 'package:flutter/foundation.dart';

/// A single intentionally-swallowed error, kept for diagnostics.
class SwallowedError {
  SwallowedError({required this.where, required this.error, DateTime? at})
    : at = at ?? DateTime.now();

  final String where;
  final String error;
  final DateTime at;
}

/// In-memory ring buffer of intentionally-swallowed errors.
///
/// The app deliberately ignores many non-critical failures (best-effort schema
/// ALTERs, optional API endpoints, cache refreshes) so the offline flow never
/// blocks on them. This buffer makes those failures visible on the sync
/// diagnostics screen instead of disappearing without a trace — invaluable in
/// the field, where attaching a debugger is not an option.
class SwallowedLog {
  SwallowedLog._();

  static const int _capacity = 200;
  static final List<SwallowedError> _entries = [];

  /// Newest first.
  static List<SwallowedError> get entries =>
      List.unmodifiable(_entries.reversed);

  static void add(String where, Object error) {
    _entries.add(SwallowedError(where: where, error: '$error'));
    if (_entries.length > _capacity) {
      _entries.removeRange(0, _entries.length - _capacity);
    }
  }

  static void clear() => _entries.clear();
}

/// Records an error that is intentionally ignored so the surrounding flow can
/// continue. Use in `catch` blocks that previously swallowed silently:
/// the error lands in [SwallowedLog] (visible on the sync screen) and is
/// printed in debug builds.
void logSwallowed(Object e, String where, [StackTrace? st]) {
  SwallowedLog.add(where, e);
  if (kDebugMode) {
    debugPrint('[swallowed] $where: $e');
  }
}
