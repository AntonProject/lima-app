class SyncOperationGate {
  Future<void>? _active;

  bool get isRunning => _active != null;

  Future<void> run(
    Future<void> Function() operation, {
    void Function()? onComplete,
  }) {
    final active = _active;
    if (active != null) return active;

    final operationFuture = operation();
    late final Future<void> guarded;
    guarded = operationFuture.whenComplete(() {
      if (identical(_active, guarded)) {
        _active = null;
        onComplete?.call();
      }
    });
    _active = guarded;
    return guarded;
  }
}
