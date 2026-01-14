import 'dart:async';

/// ===============================
/// 1️⃣ Debounce - Only execute the last call
/// ===============================
class Debounce {
  final Duration delay;
  Timer? _timer;

  Debounce(this.delay);

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// ===============================
/// 2️⃣ Throttle - Execute at most once per interval
/// ===============================
class Throttle {
  final Duration interval;
  Timer? _timer;
  bool _ready = true;

  Throttle(this.interval);

  void call(void Function() action) {
    if (!_ready) return;

    _ready = false;
    action();

    _timer = Timer(interval, () {
      _ready = true;
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _ready = true;
  }

  void dispose() => cancel();
}

/// =================================================
/// 3️⃣ LeadingDebounce - Execute first call immediately + last call
/// =================================================
class LeadingDebounce {
  final Duration delay;

  Timer? _timer;
  bool _hasPendingTrailing = false;
  bool _leadingExecuted = false;

  LeadingDebounce(this.delay);

  void call({
    required void Function() leading,
    required void Function() trailing,
  }) {
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

  void dispose() => cancel();
}

/// =====================================
/// 4️⃣ Latest - Keep only the latest async task
/// =====================================
class Latest {
  int _token = 0;

  Future<void> run(Future<void> Function() task) async {
    final current = ++_token;

    await task();

    if (current != _token) {
      // Not the last one, result invalidated
      return;
    }
  }

  void reset() {
    _token++;
  }
}
