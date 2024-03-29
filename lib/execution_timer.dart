import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

const _kDefaultGroup = '';

/// Container for all execution timers.
class TimeKeeper {
  static final Map<String, Map<String, ExecutionWatch>> _groups =
      SplayTreeMap((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  static bool? _enabled;

  /// Returns whether the the execution times are enabled.  By default, this
  /// will return true when running in debug mode and false when running in
  /// production mode.
  static bool get enabled {
    var enabled = _enabled;

    if (enabled == null) {
      assert(() {
        enabled = true;
        return true;
      }());
    }

    if (enabled != true) {
      clear();
    }

    return enabled == true;
  }

  /// Return all the group names for all the watches and timers.
  static Iterable<String> get groupNames => _groups.keys;

  /// Sets whether or not the execution timers are enabled.  The value set here
  /// will override the default.
  static set enabled(bool enabled) => _enabled = enabled;

  /// Clears the time keeper and removes all timers from the internal cache.
  static void clear() => _groups.clear();

  /// Returns the list of named watches for the given group.  If the group name
  /// doesn't exist, this returns an empty map.
  static Map<String, ExecutionWatch> group(String name) =>
      Map.unmodifiable(_groups[name] ?? const <String, ExecutionWatch>{});

  /// Measures a named [callback].  This will start the timer immediately before
  /// executing the [callback], end the timer as soon as the [callback] ends
  /// and then either throw the exception thrown by [callback] or return the
  /// result from [callback].
  static Future<T> measure<T>(
    String name,
    FutureOr<T> Function(ExecutionTimer timer) callback, {
    String group = _kDefaultGroup,
  }) async {
    T result;
    final watch = ExecutionWatch(
      group: group,
      name: name,
    );

    final timer = watch.start();
    try {
      result = await callback(timer);
    } finally {
      timer.stop();
    }

    return result;
  }

  /// Measures a named [callback].  This functions identically to [measure]
  /// except that it requires the [callback] to be fully synchronous and does
  /// not support futures.
  static T measureSync<T>(
    String name,
    T Function(ExecutionTimer timer) callback, {
    String group = _kDefaultGroup,
  }) {
    T result;
    final watch = ExecutionWatch(
      group: group,
      name: name,
    );

    final timer = watch.start();
    try {
      result = callback(timer);
    } finally {
      timer.stop();
    }

    return result;
  }

  /// Removes a single group from the time keeper.
  static Map<String, ExecutionWatch>? removeGroup(String name) =>
      _groups.remove(name);

  /// Returns all the timers in a JSON-encodable map.
  static Map<String, dynamic> toJson([bool verbose = false]) {
    final result = <String, dynamic>{};

    for (var entry in _groups.entries) {
      final group = <String, dynamic>{};
      result[entry.key] = group;

      for (var e2 in entry.value.entries) {
        group[e2.key] = e2.value.toJson(verbose);
      }
    }

    return result;
  }
}

/// Container for all timers within a given group and name combination.
class ExecutionWatch {
  /// Creates a new watch.  However, if [TimeKeeper.enabled] returns false then
  /// this will actually return a watch that does nothing.
  factory ExecutionWatch({
    String group = _kDefaultGroup,
    required String name,
    TimerPrecision precision = TimerPrecision.millisecond,
  }) {
    ExecutionWatch result;

    if (TimeKeeper.enabled) {
      final timers = TimeKeeper._groups[group] ??
          SplayTreeMap(
            (a, b) => a.toLowerCase().compareTo(
                  b.toLowerCase(),
                ),
          );
      TimeKeeper._groups[group] = timers;

      final timer = timers[name] ??
          ExecutionWatch._(
            group: group,
            name: name,
            precision: precision,
          );
      timers[name] = timer;

      result = timer;
    } else {
      result = _NoOpExecutionWatch(
        group: group,
        name: name,
      );
    }

    return result;
  }

  ExecutionWatch._({
    required this.group,
    required this.name,
    required this.precision,
  });

  /// The group for the watch and timers.
  final String group;

  /// The name of the watch and timers within the group.
  final String name;

  /// The precision to use for the timers.  You may which to use
  /// [TimerPrecision.millisecond] for relatively long running tasks and
  /// [TimerPrecision.microsecond] for multiple, very fast, timers.
  final TimerPrecision precision;

  final List<ExecutionTimer> _timers = [];

  /// Returns all the timers within this watch.
  List<ExecutionTimer> get timers => List.unmodifiable(_timers);

  /// Starts a new timer within this watch.
  ExecutionTimer start() {
    final timer = ExecutionTimer._(this);
    _timers.add(timer);

    return timer;
  }

  Map<String, dynamic> toJson([bool verbose = false]) {
    final times = <int>[];
    int? min;
    int? max;
    var total = 0;

    for (var timer in _timers) {
      final time = timer.runTime;

      max = max == null ? time : math.max(max, time);
      min = min == null ? time : math.min(min, time);

      total += time;
      times.add(time);
    }

    return verbose
        ? {
            'average': total / times.length,
            'min': min,
            'max': max,
            'times': _timers
                .map((e) => {
                      'start': e.startTime,
                      'end': e.endTime,
                      'runTime': e.runTime,
                    })
                .toList()
          }
        : {'times': times};
  }
}

class ExecutionTimer {
  ExecutionTimer._(this._parent)
      : startTime = _parent.precision == TimerPrecision.millisecond
            ? DateTime.now().millisecondsSinceEpoch
            : DateTime.now().microsecondsSinceEpoch;

  final ExecutionWatch _parent;

  final int startTime;

  int? _endTime;

  int? get endTime => _endTime;

  String get group => _parent.group;

  String get name => _parent.name;

  TimerPrecision get precision => _parent.precision;

  /// Returns the number of ticks this timer executed for.  If the timer
  /// has not yet stopped, this will return the amount of time between now and
  /// when the timer was started.
  int get runTime => (endTime ?? _now) - startTime;

  /// Cancels the timer and removes it from the [TimeKeeper].  This action
  /// cannot be undone.
  void cancel() => _parent._timers.remove(this);

  /// Stops the timer and marks the end time as the current time.  If the timer
  /// has already been stopped, this has no effect.
  void stop() => _endTime ??= _now;

  int get _now => precision == TimerPrecision.millisecond
      ? DateTime.now().millisecondsSinceEpoch
      : DateTime.now().microsecondsSinceEpoch;
}

enum TimerPrecision {
  microsecond,
  millisecond,
}

class _NoOpExecutionWatch implements ExecutionWatch {
  _NoOpExecutionWatch({
    required this.group,
    required this.name,
  });

  @override
  final String group;

  @override
  final String name;

  @override
  final TimerPrecision precision = TimerPrecision.millisecond;

  @override
  List<ExecutionTimer> get _timers => const [];

  @override
  ExecutionTimer start() => _NoOpExecutionTimer(this);

  @override
  List<ExecutionTimer> get timers => _timers;

  @override
  Map<String, dynamic> toJson([bool verbose = false]) => const {};
}

class _NoOpExecutionTimer implements ExecutionTimer {
  _NoOpExecutionTimer(this._parent);

  @override
  final TimerPrecision precision = TimerPrecision.millisecond;

  @override
  final int startTime = DateTime.now().millisecondsSinceEpoch;

  @override
  final ExecutionWatch _parent;

  @override
  int? get _endTime => null;

  @override
  set _endTime(int? endTime) {
    // no-op
  }

  @override
  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  String get group => _parent.group;

  @override
  String get name => _parent.name;

  @override
  void cancel() {
    // no-op
  }

  @override
  int? get endTime => null;

  @override
  int get runTime => 0;

  @override
  void stop() {
    // no-op
  }
}
