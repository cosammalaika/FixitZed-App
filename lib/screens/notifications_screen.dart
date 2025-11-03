import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/screens/payment_sheet.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  StreamSubscription<AppSyncEvent>? _syncSub;
  final Set<int> _deleting = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
    _syncSub = AppSync.instance
        .on(AppSyncTopic.notifications)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final list = await _svc.fetch();
    if (!mounted) return;
    setState(() {
      _items = list;
      if (!silent) {
        _loading = false;
      }
    });
  }

  int? _notificationId(Map<String, dynamic> notification) {
    final raw = notification['id'] ??
        notification['uuid'] ??
        notification['notification_id'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  bool _sameNotification(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final idA = _notificationId(a);
    final idB = _notificationId(b);
    if (idA != null && idB != null) return idA == idB;
    return identical(a, b);
  }

  Widget _dismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD84343),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> notification) async {
    final id = _notificationId(notification);
    if (id == null) return true;
    if (_deleting.contains(id)) return false;
    setState(() => _deleting.add(id));
    final ok = await _svc.delete(id);
    if (!mounted) return false;
    setState(() => _deleting.remove(id));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete notification',
            style: GoogleFonts.urbanist(),
          ),
          backgroundColor: const Color(0xFFD84343),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return ok;
  }

  void _removeNotification(Map<String, dynamic> notification) {
    if (!mounted) return;
    setState(() {
      _items = _items
          .where((item) => !_sameNotification(item, notification))
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notification removed',
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _dismissibleTile(Map<String, dynamic> notification) {
    final id = _notificationId(notification);
    final key = id != null ? 'notif_$id' : 'notif_${notification.hashCode}';
    return Dismissible(
      key: ValueKey<String>(key),
      direction: DismissDirection.endToStart,
      secondaryBackground: _dismissBackground(),
      confirmDismiss: (_) => _confirmDelete(notification),
      onDismissed: (_) => _removeNotification(notification),
      child: _tile(notification),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final created =
        parseAppDate(n['created_at'] ?? n['updated_at']) ?? DateTime.now();
    final timeStr = formatAppTime(created);
    final title = (n['title'] ?? n['subject'] ?? 'Notification').toString();
    final body = (n['message'] ?? n['body'] ?? '').toString();
    final readVal = n['read'] ?? n['read_at'] ?? n['is_read'];
    final read = readVal == true || (readVal is String && readVal.isNotEmpty);

    return InkWell(
      onTap: () => _handleTap(n),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF6EEEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: Color(0xFFF1592A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.urbanist(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      color: Colors.black54,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (!read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1592A),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(Map<String, dynamic> notification) async {
    final id = (notification['id'] as num?)?.toInt();
    if (id != null) {
      final ok = await _svc.markRead(id);
      if (ok && mounted) {
        setState(() {
          final idx = _items.indexWhere(
            (e) => (e['id'] as num?)?.toInt() == id,
          );
          if (idx != -1) {
            final updated = Map<String, dynamic>.from(_items[idx]);
            updated['read'] = true;
            updated['read_at'] = DateTime.now().toIso8601String();
            _items[idx] = updated;
          }
        });
      }
    }

    final requestId = _parseRequestId(notification);
    final isPayment = _isPaymentNotification(notification);

    if (requestId != null && isPayment) {
      final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(requestId: requestId),
          fullscreenDialog: true,
        ),
      );
      if (paid == true && mounted) {
        await _load();
      }
      return;
    }

    await Navigator.pushNamed(context, '/profile/bookings');
    if (mounted) await _load();
  }

  int? _parseRequestId(Map<String, dynamic> notification) {
    for (final key in const [
      'request_id',
      'service_request_id',
      'request',
      'requestId',
    ]) {
      final value = notification[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool _isPaymentNotification(Map<String, dynamic> notification) {
    final combined = [
      notification['title'],
      notification['subject'],
      notification['message'],
      notification['body'],
    ].whereType<String>().join(' ').toLowerCase();
    return combined.contains('payment') ||
        combined.contains('bill') ||
        combined.contains('invoice');
  }

  @override
  Widget build(BuildContext context) {
    final today = <Map<String, dynamic>>[];
    final yesterday = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final n in _items) {
      final d = parseAppDate(n['created_at'] ?? n['updated_at']) ?? now;
      if (isSameDay(d, now)) {
        today.add(n);
      } else if (isYesterday(d, relativeTo: now)) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Notification',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (today.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Today',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _items.isEmpty
                              ? null
                              : () async {
                                  final ok = await _svc.markAllRead();
                                  if (ok) {
                                    await _load();
                                  }
                                },
                          child: const Text(
                            'Mark All As Read',
                            style: TextStyle(color: Color(0xFFF1592A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...today.map(_dismissibleTile),
                    const SizedBox(height: 18),
                  ],
                  if (yesterday.isNotEmpty) ...[
                    Text(
                      'Yesterday',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...yesterday.map(_dismissibleTile),
                    const SizedBox(height: 18),
                  ],
                  if (earlier.isNotEmpty) ...[
                    Text(
                      'Earlier',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...earlier.map(_dismissibleTile),
                  ],
                  if (today.isEmpty && yesterday.isEmpty && earlier.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: GoogleFonts.urbanist(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
