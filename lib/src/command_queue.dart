import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';

import 'command.dart';

class CommandQueue<T> {
  CommandQueue({this.debugLabel});

  /// A label that can be used to identify the processor.
  final String? debugLabel;

  final _processItemQueue = Queue<CommandQueueItem<T>>();
  final _identifiers = <(int, String)>[];

  Completer<void> _pauseCompleter = Completer<void>()..complete();
  bool _isRunning = false;
  int _count = 1;

  CommandQueueItem<T>? _current;

  /// Adds a process to the queue and returns a [CommandQueueItem].
  ///
  /// If [identifier] is provided and [ignoreIfContainsIdentifier] is `true`, the
  /// process will not be added to the queue if the same identifier is already
  /// on the identifiers list. In this case the method will return `null`.
  ///
  /// Identifiers can be kept on a list for a certain amount of time. This
  /// time can be set with [timeToStoreIdentifier].
  ///
  /// If no time was set, the identifier will be removed from the list as soon
  /// as the process is completed.
  ///
  /// If the process takes longer than the time set, the identifier will be
  /// removed from the list when the process is completed.
  ///
  /// If the processor is paused, the process will be added to the queue but
  /// will not be executed until the processor is resumed.
  ///
  /// If you want to start the processor, use [resume].
  CommandQueueItem<T>? addCommand(
    Command<T> command, {
    String? identifier,
    bool ignoreIfContainsIdentifier = false,
    Duration timeToStoreIdentifier = Duration.zero,
  }) {
    assert(
      !timeToStoreIdentifier.isNegative,
      'timeToStoreIdentifier must be positive',
    );
    if ((identifier != null) && containsIdentifier(identifier)) {
      return null;
    }
    late final CommandQueueItem<T> item;
    item = CommandQueueItem.command(
      command,
      id: _count++,
      identifier: identifier,
      timeToStoreIdentifier: timeToStoreIdentifier,
      onCancel: () => _identifiers.remove((item.id, item.identifier)),
    );
    _identifiers.add((item.id, item.identifier));
    _processItemQueue.add(item);

    if (!isRunning) {
      unawaited(_runProcessor());
    }

    return item;
  }

  /// Processes a function and returns a [Future] that will complete when the
  /// function is done.
  ///
  /// If [identifier] is provided and [ignoreIfContainsIdentifier] is `true`,
  /// the process will not be added to the queue if the same identifier is
  /// already on the queue. In this case the method will return `null`.
  ///
  /// Identifiers can be kept on the queue for a certain amount of time. This
  /// time can be set with [timeToStoreIdentifier].
  ///
  /// If no time was set, the identifier will be removed from the list as soon
  /// as the process is completed.
  ///
  /// If the process takes longer than the time set, the identifier will be
  /// removed from the list when the process is completed.
  ///
  /// If the processor is paused, the process will be added to the queue but
  /// will not be executed until the processor is resumed.
  ///
  /// If you want to start the processor, use [resume].
  Future<Result<T>>? process(
    Command<T> command, {
    String? identifier,
    bool ignoreIfContainsIdentifier = false,
    Duration timeToStoreIdentifier = Duration.zero,
  }) {
    assert(
      !timeToStoreIdentifier.isNegative,
      'timeToStoreIdentifier must be positive',
    );
    final item = addCommand(
      command,
      identifier: identifier,
      timeToStoreIdentifier: timeToStoreIdentifier,
      ignoreIfContainsIdentifier: ignoreIfContainsIdentifier,
    );
    return item?.result.future;
  }

  /// Runs the processor.
  ///
  /// This will run the processes that are on the queue.
  /// If the processor is paused, it will not run the processes.
  Future<void> _runProcessor() async {
    _isRunning = true;

    while (_processItemQueue.isNotEmpty && !isPaused) {
      _current = _processItemQueue.removeFirst();

      if (!_current!.isCanceled) {
        Timer(
          _current!.timeToStoreIdentifier.isNegative
              ? Duration.zero
              : _current!.timeToStoreIdentifier,
          () async {
            await _current!.result.future;
            _identifiers.remove((_current!.id, _current!.identifier));
          },
        );
        await _current!._execute();
      }
    }

    _isRunning = false;
  }

  /// Waits for all the processes to complete.
  ///
  /// If [completeOnPause] is `true`, the method will complete when the
  /// processor is paused. Otherwise, it will wait for all the processes to
  /// complete.
  ///
  /// When [completeOnPause] is `false`, this will wait for a call to [resume]
  /// and then for any remaining processes to complete.
  Future<void> waitAll({bool completeOnPause = false}) async {
    final queue = [?_current, ..._processItemQueue];
    while (queue.where((p) => !p.isCanceled).isNotEmpty &&
        (!completeOnPause || !isPaused)) {
      if (isPaused) {
        await waitForResume();
        continue;
      }
      await queue.first.result.future.then<void>((_) {}, onError: (_) {});
    }
  }

