
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();

  static const String baseUrl =
      'https://backend-fastapi-1.fadehost.app';
  static const Duration _timeout = Duration(seconds: 20);

  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> _publicHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> _authHeaders() async {
    final token = (await getToken())?.trim();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      ..._publicHeaders(),
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // ERROR DAN RESPONSE
  // ============================================================

  static String _extractErrorMessage(dynamic result) {
    if (result is Map) {
      final detail = result['detail'] ?? result['message'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }

      if (detail is List) {
        return detail.map((item) {
          if (item is Map) {
            return (item['msg'] ?? item['message'] ?? item)
                .toString();
          }
          return item.toString();
        }).join('\n');
      }
    }

    return 'Permintaan tidak dapat diproses oleh server.';
  }

  static dynamic _decodeResponse(http.Response response) {
    dynamic result;

    if (response.body.trim().isEmpty) {
      result = null;
    } else {
      try {
        result = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          throw Exception('Format respons server tidak valid.');
        }
      }
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message = _extractErrorMessage(result);

      switch (response.statusCode) {
        case 401:
          throw Exception(
            'Sesi login tidak valid atau kedaluwarsa. $message',
          );
        case 403:
          throw Exception('Akses ditolak. $message');
        case 404:
          throw Exception('Data atau endpoint tidak ditemukan. $message');
        case 409:
          throw Exception('Konflik data atau stok tiket berubah. $message');
        case 422:
          throw Exception('Data yang dikirim tidak valid. $message');
        case 429:
          throw Exception('Terlalu banyak permintaan. Coba lagi nanti.');
        default:
          throw Exception(
            'Permintaan gagal (${response.statusCode}). $message',
          );
      }
    }

    return result;
  }

  static Future<T> _request<T>(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      final result = _decodeResponse(response);
      return result as T;
    } on TimeoutException {
      throw Exception(
        'Koneksi ke server terlalu lama. Periksa jaringan.',
      );
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on http.ClientException {
      throw Exception(
        'Terjadi masalah jaringan saat menghubungi server.',
      );
    } on FormatException {
      throw Exception('Data dari server tidak dapat dibaca.');
    } catch (error) {
      if (error is Exception) rethrow;

      if (kDebugMode) {
        debugPrint('ApiService error: $error');
      }

      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  // ============================================================
  // HTTP REQUESTS
  // ============================================================

  static Future<dynamic> _get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _request<dynamic>(
      () => http.get(
        Uri.parse('$baseUrl$path'),
        headers: headers ?? _publicHeaders(),
      ),
    );
  }

  static Future<dynamic> _post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request<dynamic>(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers ?? _publicHeaders(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  static Future<dynamic> _put(
    String path, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    return _request<dynamic>(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  static Future<void> _delete(
    String path, {
    required Map<String, String> headers,
  }) async {
    await _request<dynamic>(
      () => http.delete(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      ),
    );
  }

  // ============================================================
  // CONVERSI DATA
  // ============================================================

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw Exception('Format objek data dari server tidak sesuai.');
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is Map) {
      value = value['items'] ?? value['data'] ?? value['results'];
    }

    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw Exception('Server tidak mengembalikan daftar data.');
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  // ============================================================
  // SESSION DAN USER
  // ============================================================

  static Future<void> saveToken(String token) async {
    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      throw Exception('Token login kosong.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, normalizedToken);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUserData({
    required int userId,
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_roleKey, role.toLowerCase());
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<bool> isAdmin() async {
    return (await getRole())?.toLowerCase() == 'admin';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
  }

  // ============================================================
  // AUTH
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = _map(
      await _post(
        '/auth/login',
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      ),
    );

    final userValue = result['user'];

    if (userValue is! Map) {
      throw Exception('Respons login tidak memiliki data user.');
    }

    final user = Map<String, dynamic>.from(userValue);
    final token = result['access_token'] ?? result['token'];
    final userId = _parseInt(user['id']);
    final username = user['name'] ?? user['username'];
    final role = user['role'];

    if (token is! String ||
        token.trim().isEmpty ||
        userId == null ||
        username == null ||
        role == null) {
      throw Exception('Data login dari server belum lengkap.');
    }

    await saveToken(token);
    await saveUserData(
      userId: userId,
      username: username.toString(),
      role: role.toString(),
    );

    return {
      ...result,
      'access_token': token,
      'user': user,
    };
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    return _map(
      await _post(
        '/auth/register',
        body: {
          'name': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> getMe() async {
    final user = _map(
      await _get('/auth/me', headers: await _authHeaders()),
    );

    final id = _parseInt(user['id']);
    final username = user['name'] ?? user['username'];
    final role = user['role'];

    if (id != null && username != null && role != null) {
      await saveUserData(
        userId: id,
        username: username.toString(),
        role: role.toString(),
      );
    }

    return user;
  }

  // ============================================================
  // EVENTS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getEvents() async {
    return _list(await _get('/events/'));
  }

  static Future<Map<String, dynamic>> getEventById(
    int eventId,
  ) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return _map(await _get('/events/$eventId'));
  }

  static Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> data,
  ) async {
    return _map(
      await _post(
        '/events/',
        headers: await _authHeaders(),
        body: data,
      ),
    );
  }

  static Future<Map<String, dynamic>> updateEvent(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return _map(
      await _put(
        '/events/$eventId',
        headers: await _authHeaders(),
        body: data,
      ),
    );
  }

  static Future<void> deleteEvent(int eventId) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    await _delete(
      '/events/$eventId',
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // TICKET CLASSES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getTicketClasses(
    int eventId,
  ) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return _list(
      await _get('/events/$eventId/ticket-classes'),
    );
  }

  static Future<Map<String, dynamic>> updateTicketClass({
    required int eventId,
    required int ticketClassId,
    required num price,
    required int availableTickets,
  }) async {
    if (eventId <= 0 || ticketClassId <= 0) {
      throw Exception('ID event atau kelas tiket tidak valid.');
    }

    if (price < 0 || availableTickets < 0) {
      throw Exception('Harga dan stok tidak boleh negatif.');
    }

    return _map(
      await _put(
        '/events/$eventId/ticket-classes/$ticketClassId',
        headers: await _authHeaders(),
        body: {
          'price': price,
          'available_tickets': availableTickets,
        },
      ),
    );
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static Future<Map<String, dynamic>> createOrder({
    required int eventId,
    required int ticketClassId,
    required int quantity,
  }) async {
    if (eventId <= 0 || ticketClassId <= 0) {
      throw Exception('Event atau kelas tiket tidak valid.');
    }

    if (quantity <= 0) {
      throw Exception('Jumlah tiket harus lebih dari nol.');
    }

    return _map(
      await _post(
        '/orders/',
        headers: await _authHeaders(),
        body: {
          'event_id': eventId,
          'ticket_class_id': ticketClassId,
          'quantity': quantity,
        },
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getMyOrders() async {
    return _list(
      await _get('/orders/', headers: await _authHeaders()),
    );
  }

  static Future<Map<String, dynamic>> getOrderDetail(
    int orderId,
  ) async {
    if (orderId <= 0) {
      throw Exception('ID pesanan tidak valid.');
    }

    final response = _map(
      await _get(
        '/orders/$orderId',
        headers: await _authHeaders(),
      ),
    );

    final detail = response['data'];
    if (detail is Map) {
      return Map<String, dynamic>.from(detail);
    }

    return response;
  }

  static Future<void> cancelOrder(int orderId) async {
    if (orderId <= 0) {
      throw Exception('ID pesanan tidak valid.');
    }

    await _delete(
      '/orders/$orderId',
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  static Future<Map<String, dynamic>> createPayment({
    required int orderId,
    required String paymentMethod,
    required String paymentProvider,
  }) async {
    const methods = {
      'transfer_bank',
      'e_wallet',
      'qris',
    };

    if (orderId <= 0) {
      throw Exception('ID pesanan tidak valid.');
    }

    if (!methods.contains(paymentMethod)) {
      throw Exception('Metode pembayaran tidak valid.');
    }

    final provider = paymentProvider.trim();

    if (provider.isEmpty) {
      throw Exception('Silakan pilih penyedia pembayaran.');
    }

    return _map(
      await _post(
        '/payments/',
        headers: await _authHeaders(),
        body: {
          'order_id': orderId,
          'payment_method': paymentMethod,
          'payment_provider': provider,
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> confirmPayment({
    required int paymentId,
  }) async {
    if (paymentId <= 0) {
      throw Exception('ID pembayaran tidak valid.');
    }

    return _map(
      await _post(
        '/payments/$paymentId/confirm',
        headers: await _authHeaders(),
        body: {},
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getMyPayments() async {
    return _list(
      await _get('/payments/', headers: await _authHeaders()),
    );
  }

  // ============================================================
  // ADMIN
  // ============================================================

  static Future<Map<String, dynamic>> getAdminDashboard() async {
    return _map(
      await _get(
        '/admin/dashboard',
        headers: await _authHeaders(),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    return _list(
      await _get(
        '/admin/orders',
        headers: await _authHeaders(),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getAdminPayments() async {
    return _list(
      await _get(
        '/admin/payments',
        headers: await _authHeaders(),
      ),
    );
  }
}
