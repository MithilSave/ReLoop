import 'package:flutter/material.dart';

import '../ui/states.dart';
import 'api.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void toast(String message, {bool error = false}) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? const Color(0xFFB42318) : null,
    duration: Duration(seconds: error ? 6 : 4),
  ));
}

/// Tells mounted queries to reload. Keys are grouped by record type ("batches/...", "recycler/receipts")
/// so a mutation can invalidate a whole group with one prefix.
class QueryBus extends ChangeNotifier {
  final Map<String, dynamic> cache = <String, dynamic>{};
  List<String> lastPrefixes = const <String>[];

  void invalidate(List<String> prefixes) {
    lastPrefixes = prefixes;
    notifyListeners();
  }

  /// Drops everything, e.g. when the signed-in account changes.
  void clear() {
    cache.clear();
    lastPrefixes = const <String>[''];
    notifyListeners();
  }
}

final QueryBus queryBus = QueryBus();

/// State of one query, as given to a [QueryBuilder].
class Q<T> {
  final T? data;
  final ApiError? error;
  final bool pending;
  final VoidCallback refetch;
  const Q(this.data, this.error, this.pending, this.refetch);
  bool get hasData => data != null;
}

/// Runs [fetch], keeps the result, and reloads when [queryBus] invalidates a prefix of [qk].
class QueryBuilder<T> extends StatefulWidget {
  final String qk;
  final Future<T> Function() fetch;
  final Widget Function(BuildContext context, Q<T> q) builder;
  final bool enabled;
  const QueryBuilder({super.key, required this.qk, required this.fetch, required this.builder, this.enabled = true});

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  T? _data;
  ApiError? _error;
  bool _pending = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    queryBus.addListener(_onBus);
    _start();
  }

  void _start() {
    final cached = queryBus.cache[widget.qk];
    _data = cached is T ? cached : null;
    _error = null;
    _pending = widget.enabled;
    if (widget.enabled) _load();
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> old) {
    super.didUpdateWidget(old);
    if (old.qk != widget.qk || old.enabled != widget.enabled) {
      _seq++;
      _start();
    }
  }

  @override
  void dispose() {
    queryBus.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    if (!widget.enabled) return;
    for (final p in queryBus.lastPrefixes) {
      if (widget.qk.startsWith(p)) {
        _load();
        return;
      }
    }
  }

  Future<void> _load() async {
    final seq = ++_seq;
    try {
      final d = await widget.fetch();
      if (!mounted || seq != _seq) return;
      queryBus.cache[widget.qk] = d;
      setState(() {
        _data = d;
        _error = null;
        _pending = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e is ApiError ? e : ApiError(-1, 'CLIENT_ERROR', e.toString());
        _pending = false;
      });
    }
  }

  void _refetch() {
    if (!mounted) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, Q<T>(_data, _error, _pending && _data == null, _refetch));
}

/// Renders loading / error / empty / data for one query.
class QueryView<T> extends StatelessWidget {
  final String qk;
  final Future<T> Function() fetch;
  final Widget Function(BuildContext context, T data) builder;
  final String? emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;
  final bool Function(T data)? isEmpty;
  final int loadingRows;
  const QueryView({
    super.key,
    required this.qk,
    required this.fetch,
    required this.builder,
    this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    this.isEmpty,
    this.loadingRows = 4,
  });

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<T>(
      qk: qk,
      fetch: fetch,
      builder: (context, s) {
        final d = s.data;
        if (d == null) {
          if (s.error != null) return ErrorState(error: s.error!, onRetry: s.refetch);
          return LoadingRows(rows: loadingRows);
        }
        if (emptyTitle != null) {
          final fn = isEmpty;
          final empty = fn != null ? fn(d) : (d is List && d.isEmpty);
          if (empty) return EmptyState(title: emptyTitle!, body: emptyBody, action: emptyAction);
        }
        return builder(context, d);
      },
    );
  }
}

/// Runs a write. On success it invalidates every query that shows the affected records, so one action
/// updates all screens. Errors carry the backend's own message; nothing is retried with altered values
/// (an over-allocation is never silently reduced). Returns null when the call failed.
Future<T?> mutate<T>(
  Future<T> Function() fn, {
  List<String> invalidate = const <String>[],
  String Function(T data)? success,
  void Function(ApiError e)? onError,
  bool toastErrors = true,
}) async {
  try {
    final d = await fn();
    if (invalidate.isNotEmpty) queryBus.invalidate(invalidate);
    if (success != null) toast(success(d));
    return d;
  } catch (e) {
    final err = e is ApiError ? e : ApiError(-1, 'CLIENT_ERROR', e.toString());
    if (onError != null) onError(err);
    if (toastErrors && err.status != 422 && err.status != 409) {
      final d = describeError(err);
      toast('${d.title}. ${d.body}', error: true);
    }
    return null;
  }
}

