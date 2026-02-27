import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class ProfileState {
  const ProfileState({
    this.name = '',
    this.email = '',
    this.avatarUrl,
    this.rawProfilePhotoPath,
    this.rawProfilePhotoUrl,
    this.rawAvatarUrl,
    this.avatarVersionToken,
    this.isFixer = false,
    this.location = '',
    this.phone = '',
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final String? rawProfilePhotoPath;
  final String? rawProfilePhotoUrl;
  final String? rawAvatarUrl;
  final String? avatarVersionToken;
  final bool isFixer;
  final String location;
  final String phone;
  ProfileState copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? rawProfilePhotoPath,
    String? rawProfilePhotoUrl,
    String? rawAvatarUrl,
    String? avatarVersionToken,
    bool? isFixer,
    String? location,
    String? phone,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rawProfilePhotoPath: rawProfilePhotoPath ?? this.rawProfilePhotoPath,
      rawProfilePhotoUrl: rawProfilePhotoUrl ?? this.rawProfilePhotoUrl,
      rawAvatarUrl: rawAvatarUrl ?? this.rawAvatarUrl,
      avatarVersionToken: avatarVersionToken ?? this.avatarVersionToken,
      isFixer: isFixer ?? this.isFixer,
      location: location ?? this.location,
      phone: phone ?? this.phone,
    );
  }
}

class ProfileController extends AutoDisposeAsyncNotifier<ProfileState> {
  bool _syncRegistered = false;

  @override
  FutureOr<ProfileState> build() {
    _registerSync();
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue<ProfileState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetch(forceRefresh: true));
  }

  Future<ProfileState> _fetch({bool forceRefresh = false}) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final me = await profileRepo.getProfile(forceRefresh: forceRefresh);
    final raw = _extractUserMap(me);
    final resolvedAvatar = _resolveAvatar(raw);
    final state = ProfileState(
      name: _resolveName(raw),
      email: (raw['email'] ?? '').toString(),
      avatarUrl: resolvedAvatar,
      rawProfilePhotoPath: _normalizeNullableString(
        raw['profile_photo_path'] ?? raw['profilePhotoPath'],
      ),
      rawProfilePhotoUrl: _normalizeNullableString(
        raw['profile_photo_url'] ?? raw['profilePhotoUrl'],
      ),
      rawAvatarUrl: _normalizeNullableString(raw['avatar_url'] ?? raw['avatarUrl']),
      avatarVersionToken: _normalizeNullableString(_resolveAvatarVersionToken(raw)),
      isFixer: _resolveIsFixer(raw),
      location: _resolveLocation(raw),
      phone: _resolvePhone(raw),
    );
    _logAvatarDebugFields(state);
    return state;
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic>? me) {
    if (me == null) return <String, dynamic>{};
    final user = me['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    return Map<String, dynamic>.from(me);
  }

  String _resolveName(Map<String, dynamic> raw) {
    final first =
        (raw['first_name'] ?? raw['firstname'] ?? raw['firstName'] ?? '')
            .toString()
            .trim();
    final last = (raw['last_name'] ?? raw['lastname'] ?? raw['lastName'] ?? '')
        .toString()
        .trim();
    final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;

    return (raw['name'] ?? raw['full_name'] ?? raw['username'] ?? '')
        .toString()
        .trim();
  }

  String _resolveLocation(Map<String, dynamic> raw) {
    final address =
        (raw['address'] ?? raw['location'] ?? '').toString().trim();
    if (address.isNotEmpty) return address;

    final province = (raw['province'] ?? raw['province_name'] ?? '')
        .toString()
        .trim();
    final district =
        (raw['district'] ?? raw['district_name'] ?? '').toString().trim();
    final parts = [province, district].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.join(', ');
  }

  String _resolvePhone(Map<String, dynamic> raw) {
    return (raw['contact_number'] ?? raw['phone'] ?? raw['mobile'] ?? '')
        .toString()
        .trim();
  }

  String? _resolveAvatar(Map<String, dynamic> raw) {
    final rawAvatar =
        (raw['avatar_url'] ??
                raw['avatarUrl'] ??
                raw['profile_photo_path'] ??
                raw['avatar'] ??
                raw['photo'] ??
                raw['profile_photo_url'] ??
                raw['profile_image'] ??
                raw['image'])
            ?.toString();
    final resolved = Api.resolveImageUrl(rawAvatar);
    if (resolved.isEmpty) return null;

    final versionToken = _resolveAvatarVersionToken(raw);
    if (versionToken.isEmpty) return resolved;
    return Api.withCacheBust(resolved, versionToken);
  }

  String _resolveAvatarVersionToken(Map<String, dynamic> raw) {
    const keys = [
      'avatar_updated_at',
      'avatarUpdatedAt',
      'profile_photo_updated_at',
      'profilePhotoUpdatedAt',
      'updated_at',
      'updatedAt',
    ];

    for (final key in keys) {
      final value = raw[key];
      if (value == null) continue;
      final token = value.toString().trim();
      if (token.isEmpty || token.toLowerCase() == 'null') continue;
      return token;
    }

    return '';
  }

  String? _normalizeNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  void _logAvatarDebugFields(ProfileState state) {
    if (!kDebugMode) return;
    debugPrint(
      '[ProfileController.avatar] '
      'profile_photo_path=${state.rawProfilePhotoPath} '
      'profile_photo_url=${state.rawProfilePhotoUrl} '
      'avatar_url=${state.rawAvatarUrl} '
      'resolved=${state.avatarUrl} '
      'version=${state.avatarVersionToken}',
    );
  }

  bool _resolveIsFixer(Map<String, dynamic> raw) {
    var fixer = false;
    final dynamic isFixerFlag = raw['is_fixer'] ?? raw['fixer'];
    if (isFixerFlag is bool) fixer = isFixerFlag;
    if (isFixerFlag is num) fixer = isFixerFlag != 0;
    if (isFixerFlag is String) {
      final v = isFixerFlag.trim().toLowerCase();
      fixer = v == '1' || v == 'true' || v == 'yes';
    }

    var roleStr =
        (raw['role'] ??
                raw['user_type'] ??
                raw['type'] ??
                raw['account_type'] ??
                '')
            .toString()
            .toLowerCase();
    if (roleStr.contains('fixer') || roleStr.contains('provider')) fixer = true;

    final roles = raw['roles'];
    if (roles is List) {
      for (final r in roles) {
        final s = r.toString().toLowerCase();
        if (s.contains('fixer') || s == 'provider') {
          fixer = true;
          break;
        }
      }
    }

    if (raw['fixer_profile'] != null) fixer = true;
    return fixer;
  }

  void _registerSync() {
    if (_syncRegistered) return;
    _syncRegistered = true;

    Future<void> handle(AppSyncEvent _) => refresh();

    ref.onAppSync(AppSyncTopic.profile, handle);
    ref.onAppSync(AppSyncTopic.dashboard, handle);
  }
}

final profileControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProfileController, ProfileState>(
      ProfileController.new,
    );
