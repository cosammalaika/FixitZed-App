import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/date_utils.dart';

class AppNotification {
  const AppNotification({
    this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  final int? id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  static AppNotification fromMap(Map<String, dynamic> map) {
    int? parseId(dynamic raw) {
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
      return null;
    }

    bool parseRead(dynamic readVal) {
      if (readVal is bool) return readVal;
      if (readVal is num) return readVal != 0;
      if (readVal is String) {
        final normalized = readVal.trim().toLowerCase();
        if (normalized.isEmpty) return false;
        if (normalized == '0' || normalized == 'false' || normalized == 'no') {
          return false;
        }
        return true;
      }
      return false;
    }

    final created = parseAppDate(map['created_at'] ?? map['updated_at']) ??
        DateTime.now();
    final readAt = parseAppDate(map['read_at']);
    final read = parseRead(map['read'] ?? map['read_at'] ?? map['is_read']);

    return AppNotification(
      id: parseId(map['id'] ?? map['uuid'] ?? map['notification_id']),
      title: (map['title'] ?? map['subject'] ?? 'Notification').toString(),
      message: (map['message'] ?? map['body'] ?? '').toString(),
      createdAt: created,
      isRead: read,
      readAt: readAt,
    );
  }
}

class NotificationDetailsSheet extends StatefulWidget {
  const NotificationDetailsSheet({
    super.key,
    required this.notification,
    this.onMarkRead,
    this.messageScrollController,
    this.isLongMessage = false,
  });

  final AppNotification notification;
  final Future<void> Function(AppNotification notification)? onMarkRead;
  final ScrollController? messageScrollController;
  final bool isLongMessage;

  @override
  State<NotificationDetailsSheet> createState() => _NotificationDetailsSheetState();
}

class _NotificationDetailsSheetState extends State<NotificationDetailsSheet> {
  static const Color _sheetBackground = Color(0xFFFFF7F2);
  static const Color _accent = Color(0xFFFF6A2B);
  static const Color _headerStart = Color(0xFFFFF1E8);
  static const Color _headerEnd = Color(0xFFFFF7F2);
  static const double _radius = 30;

  late bool _isRead;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _isRead = widget.notification.isRead;
  }

  Future<void> _handleMarkRead() async {
    if (_isRead || _marking || widget.onMarkRead == null) return;
    setState(() => _marking = true);
    final marked = widget.notification.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    try {
      await widget.onMarkRead!(marked);
      if (!mounted) return;
      setState(() {
        _isRead = true;
      });
    } finally {
      if (mounted) {
        setState(() => _marking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleColor = cs.onSurface;
    final bodyColor = cs.onSurface.withValues(alpha: 0.82);
    final metaColor = cs.onSurface.withValues(alpha: 0.58);
    final dividerColor = cs.onSurface.withValues(alpha: 0.08);
    final showMarkRead = !_isRead && widget.onMarkRead != null;
    final title = widget.notification.title.trim().isEmpty
        ? 'Notification'
        : widget.notification.title.trim();
    final message = widget.notification.message.trim().isEmpty
        ? 'No message details.'
        : widget.notification.message.trim();

    return Container(
      decoration: const BoxDecoration(
        color: _sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_headerStart, _headerEnd],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    InkResponse(
                      radius: 18,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x17000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatAppDateTime(widget.notification.createdAt),
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: metaColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isRead
                                  ? cs.onSurface.withValues(alpha: 0.07)
                                  : _accent.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _isRead ? 'Read' : 'Unread',
                              style: GoogleFonts.urbanist(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isRead
                                    ? cs.onSurface.withValues(alpha: 0.72)
                                    : _accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: dividerColor),
                      const SizedBox(height: 12),
                      widget.isLongMessage
                          ? SizedBox(
                              height: 150,
                              child: Scrollbar(
                                controller: widget.messageScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: widget.messageScrollController,
                                  child: Text(
                                    message,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 15,
                                      height: 1.45,
                                      color: bodyColor,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              message,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.urbanist(
                                fontSize: 15,
                                height: 1.45,
                                color: bodyColor,
                              ),
                            ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: dividerColor),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              foregroundColor: _accent,
                              textStyle: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                          if (showMarkRead) ...[
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _marking ? null : _handleMarkRead,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                textStyle: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                              ),
                              child: Text(
                                _marking ? 'Marking...' : 'Mark as read',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isLongMessage(String message) {
  final text = message.trim();
  if (text.length > 220) return true;
  final lines = '\n'.allMatches(text).length + 1;
  return lines > 6;
}

Future<void> showNotificationDetails(
  BuildContext context,
  AppNotification notification, {
  Future<void> Function(AppNotification notification)? onMarkRead,
}) async {
  final longMessage = _isLongMessage(notification.message);
  final maxHeight = MediaQuery.of(context).size.height * 0.45;
  final compactHeight = _compactSheetHeight(
    context,
    notification,
    showMarkReadAction: !notification.isRead && onMarkRead != null,
  );

  if (longMessage) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.34,
          maxChildSize: 0.45,
          builder: (_, scrollController) {
            return NotificationDetailsSheet(
              notification: notification,
              onMarkRead: onMarkRead,
              messageScrollController: scrollController,
              isLongMessage: true,
            );
          },
        );
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) {
      return SizedBox(
        height: compactHeight.clamp(0, maxHeight),
        child: NotificationDetailsSheet(
          notification: notification,
          onMarkRead: onMarkRead,
          isLongMessage: false,
        ),
      );
    },
  );
}

double _compactSheetHeight(
  BuildContext context,
  AppNotification notification, {
  required bool showMarkReadAction,
}) {
  final maxHeight = MediaQuery.of(context).size.height * 0.45;
  final message = notification.message.trim();
  final estimatedLines = message.isEmpty ? 2 : (message.length / 44).ceil();
  final clampedLines = estimatedLines.clamp(2, 6);
  final estimated = 256.0 +
      (clampedLines * 14.0) +
      (showMarkReadAction ? 20.0 : 6.0);
  final upper = maxHeight < 360 ? maxHeight : 360.0;
  final lower = upper < 280 ? upper : 280.0;

  return estimated.clamp(lower, upper).toDouble();
}

Future<void> showNotificationDetailsSheet(
  BuildContext context,
  AppNotification notification, {
  Future<void> Function(AppNotification notification)? onMarkRead,
}) {
  return showNotificationDetails(
    context,
    notification,
    onMarkRead: onMarkRead,
  );
}
