import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  String _baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:8000/api/v1';
  }

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final savedBase = prefs.getString('api_base_url');
    if (savedBase != null && savedBase.isNotEmpty) {
      _baseUrl = savedBase;
      return;
    }

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          // Probe localhost (active on physical phone via `adb reverse`)
          try {
            final res = await http
                .get(Uri.parse('http://127.0.0.1:8000/health'))
                .timeout(const Duration(milliseconds: 600));
            if (res.statusCode == 200) {
              _baseUrl = 'http://127.0.0.1:8000/api/v1';
              return;
            }
          } catch (_) {}
          // Fallback to emulator host loopback
          _baseUrl = 'http://10.0.2.2:8000/api/v1';
        }
      } catch (_) {}
    }
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Ping the backend health endpoint
  Future<bool> checkHealth() async {
    try {
      final host = _baseUrl.replaceAll('/api/v1', '');
      final res = await http
          .get(Uri.parse('$host/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate and retrieve bearer token
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token != null) {
          await saveToken(token);
        }
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('API login failed: $e');
      return null;
    }
  }

  /// Fetch list of batches from backend
  Future<List<Map<String, dynamic>>?> fetchBatches({String? status}) async {
    try {
      var uri = Uri.parse('$_baseUrl/batches');
      if (status != null) {
        uri = uri.replace(queryParameters: {'status': status});
      }
      final res = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('API fetchBatches failed: $e');
      return null;
    }
  }

  /// Create a batch on backend
  Future<Map<String, dynamic>?> createBatch({
    required int materialId,
    required String packagingCategory,
    required double estimatedKg,
    required String pickupAddress,
    required String locality,
    required double lat,
    required double lng,
    required DateTime availableFrom,
    required DateTime availableTo,
    List<String>? photos,
  }) async {
    try {
      final body = {
        'material_id': materialId,
        'packaging_category': packagingCategory,
        'estimated_weight_kg': estimatedKg,
        'pickup_address': pickupAddress,
        'locality': locality,
        'lat': lat,
        'lng': lng,
        'available_from': availableFrom.toIso8601String(),
        'available_to': availableTo.toIso8601String(),
        'photo_urls': photos ?? [],
      };
      final res = await http
          .post(
            Uri.parse('$_baseUrl/batches'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('API createBatch failed: $e');
      return null;
    }
  }

  /// Fetch digital product passport by batch code
  Future<Map<String, dynamic>?> fetchPassport(String batchCode) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/passports/$batchCode'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('API fetchPassport failed: $e');
      return null;
    }
  }

  /// Submit NGO verification decision
  Future<Map<String, dynamic>?> submitVerification({
    required String verificationId,
    required String decision,
    required Map<String, bool> checklist,
    required String comments,
  }) async {
    try {
      final body = {
        'decision': decision,
        'checklist': checklist,
        'comments': comments,
      };
      final res = await http
          .post(
            Uri.parse('$_baseUrl/ngo/verifications/$verificationId/decision'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('API submitVerification failed: $e');
      return null;
    }
  }

  /// Allocate EPR credits to a brand owner
  Future<Map<String, dynamic>?> allocateEpr({
    required String processingRunId,
    required String eprClientId,
    required String packagingCategory,
    required double quantityKg,
  }) async {
    try {
      final body = {
        'processing_record_id': processingRunId,
        'epr_client_id': eprClientId,
        'packaging_category': packagingCategory,
        'quantity_kg': quantityKg,
      };
      final res = await http
          .post(
            Uri.parse('$_baseUrl/epr/allocations'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('API allocateEpr failed: $e');
      return null;
    }
  }

  /// Reverse an active EPR allocation
  Future<bool> reverseEprAllocation({
    required String allocationId,
    required String reason,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/epr/allocations/$allocationId/reverse'),
            headers: _headers(),
            body: jsonEncode({'reversal_reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('API reverseEprAllocation failed: $e');
      return false;
    }
  }
}
