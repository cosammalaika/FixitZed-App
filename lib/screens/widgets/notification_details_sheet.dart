import 'dart:async';
import 'dart:math' as math;

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
    this.type = '',
    this.iconKey,
    this.data = const <String, dynamic>{},
  });

  final int? id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String type;
  final String? iconKey;
  final Map<String, dynamic> data;

  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? type,
    String? iconKey,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      data: data ?? this.data,
    );
  }

  static AppNotification fromMap(Map<String, dynamic> map) {
    int? parseId(dynamic raw) {
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
      return null;
    }

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    String parseString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      final parsed = value.toString().trim();
      return parsed.isEmpty ? fallback : parsed;
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

    final data = parseMap(map['data']);
    final readAt = parseAppDate(map['read_at']);

    return AppNotification(
      id: parseId(map['id'] ?? map['uuid'] ?? map['notification_id']),
      title: parseString(
        map['title'] ?? map['subject'] ?? map['heading'],
        fallback: 'Notification',
      ),
      message: parseString(
        map['message'] ??
            map['body'] ??
            map['content'] ??
            data['message'] ??
            data['body'],
      ),
      createdAt:
          parseAppDate(
            map['created_at'] ?? map['updated_at'] ?? map['createdAt'],
          ) ??
          DateTime.now(),
      isRead: parseRead(map['read'] ?? map['is_read']) || readAt != null,
      readAt: readAt,
      type: parseString(
        map['type'] ?? data['type'] ?? data['notification_type'],
      ),
      iconKey: parseString(
        map['icon'] ?? data['icon'] ?? data['icon_name'] ?? data['icon_key'],
      ),
      data: data,
    );
  }
}

class NotificationDetailsSheet extends StatelessWidget {
  const NotificationDetailsSheet({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = NotificationVisualStyle.resolve(theme, notification);
    final title = notification.title.trim().isEmpty
        ? 'Notification'
        : notification.title.trim();
    final message = notification.message.trim().isEmpty
        ? 'No additional details are available for this notification.'
        : notification.message.trim();
    final statusLabel = notification.isRead ? 'Read' : 'Unread';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final sheetTop = theme.brightness == Brightness.dark
        ? Color.alphaBlend(
            const Color(0xFFF1592A).withValues(alpha: 0.12),
            scheme.surface,
          )
        : const Color(0xFFFFF5EE);
    final cardBorder = scheme.outline.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
    );
    final textPrimary = scheme.onSurface;
    final textSecondary = scheme.onSurface.withValues(alpha: 0.62);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(12, bottomInset + 12)),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: size.height * 0.78,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sheetTop, scheme.surface],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.34
                              : 0.12,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.18
                                      : 0.05,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: visual.backgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  visual.icon,
                                  color: visual.accentColor,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  customBorder: const CircleBorder(),
                                  child: Ink(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: textSecondary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.16
                                      : 0.04,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatAppDateTime(notification.createdAt),
                                      style: GoogleFonts.urbanist(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _StatusChip(
                                    label: statusLabel,
                                    isRead: notification.isRead,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: scheme.outline.withValues(alpha: 0.12),
                                height: 1,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                message,
                                style: GoogleFonts.urbanist(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: textPrimary.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Divider(
                                color: scheme.outline.withValues(alpha: 0.12),
                                height: 1,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFF1592A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationVisualStyle {
  const NotificationVisualStyle({
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  static NotificationVisualStyle resolve(
    ThemeData theme,
    AppNotification notification,
  ) {
    final scheme = theme.colorScheme;
    final hints = <String>[
      notification.type,
      notification.iconKey ?? '',
      notification.title,
      notification.message,
      notification.data['type']?.toString() ?? '',
      notification.data['notification_type']?.toString() ?? '',
      notification.data['icon']?.toString() ?? '',
      notification.data['category']?.toString() ?? '',
    ].join(' ').toLowerCase();

    const brand = Color(0xFFF1592A);
    const green = Color(0xFF2E9D6A);
    const blue = Color(0xFF3276E8);
    const red = Color(0xFFE45A4F);

    Color tinted(Color color, double opacity) {
      return Color.alphaBlend(color.withValues(alpha: opacity), scheme.surface);
    }

    if (_hasAny(hints, [
      'wallet',
      'payment',
      'transaction',
      'refund',
      'withdraw',
      'credit',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.account_balance_wallet_outlined,
        accentColor: green,
        backgroundColor: tinted(
          green,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, ['chat', 'message', 'support', 'reply'])) {
      return NotificationVisualStyle(
        icon: Icons.chat_bubble_outline_rounded,
        accentColor: blue,
        backgroundColor: tinted(
          blue,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, [
      'alert',
      'warning',
      'cancel',
      'declined',
      'failed',
      'issue',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.error_outline_rounded,
        accentColor: red,
        backgroundColor: tinted(
          red,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, [
      'booking',
      'request',
      'service',
      'repair',
      'fixer',
      'assigned',
      'order',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.event_available_rounded,
        accentColor: brand,
        backgroundColor: tinted(
          brand,
          theme.brightness == Brightness.dark ? 0.2 : 0.12,
        ),
      );
    }
    return NotificationVisualStyle(
      icon: Icons.notifications_active_outlined,
      accentColor: brand,
      backgroundColor: tinted(
        brand,
        theme.brightness == Brightness.dark ? 0.2 : 0.12,
      ),
    );
  }

  static bool _hasAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isRead});

  final String label;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isRead
        ? scheme.onSurface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
          )
        : const Color(0xFFF1592A).withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
          );
    final foreground = isRead
        ? scheme.onSurface.withValues(alpha: 0.82)
        : const Color(0xFFF1592A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

Future<void> showNotificationDetails(
  BuildContext context,
  AppNotification notification, {
  Future<void> Function(AppNotification notification)? onMarkRead,
}) async {
  var effectiveNotification = notification;

  if (!notification.isRead && onMarkRead != null) {
    effectiveNotification = notification.copyWith(
      isRead: true,
      readAt: notification.readAt ?? DateTime.now(),
    );
    unawaited(onMarkRead(effectiveNotification));
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) =>
        NotificationDetailsSheet(notification: effectiveNotification),
  );
}

Future<void> showNotificationDetailsSheet(
  BuildContext context,
  AppNotification notification, {
  Future<void> Function(AppNotification notification)? onMarkRead,
}) {
  return showNotificationDetails(context, notification, onMarkRead: onMarkRead);
}
