import 'dart:async';

/// ===============================
/// 1️⃣ Debounce - Only execute the last call
/// ===============================
class Debounce {
  final Duration delay;
  Timer? _timer;
  bool _isDisposed = false;

  Debounce(this.delay);

  void call(void Function() action) {
    if (_isDisposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_isDisposed) return;
      action();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _isDisposed = true;
    cancel();
  }
}

/// ===============================
/// 2️⃣ Throttle - Execute at most once per interval
/// ===============================
class Throttle {
  final Duration interval;
  Timer? _timer;
  bool _ready = true;
  bool _isDisposed = false;

  Throttle(this.interval);

  void call(void Function() action) {
    if (_isDisposed || !_ready) return;

    _ready = false;
    action();

    _timer = Timer(interval, () {
      if (_isDisposed) return;
      _ready = true;
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _ready = true;
  }

  void dispose() {
    _isDisposed = true;
    cancel();
  }
}

/// =================================================
/// 3️⃣ LeadingDebounce - Execute first call immediately + last call
/// =================================================
class LeadingDebounce {
  final Duration delay;

  Timer? _timer;
  bool _hasPendingTrailing = false;
  bool _leadingExecuted = false;
  bool _isDisposed = false;

  LeadingDebounce(this.delay);

  void call({
    required void Function() leading,
    required void Function() trailing,
  }) {
    if (_isDisposed) return;

    // First time window entered: execute leading
    if (!_leadingExecuted) {
      _leadingExecuted = true;
      leading();
    } else {
      // Mark trailing needed only if there are consecutive triggers
      _hasPendingTrailing = true;
    }

    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_isDisposed) return;

      if (_hasPendingTrailing) {
        trailing();
      }

      // reset window
      _leadingExecuted = false;
      _hasPendingTrailing = false;
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _leadingExecuted = false;
    _hasPendingTrailing = false;
  }

  void dispose() {
    _isDisposed = true;
    cancel();
  }
}

/// =====================================
/// 4️⃣ Latest - Keep only the latest async task
/// =====================================
class Latest {
  int _token = 0;
  bool _isDisposed = false;

  Future<void> run(Future<void> Function() task) async {
    if (_isDisposed) return;

    final current = ++_token;

    await task();

    if (_isDisposed || current != _token) {
      // Disposed or not the last one, result invalidated
      return;
    }
  }

  void reset() {
    _token++;
  }

  void dispose() {
    _isDisposed = true;
  }
}
