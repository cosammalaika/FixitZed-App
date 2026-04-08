import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/screens/widgets/notification_details_sheet.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final NotificationService _svc;
  bool _loading = true;
  bool _hardFailure = false;
  List<Map<String, dynamic>> _items = const [];
  StreamSubscription<AppSyncEvent>? _syncSub;
  final Set<int> _deleting = <int>{};
  final Set<String> _pendingRemovalKeys = <String>{};
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _svc = ref.read(notificationServiceProvider);
    final cached = ref.read(notificationsRepositoryProvider).cached;
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    unawaited(_load());
    _syncSub = AppSync.instance
        .on(AppSyncTopic.notifications)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    final existing = _loadFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _performLoad(silent: silent, forceRefresh: forceRefresh);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _performLoad({
    required bool silent,
    required bool forceRefresh,
  }) async {
    final shouldShowLoader = !silent && _items.isEmpty;
    if (shouldShowLoader && mounted) {
      setState(() => _loading = true);
    }
    final result = await ref
        .read(notificationsRepositoryProvider)
        .loadNotifications(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _items = result.items;
      _hardFailure =
          !result.success && !result.usedCacheFallback && result.items.isEmpty;
      _loading = false;
    });
  }

  int? _notificationId(Map<String, dynamic> notification) {
    final raw =
        notification['id'] ??
        notification['uuid'] ??
        notification['notification_id'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  bool _sameNotification(Map<String, dynamic> a, Map<String, dynamic> b) {
    final idA = _notificationId(a);
    final idB = _notificationId(b);
    if (idA != null && idB != null) return idA == idB;
    return identical(a, b);
  }

  Widget _dismissBackground({required bool leading}) {
    final colors = Theme.of(context).fx;
    return Align(
      alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 78,
        height: 56,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.danger,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
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
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        backgroundColor: synced
            ? Theme.of(context).fx.success
            : Theme.of(context).fx.warning,
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
    final details = AppNotification.fromMap(n);
    final timeStr = formatAppTime(details.createdAt);
    final theme = Theme.of(context);
    final colors = theme.fx;
    final visual = NotificationVisualStyle.resolve(theme, details);
    final title = details.title.trim().isEmpty
        ? 'Notification'
        : details.title.trim();
    final preview = details.message.trim().isEmpty
        ? 'No additional details available.'
        : details.message.trim();
    final cardColor = details.isRead
        ? colors.surfaceSubtle
        : Color.alphaBlend(
            colors.brand.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.05,
            ),
            colors.surface,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(n),
        borderRadius: BorderRadius.circular(20),
        splashColor: colors.brand.withValues(alpha: 0.1),
        highlightColor: colors.brand.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: details.isRead
                    ? Colors.transparent
                    : colors.brand.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: visual.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visual.icon, color: visual.accentColor),
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
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: GoogleFonts.urbanist(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!details.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    decoration: BoxDecoration(
                      color: colors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isRead(Map<String, dynamic> notification) {
    final readVal =
        notification['read'] ??
        notification['read_at'] ??
        notification['is_read'];
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
    var details = AppNotification.fromMap(notification);

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
    final theme = Theme.of(context);
    final colors = theme.fx;
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
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hardFailure
          ? RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load notifications',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to try again once your connection is stable.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(color: colors.textSecondary),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
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
                                    await _load(
                                      silent: true,
                                      forceRefresh: true,
                                    );
                                  }
                                },
                          child: Text(
                            'Mark All As Read',
                            style: TextStyle(color: colors.brand),
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
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: colors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: GoogleFonts.urbanist(
                              color: colors.textSecondary,
                            ),
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
