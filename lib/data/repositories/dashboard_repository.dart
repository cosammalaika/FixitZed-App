import '../../core/api.dart';
import '../../services/home_service.dart';
import '../../services/notification_service.dart';
import '../models/dashboard_snapshot.dart';
import '../models/user_summary.dart';

class DashboardRepository {
  DashboardRepository(this._homeService, this._notifications);

  final HomeService _homeService;
  final NotificationService _notifications;

  Future<DashboardSnapshot> fetchDashboard({int fixerLimit = 10}) async {
    final results = await Future.wait([
      _homeService.fetchMe(),
      _homeService.fetchCategories(),
      _homeService.fetchServices(),
      _homeService.fetchFixers(limit: fixerLimit),
      _notifications.fetch(page: 1),
    ]);

    final meRaw = results[0] as Map<String, dynamic>?;
    final categories = (results[1] as List<dynamic>?) ?? const [];
    final services = (results[2] as List<dynamic>?) ?? const [];
    final fixers = (results[3] as List<dynamic>?) ?? const [];
    final notifications =
        (results[4] as List<Map<String, dynamic>>?) ?? const [];

    final userSummary = _userFromPayload(meRaw);
    final hasUnread = notifications.any(_isUnreadNotification);

    return DashboardSnapshot(
      user: userSummary,
      categories: categories,
      services: services,
      fixers: fixers,
      hasUnreadNotifications: hasUnread,
      fetchedAt: DateTime.now(),
    );
  }

  UserSummary? _userFromPayload(Map<String, dynamic>? envelope) {
    if (envelope == null) return null;
    Map<String, dynamic>? raw;
    if (envelope['user'] is Map<String, dynamic>) {
      raw = Map<String, dynamic>.from(envelope['user'] as Map);
    } else if (envelope['data'] is Map<String, dynamic>) {
      raw = Map<String, dynamic>.from(envelope['data'] as Map);
    } else {
      raw = Map<String, dynamic>.from(envelope);
    }

    final first = (raw['first_name'] ?? raw['firstName'] ?? '')
        .toString()
        .trim();
    final last = (raw['last_name'] ?? raw['lastName'] ?? '').toString().trim();
    final explicitName = (raw['name'] ?? raw['full_name'] ?? raw['username'])
        ?.toString()
        .trim();

    final displayName = explicitName?.isNotEmpty == true
        ? explicitName!
        : [first, last].where((p) => p.isNotEmpty).join(' ');

    final addressCandidates = [
      raw['address'],
      raw['location'],
      raw['city'],
      raw['country'],
      raw['region'],
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);

    final location = addressCandidates.isEmpty ? '' : addressCandidates.first;

    final avatarRaw =
        (raw['profile_photo_path'] ??
                raw['avatar_url'] ??
                raw['avatar'] ??
                raw['profile_photo_url'] ??
                raw['photo'] ??
                raw['image'])
            ?.toString();
    final avatarUrl = Api.resolveImageUrl(avatarRaw);

    return UserSummary(
      displayName: displayName,
      location: location,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      raw: raw,
    );
  }

  bool _isUnreadNotification(Map<String, dynamic> notification) {
    final readVal =
        notification['read'] ??
        notification['is_read'] ??
        notification['read_at'] ??
        notification['readAt'] ??
        notification['readAtFormatted'];

    if (readVal == null) return true;
    if (readVal is bool) return !readVal;
    if (readVal is num) return readVal == 0;
    final value = readVal.toString().trim().toLowerCase();
    if (value.isEmpty) return true;
    return value == '0' ||
        value == 'false' ||
        value == 'pending' ||
        value == 'null';
  }
}
