/// JSON helpers with no Flutter dependency, so quantity logic can be unit-tested in plain Dart.
library;

/// JSON object as sent by the backend. Field names are kept exactly as the API sends them.
typedef J = Map<String, dynamic>;

/// Number from a JSON value. The backend sends some quantities as "123.000" strings.
double? dn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    return (n != null && n.isFinite) ? n : null;
  }
  return null;
}

/// String from a JSON value, or null when absent.
String? sn(dynamic v) => v?.toString();

/// List of JSON objects from a JSON value.
List<J> jl(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return <J>[];
}

/// JSON object from a JSON value, or null.
J? jo(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
