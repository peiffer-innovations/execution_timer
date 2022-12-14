# execution_timer

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Introduction](#introduction)
- [Using the Library](#using-the-library)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

Provides a simple way to time parts of code as they execute in real, clock, 
time.


## Using the Library

Add the repo to your Dart `pubspec.yaml` file.

```
dependencies:
  execution_timer: <<version>> 
```

Then run...
```
dart pub get
```


By default, the timing is enabled in debug mode but disabled in production mode.
To change this set `TimeKeeper.enabled` to be `true` or `false`.  Since this
is not a Flutter library, it can be used in any Dart base application, but it
cannot detect Profile mode vs Debug.  

There are two ways to perform a time measurement.

1. Use the `ExecutionWatch` and `ExecutionTimer` to manually measure your timing:
    ```dart
    // This option will be more performant for loops like the following...

    final watch = ExecutionWatch(group: 'myGroup', name: 'myTimerName');

    for (var i = 0; i < someCount; i++) {
      final timer = watch.start();
      // do something worth measuring
      timer.stop();
    }

    // each iteration from the loop will be individually timed
    ```
2. Use the `TimeKeeper.measure` function:
    ```dart
    // This option may be easier for timing long-ish running units of work with
    // return values.

    final result = await TimeKeeper.measure<X>(
      'myTimerName',
      (timer) async {
        X result;

        // doSomething that assigns X to the result

        return result;
      },
      group: 'myOptionalGroupName',
    );
    ```

When you need the results, you can get them from:
```dart
final timings = TimeKeeper.toJson();

print(const JsonEncoder.withIndent('  ').convert(timings));
```