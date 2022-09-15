import 'dart:isolate';

class Node {
  final int index;
  final Isolate isolate;
  final ReceivePort masterPort;
  SendPort? workerPort;
  Node({required this.isolate, required this.masterPort, required this.index});
}

class ThreadPool {
  static int? _maxThread;
  static List<Node?>? _nodes;
  static int? _index;

  ThreadPool._privateConstructor();

  static final ThreadPool _instance = ThreadPool._privateConstructor();

  factory ThreadPool() {
    return _instance;
  }

  static int? get index => _index;

  static initThreadPool({required int maxThread}) {
    assert(_maxThread == null, "Threadpool has been init");
    assert(maxThread > 0, "required size of Threadpool > 0");
    _maxThread = maxThread;
    _nodes = List<Node?>.filled(maxThread, null);
    _index = 0;
  }

  static Future<void> disposeThreadPool() async {
    assert(_maxThread != null, "Threadpool has been not init");
    for (Node? n in _nodes ?? []) {
      if (n != null) {
        await deleteTask(n.index);
      }
    }
    _maxThread = null;
    _nodes = null;
    _index = null;
  }

  static Future<Node?> createTask(void Function(SendPort) func) async {
    assert(_maxThread != null,
        "Threadpool has not been init, call [initThreadPool] before ");
    assert((_maxThread ?? 0) > (_index ?? 0), "Thread pool is full");
    try {
      final ReceivePort masterPort = ReceivePort('$_index');
      final isolate = await Isolate.spawn(func, masterPort.sendPort);
      _nodes?[_index!] =
          Node(isolate: isolate, masterPort: masterPort, index: _index!);
      _index = _index! + 1;
      return _nodes?[_index! - 1];
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteTask(int idx,
      {int priority = Isolate.beforeNextEvent}) async {
    assert(_maxThread != null,
        "Threadpool has not been init, call [initThreadPool] before ");
    assert(idx < 0, "index is become [0,1,...]");
    assert(idx <= ((_maxThread ?? 0) - 1),
        "only contain $_maxThread but required $idx");
    if (_nodes?[idx] == null) {
      return true;
    }
    try {
      _nodes?[idx]?.isolate.pause();
      _nodes?[idx]?.isolate.kill(priority: priority);
      _nodes?[idx] = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Node?> getNode(int idx) {
    assert(idx < 0, "index is become [0,1,...]");
    assert(idx <= ((_maxThread ?? 0) - 1),
        "only contain $_maxThread but required $idx");
    return Future.value(_nodes?[idx]);
  }
}
