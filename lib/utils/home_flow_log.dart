import 'package:flutter/foundation.dart';

class HomeFlowLog {
  HomeFlowLog._();

  static void log(
    String scope,
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer('[home_flow][$scope] $event');
    if (details.isNotEmpty) {
      final parts = <String>[];
      details.forEach((key, value) {
        parts.add('$key=${_stringify(value)}');
      });
      buffer.write(' ${parts.join(' ')}');
    }
    debugPrint(buffer.toString());
  }

  static String _stringify(Object? value) {
    if (value == null) return 'null';
    final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '""';
    return text;
  }
}
