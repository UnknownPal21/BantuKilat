import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl =
      'https://517d17c3be9a940d.kyydayxlyodt.opentunnel.xyz';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuthResponse(response);
  }

  static Future<Map<String, dynamic>> register({
    required String role,
    required String name,
    required String email,
    required String phone,
    required String password,
    required String city,
    required String district,
    List<String>? skills,
    bool termsAccepted = false,
  }) async {
    final body = <String, dynamic>{
      'role': role.toUpperCase(),
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'city': city,
      'district': district,
      'terms_accepted': termsAccepted,
      if (skills != null)
        'skills': skills.map((skill) => skill.toUpperCase()).toList(),
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleAuthResponse(response);
  }

  static Future<Map<String, dynamic>> _handleAuthResponse(
    http.Response response,
  ) async {
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(decoded));
    }
    final result = Map<String, dynamic>.from(decoded as Map);
    await _storage.write(
      key: 'access_token',
      value: result['access_token'] as String,
    );
    await _storage.write(
      key: 'user_profile',
      value: jsonEncode(result['user']),
    );
    return result;
  }

  static String _errorMessage(dynamic response) {
    if (response is Map) {
      final detail = response['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((item) => item is Map ? item['msg'] : item)
            .join(', ');
      }
    }
    return 'Permintaan gagal. Periksa data dan koneksi internet.';
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final profile = await _storage.read(key: 'user_profile');
    if (profile == null) return null;
    return Map<String, dynamic>.from(jsonDecode(profile) as Map);
  }

  static Future<String?> getToken() => _storage.read(key: 'access_token');

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_profile');
  }

  static Future<Map<String, dynamic>?> validateSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await logout();
        return null;
      }
      final user = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      await _storage.write(key: 'user_profile', value: jsonEncode(user));
      return user;
    } catch (_) {
      // Keep stored token during temporary connectivity errors.
      return getCurrentUser();
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/categories'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal mengambil kategori layanan.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Format kategori tidak valid.');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyOffers({
    int limit = 50,
    String? status,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/offers/mine?limit=$limit${status == null ? '' : '&status=${Uri.encodeQueryComponent(status)}'}',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Format daftar tawaran tidak valid.');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> uploadMedia(String dataUri) async {
    final response = await _authorizedRequest(
      'POST',
      '/media',
      body: {'data': dataUri, 'kind': 'offers'},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<String> getMediaUrl(String fileId) async {
    final response = await _authorizedRequest(
      'GET',
      '/media/${Uri.encodeComponent(fileId)}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
      throw Exception(_errorMessage(decoded));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is String) {
      if (decoded.startsWith('data:image/')) return decoded;
      return decoded.startsWith('http') ? decoded : '$_baseUrl$decoded';
    }
    if (decoded is Map && decoded['url'] is String) {
      final url = decoded['url'] as String;
      return url.startsWith('http') ? url : '$_baseUrl$url';
    }
    throw Exception('Respons media tidak memiliki URL gambar.');
  }

  static Future<Map<String, dynamic>> createOffer({
    required String categoryId,
    required String title,
    required String description,
    required List<String> photos,
    required double latitude,
    required double longitude,
    required String address,
    required bool isSos,
    required int budget,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/offers',
      body: {
        'category_id': categoryId,
        'title': title,
        'description': description,
        'photos': photos,
        'lat': latitude,
        'lng': longitude,
        'address_text': address,
        'is_sos': isSos,
        'initial_budget': budget,
      },
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getNearbyOffers({
    required double latitude,
    required double longitude,
    int radius = 5000,
    String? category,
    bool? sos,
    int limit = 20,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi berakhir. Silakan masuk kembali.');
    }
    final query = <String, String>{
      'lat': '$latitude',
      'lng': '$longitude',
      'radius': '$radius',
      'limit': '$limit',
      if (category != null) 'category': category,
      if (sos != null) 'sos': '$sos',
    };
    final uri = Uri.parse('$_baseUrl/offers/nearby')
        .replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
      throw Exception(_errorMessage(decoded));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List)
      throw Exception('Format daftar tawaran sekitar tidak valid.');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyTasks({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    final profile = await getCurrentUser();
    final technicianId = profile?['_id']?.toString();
    if (technicianId == null) return [];
    
    // 1. Ambil tawaran sekitar/semua tawaran status WAITING, ASSIGNED, COMPLETED, dll
    final offers = await getNearbyOffers(
      latitude: latitude,
      longitude: longitude,
      radius: 500000,
      limit: 200,
    );

    final assigned = <Map<String, dynamic>>[];
    for (final offer in offers) {
      final status = '${offer['status'] ?? ''}'.toUpperCase();
      final tId = offer['technician_id']?.toString();
      
      bool isMyAssignedTask = tId == technicianId && (status == 'ASSIGNED' || status == 'COMPLETED');
      
      if (!isMyAssignedTask) {
        try {
          final bids = await getBids('${offer['_id'] ?? offer['id']}');
          final accepted = bids.where(
            (bid) =>
                (bid['technician_id']?.toString() == technicianId ||
                    (bid['technician_snapshot'] as Map?)?['_id']?.toString() ==
                        technicianId) &&
                '${bid['status']}'.toUpperCase() == 'ACCEPTED',
          );
          if (accepted.isNotEmpty) {
            isMyAssignedTask = true;
            offer['accepted_bid'] = accepted.first;
            offer['status'] = 'ASSIGNED';
          }
        } catch (_) {}
      }

      if (isMyAssignedTask) {
        assigned.add(offer);
      }
    }
    return assigned;
  }

  static Future<Map<String, dynamic>> getOffer(String offerId) async {
    final response = await _authorizedRequest(
      'GET',
      '/offers/${Uri.encodeComponent(offerId)}',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getBids(String offerId) async {
    final response = await _authorizedRequest(
      'GET',
      '/offers/${Uri.encodeComponent(offerId)}/bids?limit=100',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Format daftar bid tidak valid.');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> placeBid({
    required String offerId,
    required int amount,
    String? message,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/offers/${Uri.encodeComponent(offerId)}/bids',
      body: {'amount': amount, if (message != null) 'message': message},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getOfferBidsByStatus(
    String offerId,
    String status,
  ) async {
    final response = await _authorizedRequest(
      'GET',
      '/offers/${Uri.encodeComponent(offerId)}/bids?status=${Uri.encodeQueryComponent(status)}&limit=100',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Format daftar bid tidak valid.');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> rejectBid(String bidId) async {
    final response = await _authorizedRequest(
      'POST',
      '/bids/${Uri.encodeComponent(bidId)}/reject',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> acceptBid(String bidId) async {
    final response = await _authorizedRequest(
      'POST',
      '/bids/${Uri.encodeComponent(bidId)}/accept',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> completeOffer(String offerId) async {
    final response = await _authorizedRequest(
      'POST',
      '/offers/${Uri.encodeComponent(offerId)}/complete',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi berakhir. Silakan masuk kembali.');
    }
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final requestBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: requestBody),
      'PATCH' => await http.patch(uri, headers: headers, body: requestBody),
      'DELETE' => await http.delete(uri, headers: headers),
      _ => throw ArgumentError('HTTP method tidak didukung: $method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
      throw Exception(_errorMessage(decoded));
    }
    return response;
  }
}

class AuthNavigation {
  static String homeRouteForRole(String role) {
    switch (role.toUpperCase()) {
      case 'USER':
        return 'user';
      case 'TECHNICIAN':
        return 'technician';
      default:
        throw Exception('Role akun tidak dikenali: $role');
    }
  }
}
