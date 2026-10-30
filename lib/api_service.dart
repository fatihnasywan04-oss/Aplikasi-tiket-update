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

  /// Batas waktu pembayaran simulasi.
  /// Waktu resmi tetap mengikuti expires_at dari backend.
  static const Duration paymentExpiration = Duration(seconds: 60);

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

  static Future<Map<String, String>> _adminHeaders() async {
    if (!await isAdmin()) {
      throw Exception(
        'Fitur ini hanya dapat digunakan oleh admin.',
      );
    }

    return _authHeaders();
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
            return (
              item['msg'] ??
              item['message'] ??
              item
            ).toString();
          }

          return item.toString();
        }).join('\n');
      }

      if (detail is Map) {
        return detail.toString();
      }
    }

    if (result is String && result.trim().isNotEmpty) {
      return result.trim();
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
          throw Exception(
            'Format respons server tidak valid.',
          );
        }

        result = response.body;
      }
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message = _extractErrorMessage(result);

      switch (response.statusCode) {
        case 400:
          throw Exception(
            'Permintaan tidak dapat diproses. $message',
          );

        case 401:
          throw Exception(
            'Sesi login tidak valid atau kedaluwarsa. $message',
          );

        case 403:
          throw Exception('Akses ditolak. $message');

        case 404:
          throw Exception(
            'Endpoint atau data tidak ditemukan. $message',
          );

        case 409:
          throw Exception(
            'Konflik data atau stok tiket berubah. $message',
          );

        case 413:
          throw Exception(
            'Ukuran file terlalu besar. Pilih gambar yang lebih kecil.',
          );

        case 422:
          throw Exception(
            'Data yang dikirim tidak valid. $message',
          );

        case 429:
          throw Exception(
            'Terlalu banyak permintaan. Coba lagi nanti.',
          );

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

      if (result is T) {
        return result;
      }

      if (result == null && T == dynamic) {
        return result as T;
      }

      throw Exception(
        'Tipe respons server tidak sesuai dengan yang diharapkan.',
      );
    } on TimeoutException {
      throw Exception(
        'Koneksi ke server terlalu lama. Periksa jaringan.',
      );
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on http.ClientException catch (error) {
      if (kDebugMode) {
        debugPrint('ApiService network error: $error');
      }

      throw Exception(
        'Terjadi masalah jaringan saat menghubungi server.',
      );
    } on FormatException {
      throw Exception(
        'Data dari server tidak dapat dibaca.',
      );
    } catch (error) {
      if (error is Exception) {
        rethrow;
      }

      if (kDebugMode) {
        debugPrint('ApiService unexpected error: $error');
      }

      throw Exception(
        'Terjadi kesalahan yang tidak terduga.',
      );
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
  // KONVERSI RESPONSE
  // ============================================================

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) {
      throw Exception(
        'Format objek data dari server tidak sesuai.',
      );
    }

    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic> _unwrapMap(dynamic value) {
    dynamic current = value;

    for (int depth = 0; depth < 6; depth++) {
      if (current is! Map) {
        break;
      }

      if (current['data'] is Map) {
        current = current['data'];
        continue;
      }

      return Map<String, dynamic>.from(current);
    }

    return _map(current);
  }

  /// Mendukung list langsung atau list di dalam wrapper API.
  static List<Map<String, dynamic>> _list(dynamic value) {
    dynamic current = value;

    for (int depth = 0; depth < 6; depth++) {
      if (current is List) {
        return current
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      if (current is! Map) {
        break;
      }

      dynamic next;
      bool found = false;

      for (final key in [
        'items',
        'data',
        'results',
        'orders',
        'payments',
      ]) {
        if (current.containsKey(key) &&
            current[key] != null) {
          next = current[key];
          found = true;
          break;
        }
      }

      if (!found) {
        break;
      }

      current = next;
    }

    if (current == null) {
      return [];
    }

    throw Exception(
      'Server tidak mengembalikan daftar data '
      'dalam format yang dikenali.',
    );
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

    await prefs.setString(
      _tokenKey,
      normalizedToken,
    );
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
    await prefs.setString(
      _roleKey,
      role.trim().toLowerCase(),
    );
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
    return (await getRole())?.trim().toLowerCase() == 'admin';
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
    final result = _unwrapMap(
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
        'Respons login tidak memiliki data user.',
      );
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
      throw Exception(
        'Data login dari server belum lengkap.',
      );
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
    return _unwrapMap(
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
    final user = _unwrapMap(
      await _get(
        '/auth/me',
        headers: await _authHeaders(),
      ),
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
  // EVENTS DAN UPLOAD POSTER
  // ============================================================

  /// Upload poster dengan multipart/form-data.
  ///
  /// Backend yang diasumsikan:
  /// POST /events/upload-image
  /// Field upload: file
  ///
  /// Respons contoh:
  /// {"image_url": "/uploads/events/poster.jpg"}
  static Future<String> uploadEventImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('File poster tidak ditemukan.');
    }

    final fileLength = await imageFile.length();

    if (fileLength <= 0) {
      throw Exception('File poster kosong.');
    }

    const maxImageSize = 5 * 1024 * 1024;

    if (fileLength > maxImageSize) {
      throw Exception('Ukuran poster maksimal 5 MB.');
    }

    final headers = await _adminHeaders();

    // MultipartRequest menentukan Content-Type beserta boundary.
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/events/upload-image'),
      );

      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: imageFile.uri.pathSegments.isNotEmpty
              ? imageFile.uri.pathSegments.last
              : 'event_poster.jpg',
        ),
      );

      final streamedResponse = await request.send().timeout(
        _timeout,
      );

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_timeout);

      final result = _decodeResponse(response);
      final data = _unwrapMap(result);

      final rawImageUrl = data['image_url']?.toString().trim();

      if (rawImageUrl == null || rawImageUrl.isEmpty) {
        throw Exception(
          'URL poster tidak ditemukan dalam respons server.',
        );
      }

      final imageUri = Uri.tryParse(rawImageUrl);

      if (imageUri == null) {
        throw Exception('Format URL poster tidak valid.');
      }

      // URL lengkap.
      if (imageUri.hasScheme) {
        if (!{'http', 'https'}.contains(imageUri.scheme) ||
            imageUri.host.isEmpty) {
          throw Exception('URL poster dari server tidak valid.');
        }

        return imageUri.toString();
      }

      // URL protokol-relatif, misalnya //cdn.example.com/image.jpg.
      if (rawImageUrl.startsWith('//')) {
        return 'https:$rawImageUrl';
      }

      // URL relatif, misalnya /uploads/events/poster.jpg.
      return Uri.parse(baseUrl).resolve(rawImageUrl).toString();
    } on TimeoutException {
      throw Exception(
        'Upload poster melewati batas waktu. Periksa koneksi internet.',
      );
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke server saat mengunggah poster.',
      );
    } on http.ClientException catch (error) {
      if (kDebugMode) {
        debugPrint('ApiService upload error: $error');
      }

      throw Exception(
        'Terjadi masalah jaringan saat mengunggah poster.',
      );
    } on FileSystemException {
      throw Exception(
        'File poster tidak dapat dibaca. Pilih gambar lain.',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getEvents() async {
    return _list(await _get('/events/'));
  }

  static Future<Map<String, dynamic>> getEventById(
    int eventId,
  ) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return _unwrapMap(
      await _get('/events/$eventId'),
    );
  }

  static Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> data,
  ) async {
    return _unwrapMap(
      await _post(
        '/events/',
        headers: await _adminHeaders(),
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

    return _unwrapMap(
      await _put(
        '/events/$eventId',
        headers: await _adminHeaders(),
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
      headers: await _adminHeaders(),
    );
  }

  /// Memerlukan endpoint POST /events/{id}/cancel di backend.
  static Future<Map<String, dynamic>> cancelEvent(
    int eventId, {
    String? reason,
  }) async {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    final body = <String, dynamic>{};

    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }

    return _unwrapMap(
      await _post(
        '/events/$eventId/cancel',
        headers: await _adminHeaders(),
        body: body,
      ),
    );
  }

  // ============================================================
  // TICKET CLASSES
  // ============================================================

  static String _ticketClassPath(int eventId) {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    return '/events/$eventId/ticket-classes';
  }

  static void _validateTicketClassIds({
    required int eventId,
    int? ticketClassId,
  }) {
    if (eventId <= 0) {
      throw Exception('ID event tidak valid.');
    }

    if (ticketClassId != null && ticketClassId <= 0) {
      throw Exception('ID kelas tiket tidak valid.');
    }
  }

  /// Endpoint yang diasumsikan:
  /// GET /events/{event_id}/ticket-classes/
  static Future<List<Map<String, dynamic>>> getTicketClasses(
    int eventId,
  ) async {
    _validateTicketClassIds(eventId: eventId);

    return _list(
      await _get('${_ticketClassPath(eventId)}/'),
    );
  }

  static Future<Map<String, dynamic>> getTicketClassById({
    required int eventId,
    required int ticketClassId,
  }) async {
    _validateTicketClassIds(
      eventId: eventId,
      ticketClassId: ticketClassId,
    );

    return _unwrapMap(
      await _get(
        '${_ticketClassPath(eventId)}/$ticketClassId',
      ),
    );
  }

  static Future<Map<String, dynamic>> createTicketClass({
    required int eventId,
    required String name,
    required num price,
    required int availableTickets,
  }) async {
    _validateTicketClassIds(eventId: eventId);

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw Exception('Nama kelas tiket wajib diisi.');
    }

    if (normalizedName.length > 30) {
      throw Exception('Nama kelas tiket maksimal 30 karakter.');
    }

    if (price < 0) {
      throw Exception('Harga tiket tidak boleh negatif.');
    }

    if (availableTickets < 0) {
      throw Exception('Stok tiket tidak boleh negatif.');
    }

    return _unwrapMap(
      await _post(
        '${_ticketClassPath(eventId)}/',
        headers: await _adminHeaders(),
        body: {
          'name': normalizedName,
          'price': price,
          'available_tickets': availableTickets,
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> updateTicketClass({
    required int eventId,
    required int ticketClassId,
    String? name,
    required num price,
    required int availableTickets,
  }) async {
    _validateTicketClassIds(
      eventId: eventId,
      ticketClassId: ticketClassId,
    );

    if (price < 0) {
      throw Exception('Harga tiket tidak boleh negatif.');
    }

    if (availableTickets < 0) {
      throw Exception('Stok tiket tidak boleh negatif.');
    }

    final body = <String, dynamic>{
      'price': price,
      'available_tickets': availableTickets,
    };

    if (name != null) {
      final normalizedName = name.trim();

      if (normalizedName.isEmpty) {
        throw Exception(
          'Nama kelas tiket tidak boleh kosong.',
        );
      }

      if (normalizedName.length > 30) {
        throw Exception('Nama kelas tiket maksimal 30 karakter.');
      }

      body['name'] = normalizedName;
    }

    return _unwrapMap(
      await _put(
        '${_ticketClassPath(eventId)}/$ticketClassId',
        headers: await _adminHeaders(),
        body: body,
      ),
    );
  }

  static Future<Map<String, dynamic>> updateTicketClassPrice({
    required int eventId,
    required int ticketClassId,
    required num price,
  }) async {
    if (price < 0) {
      throw Exception('Harga tiket tidak boleh negatif.');
    }

    final ticketClasses = await getTicketClasses(eventId);

    final ticketClass = ticketClasses.firstWhere(
      (item) => _parseInt(item['id']) == ticketClassId,
      orElse: () => throw Exception(
        'Kelas tiket tidak ditemukan.',
      ),
    );

    final currentStock =
        _parseInt(ticketClass['available_tickets']) ?? 0;

    return updateTicketClass(
      eventId: eventId,
      ticketClassId: ticketClassId,
      name: ticketClass['name']?.toString(),
      price: price,
      availableTickets: currentStock,
    );
  }

  static Future<void> deleteTicketClass({
    required int eventId,
    required int ticketClassId,
  }) async {
    _validateTicketClassIds(
      eventId: eventId,
      ticketClassId: ticketClassId,
    );

    await _delete(
      '${_ticketClassPath(eventId)}/$ticketClassId',
      headers: await _adminHeaders(),
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

    return _unwrapMap(
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
    final result = await _get(
      '/orders/',
      headers: await _authHeaders(),
    );

    final orders = _list(result);

    if (kDebugMode) {
      debugPrint(
        '[ApiService] GET /orders/ berhasil. '
        'Jumlah pesanan: ${orders.length}',
      );

      if (orders.isNotEmpty) {
        debugPrint(
          '[ApiService] ID pesanan pertama: '
          '${orders.first['id'] ?? orders.first['order_id']}',
        );
      }
    }

    return orders;
  }

  static Future<Map<String, dynamic>> getOrderDetail(
    int orderId,
  ) async {
    if (orderId <= 0) {
      throw Exception('ID pesanan tidak valid.');
    }

    return _unwrapMap(
      await _get(
        '/orders/$orderId',
        headers: await _authHeaders(),
      ),
    );
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

  static DateTime? parseOrderExpiration(
    Map<String, dynamic> order,
  ) {
    final value = order['expires_at'];

    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return null;

    return parsed.toUtc();
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

    final normalizedMethod = paymentMethod.trim().toLowerCase();

    if (!methods.contains(normalizedMethod)) {
      throw Exception(
        'Metode pembayaran tidak valid. '
        'Gunakan transfer_bank, e_wallet, atau qris.',
      );
    }

    final provider = paymentProvider.trim();

    if (provider.isEmpty) {
      throw Exception('Silakan pilih penyedia pembayaran.');
    }

    return _unwrapMap(
      await _post(
        '/payments/',
        headers: await _authHeaders(),
        body: {
          'order_id': orderId,
          'payment_method': normalizedMethod,
          'payment_provider': provider,
        },
      ),
    );
  }

  /// Endpoint simulasi: POST /payments/{payment_id}/confirm.
  static Future<Map<String, dynamic>> confirmPayment({
    required int paymentId,
  }) async {
    if (paymentId <= 0) {
      throw Exception('ID pembayaran tidak valid.');
    }

    return _unwrapMap(
      await _post(
        '/payments/$paymentId/confirm',
        headers: await _authHeaders(),
        body: {},
      ),
    );
  }

  /// Endpoint backend: GET /payments/my.
  static Future<List<Map<String, dynamic>>> getMyPayments() async {
    return _list(
      await _get(
        '/payments/my',
        headers: await _authHeaders(),
      ),
    );
  }

  // ============================================================
  // ADMIN
  // ============================================================

  static Future<Map<String, dynamic>> getAdminDashboard() async {
    return _unwrapMap(
      await _get(
        '/admin/dashboard',
        headers: await _adminHeaders(),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    return _list(
      await _get(
        '/orders/admin/all',
        headers: await _adminHeaders(),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getAdminPayments() async {
    return _list(
      await _get(
        '/admin/payments',
        headers: await _adminHeaders(),
      ),
    );
  }
}