/// Query keys, grouped by record type.
class K {
  static const String batches = 'batches';
  static String batchList([String? status]) => 'batches/list/${status ?? 'all'}';
  static String batch(String id) => 'batches/one/$id';
  static String passport(String code) => 'batches/passport/$code';
  static String trace(String id) => 'batches/trace/$id';
  static String events(String id) => 'batches/events/$id';
  static String offers(String id) => 'batches/offers/$id';
  static String qr(String id) => 'qr/$id';
  static const String materials = 'materials';
  static String orgs([String? t]) => 'orgs/${t ?? 'all'}';
  static const String myOrg = 'orgs/me';
  static const String collections = 'collections';
  static const String available = 'collections/available';
  static const String jobs = 'collections/jobs';
  static const String consignments = 'consignments';
  static const String recycler = 'recycler';
  static const String incoming = 'recycler/incoming';
  static String receipts([bool history = false]) => 'recycler/receipts/$history';
  static const String receiptsAll = 'recycler/receipts';
  static const String processing = 'recycler/processing';
  static const String capacity = 'recycler/capacity';
  static const String yieldKey = 'recycler/yield';
  static const String recOffers = 'recycler/offers';
  static const String epr = 'epr';
  static const String allocations = 'epr/allocations';
  static String eprDash(String p) => 'epr/dashboard/$p';
  static const String targets = 'epr/targets';
  static const String eprCerts = 'epr/certificates';
  static const String eprDisc = 'epr/discrepancies';
  static const String ngo = 'ngo';
  static const String verifications = 'ngo/verifications';
  static String verification(String id) => 'ngo/verifications/one/$id';
  static const String ngoReports = 'ngo/reports';
  static const String ngoImpact = 'ngo/impact';
  static const String anomalies = 'anomalies';
  static const String audit = 'audit';
  static const String payments = 'payments';
  static String perf(String id) => 'performance/$id';
  static const String impact = 'impact';
  static const String admin = 'admin';
  static String adminOrgs([String? s]) => 'admin/orgs/${s ?? 'all'}';
  static const String intel = 'intel';
  static const String demand = 'intel/demand';
  static const String plans = 'intel/plans';
  static String plan(String id) => 'intel/plans/one/$id';
  static const String pricing = 'intel/pricing';
  static const String supplyFc = 'intel/supply';
  static const String demandFc = 'intel/demandfc';
  static String shortage(String m) => 'intel/shortage/$m';
  static const String ai = 'ai/status';
  static const String health = 'health';
}

/// Named query for [Queries]: a cache key and its fetch function. A null [qk] disables the query.
class QDef {
  final String? qk;
  final Future<dynamic> Function() fetch;
  const QDef(this.qk, this.fetch);
}

/// State of several queries loaded in parallel.
class QSet {
  final Map<String, dynamic> _data;
  final Map<String, ApiError> _errors;
  final Set<String> _pending;
  final VoidCallback refetch;
  const QSet(this._data, this._errors, this._pending, this.refetch);

  T? get<T>(String name) {
    final v = _data[name];
    return v is T ? v : null;
  }

  List<J> list(String name) => get<List<J>>(name) ?? const <J>[];
  bool pending(String name) => _pending.contains(name) && !_data.containsKey(name);
  bool has(String name) => _data.containsKey(name);
  ApiError? error(String name) => _data.containsKey(name) ? null : _errors[name];
}

/// Several [QueryBuilder]s in one: each named query loads in parallel, is cached under its key and reloads
/// when [queryBus] invalidates a prefix of that key.
class Queries extends StatefulWidget {
  final Map<String, QDef> queries;
  final Widget Function(BuildContext context, QSet q) builder;
  const Queries({super.key, required this.queries, required this.builder});

  @override
  State<Queries> createState() => _QueriesState();
}

class _QueriesState extends State<Queries> {
  final Map<String, dynamic> _data = <String, dynamic>{};
  final Map<String, ApiError> _errors = <String, ApiError>{};
  final Set<String> _pending = <String>{};
  final Map<String, int> _seq = <String, int>{};
  final Map<String, String?> _keys = <String, String?>{};

  @override
  void initState() {
    super.initState();
    queryBus.addListener(_onBus);
    widget.queries.forEach(_start);
  }

  void _start(String name, QDef d) {
    _keys[name] = d.qk;
    _seq[name] = (_seq[name] ?? 0) + 1;
    _errors.remove(name);
    final cached = d.qk == null ? null : queryBus.cache[d.qk];
    if (cached != null) {
      _data[name] = cached;
    } else {
      _data.remove(name);
    }
    if (d.qk == null) {
      _pending.remove(name);
      return;
    }
    _pending.add(name);
    _load(name, d);
  }

  @override
  void didUpdateWidget(covariant Queries old) {
    super.didUpdateWidget(old);
    widget.queries.forEach((name, d) {
      if (_keys[name] != d.qk || !_keys.containsKey(name)) _start(name, d);
    });
  }

  @override
  void dispose() {
    queryBus.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    widget.queries.forEach((name, d) {
      final k = d.qk;
      if (k == null) return;
      for (final p in queryBus.lastPrefixes) {
        if (k.startsWith(p)) {
          _load(name, d);
          return;
        }
      }
    });
  }

  Future<void> _load(String name, QDef d) async {
    final seq = (_seq[name] ?? 0) + 1;
    _seq[name] = seq;
    try {
      final v = await d.fetch();
      if (!mounted || _seq[name] != seq) return;
      if (d.qk != null) queryBus.cache[d.qk!] = v;
      setState(() {
        _data[name] = v;
        _errors.remove(name);
        _pending.remove(name);
      });
    } catch (e) {
      if (!mounted || _seq[name] != seq) return;
      setState(() {
        _errors[name] = e is ApiError ? e : ApiError(-1, 'CLIENT_ERROR', e.toString());
        _pending.remove(name);
      });
    }
  }

  void _refetchAll() {
    if (!mounted) return;
    setState(() {
      _errors.clear();
      widget.queries.forEach((name, d) {
        if (d.qk != null) _pending.add(name);
      });
    });
    widget.queries.forEach((name, d) {
      if (d.qk != null) _load(name, d);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, QSet(_data, _errors, _pending, _refetchAll));
}
