import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'errors.dart';
import 'json.dart';

export 'errors.dart';
export 'json.dart';

/// The only HTTP client in the app. Screens never call http directly; they call the methods below.
class Api {
  static const String _envBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _kOrigin = 'reloop.api_origin';
  static const String _kAccess = 'reloop.access_token';
  static const String _kRefresh = 'reloop.refresh_token';

  /// HTTP client for every request. Tests replace it with package:http/testing.dart's MockClient.
  static http.Client client = http.Client();

  static String origin = defaultOrigin();
  static String get base => '$origin/api/v1';
  static String? access;
  static String? refresh;

  /// Called when the session can no longer be refreshed.
  static void Function()? onSessionExpired;

  /// Android emulators reach the host machine at 10.0.2.2; everything else uses localhost.
  static String defaultOrigin() {
    if (_envBase.isNotEmpty) return _clean(_envBase);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static String _clean(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/api/v1')) u = u.substring(0, u.length - 7);
    return u;
  }

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_kOrigin);
      if (saved != null && saved.isNotEmpty) origin = saved;
      access = p.getString(_kAccess);
      refresh = p.getString(_kRefresh);
    } catch (_) {
      // Storage unavailable: the app still works for this run.
    }
  }

  static Future<void> setOrigin(String url) async {
    origin = url.trim().isEmpty ? defaultOrigin() : _clean(url);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kOrigin, origin);
    } catch (_) {}
  }

  static Future<void> setTokens(String a, String r) async {
    access = a;
    refresh = r;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kAccess, a);
      await p.setString(_kRefresh, r);
    } catch (_) {}
  }

  static Future<void> clearTokens() async {
    access = null;
    refresh = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kAccess);
      await p.remove(_kRefresh);
    } catch (_) {}
  }

  static Uri _uri(String root, String path, Map<String, dynamic>? query) {
    final qp = <String, String>{};
    if (query != null) {
      query.forEach((k, v) {
        if (v != null) qp[k] = v.toString();
      });
    }
    final u = Uri.parse('$root$path');
    return qp.isEmpty ? u : u.replace(queryParameters: qp);
  }

  static ApiError _errorFrom(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    return apiErrorFromBody(res.statusCode, body);
  }

  // Single-flight refresh: concurrent 401s wait for one /auth/refresh call.
  static Future<String?>? _refreshing;
  static Future<String?> _refreshAccess() async {
    final rt = refresh;
    if (rt == null) return null;
    try {
      final res = await client
          .post(_uri(base, '/auth/refresh', null), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': rt}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['access_token'] != null && data['refresh_token'] != null) {
        await setTokens(data['access_token'].toString(), data['refresh_token'].toString());
        return access;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response> _raw(String method, String path, {Map<String, dynamic>? query, Object? body, bool retried = false}) async {
    final req = http.Request(method, _uri(base, path, query));
    req.headers['Accept'] = 'application/json';
    final t = access;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    if (method != 'GET') {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body ?? <String, dynamic>{});
    }
    http.Response res;
    try {
      final streamed = await client.send(req).timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw toApiError(e);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    if (res.statusCode == 401 && !retried && refresh != null) {
      _refreshing ??= _refreshAccess().whenComplete(() => _refreshing = null);
      final fresh = await _refreshing;
      if (fresh != null) return _raw(method, path, query: query, body: body, retried: true);
    }
    if (res.statusCode == 401) {
      await clearTokens();
      final cb = onSessionExpired;
      if (cb != null) cb();
    }
    throw _errorFrom(res);
  }

  static dynamic _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async => _decode(await _raw('GET', path, query: query));
  static Future<dynamic> _post(String path, [Object? body]) async => _decode(await _raw('POST', path, body: body));

  static Future<J> getJ(String path, [Map<String, dynamic>? query]) async => jo(await _get(path, query)) ?? <String, dynamic>{};
  static Future<List<J>> getL(String path, [Map<String, dynamic>? query]) async => jl(await _get(path, query));
  static Future<J> postJ(String path, [Object? body]) async => jo(await _post(path, body)) ?? <String, dynamic>{};

  /* ── Auth ─────────────────────────────────────────────── */

  /// Plain request: a 401 here is a wrong password, not an expired session.
  static Future<J> login(String loginId, String password) async {
    http.Response res;
    try {
      res = await client
          .post(_uri(base, '/auth/login', null), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'login': loginId, 'password': password}))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toApiError(e);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) throw _errorFrom(res);
    return jo(_decode(res)) ?? <String, dynamic>{};
  }

  static Future<J> me() => getJ('/auth/me');
  static Future<J> logout(String refreshToken) => postJ('/auth/logout', {'refresh_token': refreshToken});

  static Future<J> health() async {
    try {
      final res = await client.get(_uri(origin, '/health', null)).timeout(const Duration(seconds: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) throw _errorFrom(res);
      return jo(_decode(res)) ?? <String, dynamic>{};
    } catch (e) {
      throw toApiError(e);
    }
  }

  /* ── Reference ───────────────────────────────────────── */
  static Future<List<J>> materials() => getL('/materials');
  static Future<List<J>> orgs([String? orgType]) => getL('/orgs', {'org_type': orgType});
  static Future<J> myOrg() => getJ('/orgs/me');
  static Future<J> impactSummary() => getJ('/impact/summary');

  /* ── Batches ─────────────────────────────────────────── */
  static Future<List<J>> batches({String? status}) => getL('/batches', {'status': status});
  static Future<J> batch(String idOrCode) => getJ('/batches/${Uri.encodeComponent(idOrCode)}');
  static Future<J> createBatch(J body) => postJ('/batches', body);
  static Future<J> cancelBatch(String id) => postJ('/batches/$id/cancel');
  static Future<List<J>> batchEvents(String id) => getL('/batches/$id/events');
  static Future<J> batchTrace(String id) => getJ('/batches/$id/trace');
  static Future<J> passport(String code) => getJ('/passports/${Uri.encodeComponent(code)}');
  static Future<List<J>> batchOffers(String id) => getL('/batches/$id/offers');
  static Future<J> acceptOffer(String batchId, String offerId) => postJ('/batches/$batchId/offers/$offerId/accept');
  static Future<J> confirmHandover(String batchId, J body) => postJ('/batches/$batchId/handover/confirm', body);

  /// The QR image is a protected PNG, fetched with the access token.
  static Future<Uint8List> batchQr(String id) async => (await _raw('GET', '/batches/$id/qr')).bodyBytes;

  /* ── Collections ─────────────────────────────────────── */
  static Future<List<J>> availableListings() => getL('/collections/available');
  static Future<J> makeOffer(String batchId, J body) => postJ('/collections/$batchId/offers', body);
  static Future<List<J>> collectorJobs() => getL('/collections/jobs');
  static Future<J> recordPickup(String batchId, J body) => postJ('/collections/$batchId/pickup', body);
  static Future<J> withdrawCollection(String batchId) => postJ('/collections/$batchId/withdraw');

  /* ── Consignments ────────────────────────────────────── */
  static Future<List<J>> consignments() => getL('/consignments');
  static Future<J> createConsignment(J body) => postJ('/consignments', body);
  static Future<J> markArrived(String id) => postJ('/consignments/$id/arrive');

  /* ── Documents ───────────────────────────────────────── */

  /// The backend records document metadata only: upload URLs point to a placeholder host and no bytes are
  /// stored. The real SHA-256 is computed on this device so the recorded hash describes the file.
  static Future<({String id, String sha})> registerDocument(Uint8List bytes, String docType, String mimeType) async {
    final sha = crypto.sha256.convert(bytes).toString();
    final created = await postJ('/documents/upload-url', {'doc_type': docType, 'mime_type': mimeType.isEmpty ? 'application/octet-stream' : mimeType, 'size_bytes': bytes.length});
    final id = created['document_id'].toString();
    final done = await postJ('/documents/$id/complete', {'sha256': sha});
    return (id: (done['document_id'] ?? id).toString(), sha: (done['sha256'] ?? sha).toString());
  }

  /* ── Recycler ────────────────────────────────────────── */
  static Future<List<J>> incoming() => getL('/recycler/incoming');
  static Future<List<J>> receipts([bool includeHistory = false]) => getL('/recycler/receipts', {'include_history': includeHistory});
  static Future<J> createReceipt(J body) => postJ('/recycler/receipts', body);
  static Future<J> correctReceipt(String id, J body) => postJ('/recycler/receipts/$id/corrections', body);
  static Future<List<J>> processing() => getL('/recycler/processing-records');
  static Future<J> createProcessing(J body) => postJ('/recycler/processing-records', body);
  static Future<J> addCertificate(String recordId, J body) => postJ('/recycler/processing-records/$recordId/certificates', body);
  static Future<J> capacity() => getJ('/recycler/capacity');
  static Future<J> yieldAnalytics() => getJ('/yield');
  static Future<List<J>> recyclerOffers() => getL('/recycler/offers');
  static Future<J> createRecyclerOffer(J body) => postJ('/recycler/offers', body);

  /* ── EPR ─────────────────────────────────────────────── */
  static Future<J> eprDashboard(String period) => getJ('/epr/dashboard', {'period': period});
  static Future<List<J>> targets() => getL('/epr/targets');
  static Future<J> upsertTarget(J body) => postJ('/epr/targets', body);
  static Future<List<J>> allocations() => getL('/epr/allocations');
  static Future<J> createAllocation(J body) => postJ('/epr/allocations', body);
  static Future<J> reverseAllocation(String id, String reason) => postJ('/epr/allocations/$id/reverse', {'reason': reason});
  static Future<List<J>> eprCertificates() => getL('/epr/certificates');
  static Future<List<J>> eprDiscrepancies() => getL('/epr/discrepancies');

  /* ── NGO ─────────────────────────────────────────────── */
  static Future<List<J>> verifications() => getL('/ngo/verifications');
  static Future<J> verification(String id) => getJ('/ngo/verifications/$id');
  static Future<J> claimVerification(String id) => postJ('/ngo/verifications/$id/claim');
  static Future<J> decide(String id, J body) => postJ('/ngo/verifications/$id/decision', body);
  static Future<J> requestDocument(String id, J body) => postJ('/ngo/verifications/$id/document-requests', body);
  static Future<J> ngoReports() => getJ('/ngo/reports');
  static Future<J> ngoImpact() => getJ('/ngo/impact');

  /* ── Shared ──────────────────────────────────────────── */
  static Future<List<J>> anomalies() => getL('/anomalies');
  static Future<J> resolveAnomaly(String id, J body) => postJ('/anomalies/$id/resolve', body);
  static Future<List<J>> auditLogs() => getL('/audit/logs');
  static Future<List<J>> payments() => getL('/payments');
  static Future<J> markPaid(String id, String externalRef) => postJ('/payments/$id/mark-paid', {'external_ref': externalRef});
  static Future<J> supplierPerformance(String orgId) => getJ('/suppliers/$orgId/performance');
  static Future<List<J>> adminOrgs([String? status]) => getL('/admin/orgs', {'status': status});
  static Future<J> approveOrg(String id, String decision, [String? note]) => postJ('/admin/orgs/$id/approve', {'decision': decision, 'note': note});

  /* ── Intelligence ────────────────────────────────────── */
  static Future<List<J>> demandProfiles() => getL('/recycler/demand-profiles');
  static Future<J> createDemand(J body) => postJ('/recycler/demand-profiles', body);
  static Future<List<J>> plans() => getL('/aggregation/plans');
  static Future<J> plan(String id) => getJ('/aggregation/plans/$id');
  static Future<J> proposePlan(J body) => postJ('/aggregation/plans/propose', body);
  static Future<J> acceptPlan(String id) => postJ('/aggregation/plans/$id/accept');
  static Future<J> cancelPlan(String id) => postJ('/aggregation/plans/$id/cancel');
  static Future<J> estimateCost(J body) => postJ('/costs/estimate', body);
  static Future<J> compareCosts(List<J> options) => postJ('/costs/compare', {'options': options});
  static Future<J> pricingAssumptions() => getJ('/pricing-assumptions');
  static Future<List<J>> supplyForecasts() => getL('/forecasts/supply');
  static Future<List<J>> demandForecasts() => getL('/forecasts/demand');
  static Future<J> shortages(String material) => getJ('/forecasts/shortages', {'material': material});

  /* ── AI polymer detection ────────────────────────────── */

  /// Whether the team's polymer model is connected on the backend.
  static Future<J> aiStatus() => getJ('/ai/status');

  /// Sends one photo to the polymer model. 503 AI_MODEL_NOT_CONFIGURED when no model is connected.
  static Future<J> classify(Uint8List bytes, {String? documentId}) =>
      postJ('/ai/classify', {'image_base64': base64Encode(bytes), 'document_id': documentId});
}
