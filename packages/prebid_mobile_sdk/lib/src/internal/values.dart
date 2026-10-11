/// Value equality for the public data classes (responses, parameters).
///
/// Internal: not exported from the public library.
library;

/// Whether [a] and [b] are equal, comparing lists and maps element by
/// element, at any depth (`ext` maps hold nested JSON).
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// A hash code consistent with [deepEquals].
int deepHash(Object? value) => switch (value) {
  List() => Object.hashAll(value.map(deepHash)),
  // Order-independent, as map equality is.
  Map() => Object.hashAllUnordered(
    value.entries.map((e) => Object.hash(e.key, deepHash(e.value))),
  ),
  _ => value.hashCode,
};

/// `Name(field: value, ...)`, leaving out null fields.
String describe(String name, Map<String, Object?> fields) {
  final set = fields.entries.where((e) => e.value != null);
  return '$name(${set.map((e) => '${e.key}: ${e.value}').join(', ')})';
}