  /// Cancels all the processes that are on the queue.
  void cancelAll() {
    for (final processItem in _processItemQueue) {
      processItem.cancel();
    }
  }

  /// Returns `true` if the process is on the queue.
  ///
  /// This does not mean that the process is running. It only means that the
  /// process is waiting to be executed.
  bool onQueue(CommandQueueItem<T> processItem) {
    return _processItemQueue.contains(processItem);
  }

  /// Returns `true` if the identifier is on the identifiers list.
  ///
  /// Identifiers can be kept on a list for a certain amount of time (even after
  /// the linked item has completely finished). This time can be set when adding
  /// a process to the queue.
  ///
  /// This means that even if the process is already completed, the identifier
  /// can still be on this list.
  ///
  /// If no time was set, the identifier will be removed from the list as soon
  /// as the process is completed.
  ///
  /// If the process takes longer than the time set, the identifier will be
  /// removed from the list when the process is completed.
  ///
  /// This can be useful to prevent the same process from being added to the
  /// queue multiple times in a short period of time.
  bool containsIdentifier(String identifier) {
    return _identifiers.any((r) => r.$2 == identifier);
  }

  /// Pauses the processor.
  ///
  /// This does not cancel the processes that are already on the queue, for
  /// this use [cancelAll].
  ///
  /// If there is a running process, it will be completed since we can't
  /// actually pause a running process.
  ///
  /// Look at [isPaused] to check if the processor is paused.
  /// Look at [isRunning] to check if the processor is running.
  /// To resume the processor, use [resume].
  void pause() {
    if (!_pauseCompleter.isCompleted) {
      return;
    }
    _pauseCompleter = Completer<void>();
  }

  /// Resumes the processor.
  ///
  /// Look at [isPaused] to check if the processor is paused.
  /// To pause the processor, use [pause].
  void resume() {
    if (!isPaused) {
      return;
    }
    _pauseCompleter.complete();

    if (!isRunning) {
      unawaited(_runProcessor());
    }
  }

  /// Cancels all the processes that are on the queue and disposes the
  /// processor.
  Future<void> dispose() async {
    cancelAll();
    resume();
    await waitAll();
  }

  @override
  String toString() {
    return 'FutureProcessor<$T>(${debugLabel ?? hashCode})';
  }

  /// Waits for the processor to be resumed.
  ///
  /// This is useful when you want to wait for the processor to be resumed
  /// before adding more processes to the queue.
  ///
  /// If the processor is not paused, the method will complete immediately.
  Future<void> waitForResume() {
    return _pauseCompleter.future;
  }

  /// Returns all the processes that have the same [identifier].
  ///
  /// This does not mean that the processes are running. It only means that
  /// the processes are on the queue.
  ///
  /// If the process is already completed, the [identifier] can still be on
  /// queue, but the process will not be returned by this method.
  Iterable<CommandQueueItem<T>> get(String identifier) {
    return _processItemQueue.where(
      (p) => p.identifier == identifier && !p.isCanceled,
    );
  }

  /// Returns `true` if the processor is paused.
  ///
  /// This does not mean that the processor is not running. It only means that
  /// future processes will not be executed until the processor is resumed.
  ///
  /// Use [pause] and [resume] to control this behavior.
  bool get isPaused => !_pauseCompleter.isCompleted;

  /// Returns `true` if the processor is running.
  ///
  /// This means that there is at least one process running at the moment.
  bool get isRunning => _isRunning;
}

class CommandQueueItem<T> {
  CommandQueueItem(
    this.func, {
    required this.id,
    String? identifier,
    this.timeToStoreIdentifier = Duration.zero,
    void Function()? onCancel,
  }) : _onCancel = onCancel,
       identifier = identifier ?? 'ProcessItem #$id';

  factory CommandQueueItem.command(
    Command<T> command, {
    required int id,
    String? identifier,
    Duration timeToStoreIdentifier = Duration.zero,
    void Function()? onCancel,
  }) {
    return CommandQueueItem(
      command.run,
      id: id,
      identifier: identifier,
      timeToStoreIdentifier: timeToStoreIdentifier,
      onCancel: onCancel,
    );
  }

  final int id;
  final String identifier;
  final Duration timeToStoreIdentifier;
  final Completer<T> _completer = Completer();
  final void Function()? _onCancel;
  final FutureOr<T> Function() func;

  bool _started = false;
  bool _canceled = false;

  bool get isCanceled => _canceled;

  Completer<Result<T>> result = Completer<Result<T>>();

  bool get isCompleted => _completer.isCompleted;
  bool get isRunning => !_canceled && _started && !_completer.isCompleted;

  Future<void> _execute() async {
    if (!_canceled) {
      _started = true;

      try {
        _completer.complete(await func());
      } on Exception catch (e, s) {
        _completer.completeError(e, s);
      }
    }
  }

  bool cancel() {
    if (!_started) {
      _canceled = true;
      _onCancel?.call();
    }
    return !_started;
  }
}
