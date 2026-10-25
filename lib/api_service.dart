
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://backend-fastapi-1.fadehost.app';

  static const Duration _timeout = Duration(seconds: 20);

  // HEADERS

  static Map<String, String> _publicHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> _authHeaders() async {
    final token = (await getToken())?.trim();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Token login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      ..._publicHeaders(),
      'Authorization': 'Bearer $token',
    };
  }

  // RESPONSE HANDLING

  static dynamic _decodeResponse(http.Response response) {
    dynamic result;

    try {
      result = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode == 401) {
        throw Exception(
          'Sesi login tidak valid atau sudah kedaluwarsa. '
          'Silakan login kembali.',
        );
      }

      throw Exception('Respons server tidak valid.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Permintaan gagal (${response.statusCode}).';

      if (result is Map) {
        final detail = result['detail'] ?? result['message'];

        if (detail is String && detail.isNotEmpty) {
          message = detail;
        } else if (detail is List) {
          message = detail.map((item) {
            if (item is Map) {
              return item['msg']?.toString() ?? item.toString();
            }
            return item.toString();
          }).join('\n');
        }
      }

      if (response.statusCode == 401) {
        throw Exception(
          'Sesi login tidak valid atau sudah kedaluwarsa. '
          'Silakan login kembali. Detail: $message',
        );
      }

      if (response.statusCode == 403) {
        throw Exception('Akses ditolak: $message');
      }

      throw Exception(message);
    }

    return result;
  }

  // HTTP REQUESTS

  static Future<dynamic> _get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: headers ?? _publicHeaders(),
        )
        .timeout(_timeout);

    return _decodeResponse(response);
  }

  static Future<dynamic> _post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers ?? _publicHeaders(),
          body: jsonEncode(body ?? {}),
        )
        .timeout(_timeout);

    return _decodeResponse(response);
  }

  static Future<dynamic> _put(
    String path, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _decodeResponse(response);
  }

  static Future<void> _delete(
    String path, {
    required Map<String, String> headers,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: headers,
        )
        .timeout(_timeout);

    _decodeResponse(response);
  }

  // DATA CONVERSION

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw Exception('Format data dari server tidak sesuai.');
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is Map) {
      value = value['items'] ??
          value['data'] ??
          value['results'];
    }

    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw Exception('Server tidak mengembalikan daftar data.');
  }

  // SESSION

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token.trim());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveUserData({
    required int userId,
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('user_id', userId);
    await prefs.setString('username', username);
    await prefs.setString('role', role);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role');
  }

  // AUTH

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
      throw Exception(
        'Respons login tidak memiliki objek user.',
      );
    }

    final user = Map<String, dynamic>.from(userValue);
    final token = result['access_token'] ?? result['token'];
    final id = int.tryParse('${user['id']}');

    final username = user['username'] ?? user['name'];
    final role = user['role'];

    if (token is! String ||
        token.trim().isEmpty ||
        id == null ||
        username == null ||
        role == null) {
      throw Exception(
        'Data login dari server belum lengkap.',
      );
    }

    await saveToken(token);

    await saveUserData(
      userId: id,
      username: username.toString(),
      role: role.toString(),
    );

    return result;
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
    return _map(
      await _get(
        '/auth/me',
        headers: await _authHeaders(),
      ),
    );
  }

  // EVENTS

  static Future<List<Map<String, dynamic>>> getEvents() async {
    return _list(await _get('/events/'));
  }

  static Future<Map<String, dynamic>> getEventById(
    int eventId,
  ) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return _map(
      await _get('/events/$eventId'),
    );
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

  // ORDERS

  static Future<Map<String, dynamic>> createOrder({
    required int eventId,
    required int quantity,
  }) async {
    if (eventId <= 0 || quantity <= 0) {
      throw Exception(
        'Event atau jumlah tiket tidak valid.',
      );
    }

    return _map(
      await _post(
        '/orders/',
        headers: await _authHeaders(),
        body: {
          'event_id': eventId,
          'quantity': quantity,
        },
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getMyOrders() async {
    return _list(
      await _get(
        '/orders/',
        headers: await _authHeaders(),
      ),
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

    // Mendukung respons langsung atau dibungkus dalam "data".
    final detail = response['data'];

    if (detail is Map) {
      return Map<String, dynamic>.from(detail);
    }

    return response;
  }

  /// Membatalkan pesanan milik user yang masih pending.
  static Future<void> cancelOrder(int orderId) async {
    if (orderId <= 0) {
      throw Exception('ID pesanan tidak valid.');
    }

    await _delete(
      '/orders/$orderId',
      headers: await _authHeaders(),
    );
  }

  // PAYMENTS

  static Future<Map<String, dynamic>> createPayment({
    required int orderId,
    required String paymentMethod,
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

    return _map(
      await _post(
        '/payments/',
        headers: await _authHeaders(),
        body: {
          'order_id': orderId,
          'payment_method': paymentMethod,
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
      await _get(
        '/payments/',
        headers: await _authHeaders(),
      ),
    );
  }

  // ADMIN

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
