import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/screens/widgets/notification_details_sheet.dart';
import 'package:fixitzed_app/services/notification_service.dart';
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
  final Set<String> _pendingRemovalKeys = <String>{};

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

  Widget _dismissBackground({required bool leading}) {
    return Align(
      alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 78,
        height: 56,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD84343),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    Map<String, dynamic> notification,
    String key,
  ) async {
    final id = _notificationId(notification);
    if (id == null) {
      _pendingRemovalKeys.add(key);
      _removeNotification(notification, synced: false);
      return true;
    }
    if (_deleting.contains(id)) return false;
    setState(() => _deleting.add(id));
    final ok = await _svc.delete(id);
    if (!mounted) return false;
    setState(() => _deleting.remove(id));
    if (!ok) {
      _pendingRemovalKeys.add(key);
      _removeNotification(notification, synced: false);
      return true;
    }
    return true;
  }

  void _removeNotification(
    Map<String, dynamic> notification, {
    bool synced = true,
  }) {
    if (!mounted) return;
    setState(() {
      _items = _items
          .where((item) => !_sameNotification(item, notification))
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Notification removed'
              : 'Notification hidden locally. Could not sync with server.',
          style: GoogleFonts.urbanist(
            color: Colors.white,
          ),
        ),
        backgroundColor:
            synced ? const Color(0xFF2E7D32) : const Color(0xFFE67E22),
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
      background: _dismissBackground(leading: true),
      secondaryBackground: _dismissBackground(leading: false),
      confirmDismiss: (_) => _confirmDelete(notification, key),
      onDismissed: (_) {
        if (_pendingRemovalKeys.remove(key)) return;
        _removeNotification(notification);
      },
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

  bool _isRead(Map<String, dynamic> notification) {
    final readVal =
        notification['read'] ?? notification['read_at'] ?? notification['is_read'];
    return readVal == true || (readVal is String && readVal.isNotEmpty);
  }

  void _markReadLocal(Map<String, dynamic> notification) {
    final id = _notificationId(notification);
    final now = DateTime.now().toIso8601String();
    if (!mounted) return;
    setState(() {
      _items = _items.map((item) {
        final same = id != null
            ? _notificationId(item) == id
            : identical(item, notification);
        if (!same) return item;
        final updated = Map<String, dynamic>.from(item);
        updated['read'] = true;
        updated['is_read'] = true;
        updated['read_at'] = updated['read_at'] ?? now;
        return updated;
      }).toList();
    });
  }

  Future<void> _syncRead(Map<String, dynamic> notification) async {
    final id = _notificationId(notification);
    if (id == null) return;
    await _svc.markRead(id);
  }

  Future<void> _handleTap(Map<String, dynamic> notification) async {
    final wasRead = _isRead(notification);
    AppNotification details = AppNotification.fromMap(notification);

    // Auto-mark on open for immediate UX feedback in the list.
    if (!wasRead) {
      _markReadLocal(notification);
      unawaited(_syncRead(notification));
      details = details.copyWith(
        isRead: true,
        readAt: details.readAt ?? DateTime.now(),
      );
    }

    await showNotificationDetailsSheet(
      context,
      details,
      onMarkRead: (updated) async {
        if (_isRead(notification)) return;
        _markReadLocal(notification);
        await _syncRead(notification);
      },
    );
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
