import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingPayload;

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'fixitzed_default',
        'General Notifications',
        description: 'Request updates, reminders and promotions from FixitZED.',
        importance: Importance.high,
      );

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        handlePayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundTapHandler,
    );

    if (Platform.isAndroid) {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidSpecific != null) {
        await androidSpecific.createNotificationChannel(_defaultChannel);
        await androidSpecific.requestNotificationsPermission();
      }
    } else if (Platform.isIOS) {
      final iosSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosSpecific?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isMacOS) {
      final macSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macSpecific?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
  }

  void bindNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingPayload != null) {
        final payload = _pendingPayload;
        _pendingPayload = null;
        handlePayload(payload);
      }
    });
  }

  Future<void> showInstant({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (kIsWeb) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> notifyBookingCreated({
    required String serviceName,
    required DateTime scheduledAt,
    String? location,
  }) async {
    final formatted = DateFormat('EEE, MMM d • HH:mm').format(scheduledAt);
    final body = location == null || location.isEmpty
        ? '$serviceName is requested for $formatted.'
        : '$serviceName is requested for $formatted at $location.';
    await showInstant(
      title: 'Request scheduled',
      body: body,
      payload: 'booking_created',
    );
  }

  void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingPayload = payload;
      return;
    }

    if (payload.startsWith('booking_detail:')) {
      final id = int.tryParse(payload.split(':').last);
      if (id != null) {
        navigator.pushNamed('/profile/booking-detail', arguments: {'id': id});
      }
      return;
    }

    if (payload.startsWith('booking_status:')) {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final id = int.tryParse(parts[1]);
        if (id != null) {
          navigator.pushNamed('/profile/booking-detail', arguments: {'id': id});
        }
      }
      return;
    }

    if (payload.startsWith('remote_notification:')) {
      navigator.pushNamed('/notifications');
      return;
    }

    if (payload == 'booking_created') {
      navigator.pushNamed('/profile/bookings');
    }
  }

  @pragma('vm:entry-point')
  static void _backgroundTapHandler(NotificationResponse response) {
    // The plugin re-enters the app with the payload. Navigation is handled
    // after startup once the navigator key is attached.
  }
}
