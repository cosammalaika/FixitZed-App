import 'package:meta/meta.dart';

import 'user_summary.dart';

@immutable
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.user,
    required this.categories,
    required this.services,
    required this.fixers,
    required this.hasUnreadNotifications,
    required this.fetchedAt,
  });

  final UserSummary? user;
  final List<dynamic> categories;
  final List<dynamic> services;
  final List<dynamic> fixers;
  final bool hasUnreadNotifications;
  final DateTime fetchedAt;

  DashboardSnapshot copyWith({
    UserSummary? user,
    List<dynamic>? categories,
    List<dynamic>? services,
    List<dynamic>? fixers,
    bool? hasUnreadNotifications,
    DateTime? fetchedAt,
  }) {
    return DashboardSnapshot(
      user: user ?? this.user,
      categories: categories ?? this.categories,
      services: services ?? this.services,
      fixers: fixers ?? this.fixers,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
