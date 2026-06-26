/// Monotonic id generator. Combines the timestamp with a process-wide counter
/// so two ids minted in the same microsecond never collide. AG-UI requires
/// every message id to be non-empty and unique within a run.
int _counter = 0;

/// Returns a unique id with the given [prefix] (e.g. `user`, `run`, `thread`).
String uid(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
