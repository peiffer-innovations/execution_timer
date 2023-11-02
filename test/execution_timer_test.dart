// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:execution_timer/execution_timer.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    TimeKeeper.clear();
  });

  test('cancel', () async {
    TimeKeeper.enabled = true;

    final watch = ExecutionWatch(group: 'test', name: 'test');
    final timer = watch.start();

    await Future.delayed(const Duration(milliseconds: 10));

    timer.stop();

    expect(TimeKeeper.groupNames.isNotEmpty, true);
    expect(watch.timers.length, 1);

    watch.start().stop();

    expect(watch.timers.length, 2);

    timer.cancel();

    expect(watch.timers.length, 1);
  });

  test('enabled', () async {
    TimeKeeper.enabled = true;

    final watch = ExecutionWatch(group: 'test', name: 'test');
    final timer = watch.start();

    await Future.delayed(const Duration(milliseconds: 10));

    timer.stop();

    expect(TimeKeeper.groupNames.isNotEmpty, true);
  });

  test('measure', () async {
    TimeKeeper.enabled = true;

    await TimeKeeper.measure(
      'test',
      (_) async {
        await Future.delayed(const Duration(milliseconds: 10));
      },
      group: 'test',
    );

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 1);

    await TimeKeeper.measure(
      'test',
      (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
      },
      group: 'test',
    );

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 1);

    await TimeKeeper.measure(
      'test2',
      (_) async {
        await Future.delayed(const Duration(milliseconds: 10));
      },
      group: 'test',
    );

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 2);

    await TimeKeeper.measure(
      'test2',
      (_) async {
        await Future.delayed(const Duration(milliseconds: 10));
      },
      group: 'test2',
    );

    expect(TimeKeeper.groupNames.length, 2);
    expect(TimeKeeper.group('test').length, 2);
    expect(TimeKeeper.group('test2').length, 1);

    final output = TimeKeeper.toJson(true);

    print(const JsonEncoder.withIndent('  ').convert(output));

    expect(output['test']['test']['times'].length, 2);
    expect(output['test2']['test2']['times'].length, 1);
  });

  test('not enabled', () async {
    TimeKeeper.enabled = false;

    final watch = ExecutionWatch(group: 'test', name: 'test');
    final timer = watch.start();

    await Future.delayed(const Duration(milliseconds: 100));

    timer.stop();

    final startTime = DateTime.now().millisecondsSinceEpoch;
    await TimeKeeper.measure<void>('test2', (_) async {
      await Future.delayed(const Duration(milliseconds: 100));
    }, group: 'foo');
    // prove the callback got executed even if the timer was a no-op.
    expect(DateTime.now().millisecondsSinceEpoch - startTime, greaterThan(90));

    expect(TimeKeeper.groupNames.isEmpty, true);
  });

  test('removeGroup', () async {
    TimeKeeper.enabled = true;

    final watch = ExecutionWatch(group: 'test', name: 'test');
    final timer = watch.start();

    await Future.delayed(const Duration(milliseconds: 10));

    timer.stop();

    expect(TimeKeeper.groupNames.isNotEmpty, true);

    TimeKeeper.removeGroup('test');
    expect(TimeKeeper.groupNames.isEmpty, true);
  });

  test('precision', () async {
    TimeKeeper.enabled = true;

    final microsecond = ExecutionWatch(
      group: 'test',
      name: 'microsecond',
      precision: TimerPrecision.microsecond,
    );
    final millisecond = ExecutionWatch(
      group: 'test',
      name: 'millisecond',
      precision: TimerPrecision.millisecond,
    );
    final millisecondWatch = millisecond.start();
    final microsecondWatch = microsecond.start();
    await Future.delayed(const Duration(milliseconds: 2));
    millisecondWatch.stop();
    microsecondWatch.stop();

    expect(millisecondWatch.runTime, greaterThanOrEqualTo(1));
    expect(millisecondWatch.runTime, lessThan(10));
    expect(microsecondWatch.runTime, greaterThanOrEqualTo(1000));
  });

  test('timing', () async {
    TimeKeeper.enabled = true;

    var watch = ExecutionWatch(group: 'test', name: 'test');
    var timer = watch.start();
    await Future.delayed(const Duration(milliseconds: 10));
    timer.stop();

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 1);
    expect(watch.timers.length, 1);
    expect(timer.runTime, greaterThanOrEqualTo(9));

    watch = ExecutionWatch(group: 'test', name: 'test');
    timer = watch.start();
    await Future.delayed(const Duration(milliseconds: 100));
    timer.stop();

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 1);
    expect(watch.timers.length, 2);
    expect(timer.runTime, greaterThanOrEqualTo(90));

    watch = ExecutionWatch(group: 'test', name: 'test2');
    timer = watch.start();
    await Future.delayed(const Duration(milliseconds: 10));
    timer.stop();

    expect(TimeKeeper.groupNames.length, 1);
    expect(TimeKeeper.group('test').length, 2);
    expect(watch.timers.length, 1);

    watch = ExecutionWatch(group: 'test2', name: 'test2');
    timer = watch.start();
    await Future.delayed(const Duration(milliseconds: 10));
    timer.stop();

    expect(TimeKeeper.groupNames.length, 2);
    expect(TimeKeeper.group('test').length, 2);
    expect(TimeKeeper.group('test2').length, 1);
    expect(watch.timers.length, 1);

    final output = TimeKeeper.toJson(true);

    print(const JsonEncoder.withIndent('  ').convert(output));

    expect(output['test']['test']['times'].length, 2);
    expect(output['test2']['test2']['times'].length, 1);
  });
}
