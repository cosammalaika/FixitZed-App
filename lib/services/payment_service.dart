import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class PaymentResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final int statusCode;

  const PaymentResult({
    required this.success,
    this.message,
    this.data,
    this.statusCode = 0,
  });
}

class PaymentService {
  PaymentService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> get(int requestId) async {
    final token = await _token();
    if (token == null) return null;
    final res = await http.get(
      _uri('requests/$requestId/payment'),
      headers: _headers(token),
    );
    await SessionGuard.evaluate(res);
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      if (root is Map && root['data'] is Map) {
        return Map<String, dynamic>.from(root['data'] as Map);
      }
      if (root is Map) return Map<String, dynamic>.from(root);
    }
    return null;
  }

  Future<PaymentResult> pay({
    required int requestId,
    required double amount,
    double? originalAmount,
    String method = 'manual',
    String transactionId = '',
    String? couponCode,
    int loyaltyPoints = 0,
  }) async {
    final token = await _token();
    if (token == null) {
      return const PaymentResult(
        success: false,
        message: 'You need to sign in again.',
      );
    }
    final paidAt = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'amount': amount,
      'status': 'paid',
      'payment_method': method,
      'transaction_id': transactionId,
      'payment_date': paidAt,
      'paid_at': paidAt,
      if (originalAmount != null) 'original_amount': originalAmount,
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'coupon_code': couponCode.trim(),
      if (loyaltyPoints > 0) 'loyalty_points': loyaltyPoints,
    };

    final res = await http.post(
      _uri('requests/$requestId/payment'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    await SessionGuard.evaluate(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      Map<String, dynamic>? data;
      String? message;
      try {
        final body = jsonDecode(res.body);
        if (body is Map) {
          data = body['data'] is Map
              ? Map<String, dynamic>.from(body['data'] as Map)
              : Map<String, dynamic>.from(body);
          message = body['message']?.toString();
        }
      } catch (_) {}
      _sync.emit(
        AppSyncTopic.bookings,
        payload: <String, dynamic>{
          'action': 'payment',
          'requestId': requestId,
          'amount': amount,
          'paidAt': paidAt,
        },
      );
      _sync.emit(
        AppSyncTopic.wallet,
        payload: <String, dynamic>{
          'delta': amount,
          'requestId': requestId,
          'paidAt': paidAt,
        },
      );

      return PaymentResult(
        success: true,
        message: message ?? 'Payment successful',
        data: data,
        statusCode: res.statusCode,
      );
    }

    String? errorMessage;
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['message'] != null) {
          errorMessage = body['message'].toString();
        } else if (body['errors'] is Map &&
            (body['errors'] as Map).isNotEmpty) {
          final first = (body['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) {
            errorMessage = first.first.toString();
          }
        }
      }
    } catch (_) {}

    if (errorMessage == null && res.body.isNotEmpty) {
      var text = res.body;
      if (text.length > 400) {
        text = text.substring(0, 400);
      }
      text = text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (text.isNotEmpty) {
        errorMessage = text;
      }
    }

    errorMessage ??= res.statusCode == 401
        ? 'You are not authorized to complete this payment.'
        : 'Payment failed. Please try again.';

    return PaymentResult(
      success: false,
      message: errorMessage,
      statusCode: res.statusCode,
    );
  }
}
