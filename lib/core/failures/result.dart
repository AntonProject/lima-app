/// Common expected-error boundary shared by application use cases.
abstract class AppFailure implements Exception {
  final String message;
  final Object? cause;

  const AppFailure(this.message, {this.cause});

  @override
  String toString() => message;
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.cause});
}

class Result<T> {
  final T? value;
  final AppFailure? failure;

  const Result._({this.value, this.failure});

  const Result.success(T value) : this._(value: value);

  const Result.failure(AppFailure failure) : this._(failure: failure);

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;

  T get requireValue {
    final current = value;
    if (current != null) return current;
    throw failure ?? const UnexpectedFailure('Result has no value');
  }
}
