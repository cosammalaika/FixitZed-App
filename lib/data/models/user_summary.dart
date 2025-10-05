import 'package:meta/meta.dart';

@immutable
class UserSummary {
  const UserSummary({
    required this.displayName,
    required this.location,
    required this.avatarUrl,
    required this.raw,
  });

  final String displayName;
  final String location;
  final String? avatarUrl;
  final Map<String, dynamic>? raw;

  UserSummary copyWith({
    String? displayName,
    String? location,
    String? avatarUrl,
    Map<String, dynamic>? raw,
  }) {
    return UserSummary(
      displayName: displayName ?? this.displayName,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      raw: raw ?? this.raw,
    );
  }
}
