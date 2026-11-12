/// Error envelope handling with no Flutter dependency (unit-tested in plain Dart).
library;

/// Normalised form of the backend error envelope: { error: { code, message, details? } }.
class ApiError implements Exception {
  final int status;
  final String code;
  final String message;
  final dynamic details;
  ApiError(this.status, this.code, this.message, [this.details]);

  /// Pydantic 422 details mapped to field paths, e.g. { estimated_kg: 'Field required' }.
  Map<String, String> fieldErrors() {
    final out = <String, String>{};
    final d = details;
    if (code == 'VALIDATION_ERROR' && d is List) {
      for (final item in d) {
        if (item is Map) {
          final loc = item['loc'];
          final msg = item['msg'];
          if (loc is List && msg != null) {
            final key = loc.where((p) => p != 'body').map((p) => p.toString()).join('.');
            if (key.isNotEmpty) out[key] = msg.toString();
          }
        }
      }
    }
    return out;
  }

  @override
  String toString() => 'ApiError($status, $code, $message)';
}

const String kNetworkError = 'NETWORK_ERROR';

ApiError toApiError(Object e) {
  if (e is ApiError) return e;
  return ApiError(0, kNetworkError, 'The ReLoop server could not be reached. Check that the backend is running and try again.');
}

/// Human explanation for the status classes the UI distinguishes.
({String title, String body}) describeError(ApiError e) {
  if (e.status == 0) return (title: 'Backend unavailable', body: e.message);
  if (e.status == 401) return (title: 'Session ended', body: 'Sign in again to continue.');
  if (e.status == 403) return (title: 'Not permitted', body: e.message);
  if (e.status == 404) return (title: 'Not found', body: e.message);
  if (e.status == 409) return (title: 'Conflict with current records', body: e.message);
  if (e.status == 422) return (title: 'Check the values entered', body: e.message);
  if (e.status >= 500) {
    return (title: 'Server error', body: 'The server could not complete this request. Try again; if it persists, report the time and action.');
  }
  return (title: 'Request failed', body: e.message);
}

/// Parses a non-2xx response body: the backend envelope { error: { code, message, details? } },
/// FastAPI's default { detail: "..." }, or anything else.
ApiError apiErrorFromBody(int status, dynamic body) {
  if (body is Map) {
    final e = body['error'];
    if (e is Map && e['code'] != null) {
      return ApiError(status, e['code'].toString(), (e['message'] ?? 'Request failed').toString(), e['details']);
    }
    final d = body['detail'];
    if (d is String) return ApiError(status, 'HTTP_$status', d);
  }
  return ApiError(status, 'HTTP_$status', 'Request failed with status $status');
}
