import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/state/service_providers.dart';

class ProfileState {
  const ProfileState({
    this.name = '',
    this.email = '',
    this.avatarUrl,
    this.isFixer = false,
    this.location = '',
    this.phone = '',
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final bool isFixer;
  final String location;
  final String phone;
  ProfileState copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    bool? isFixer,
    String? location,
    String? phone,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFixer: isFixer ?? this.isFixer,
      location: location ?? this.location,
      phone: phone ?? this.phone,
    );
  }
}

class ProfileController extends AutoDisposeAsyncNotifier<ProfileState> {
  @override
  FutureOr<ProfileState> build() {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue<ProfileState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }

  Future<ProfileState> _fetch() async {
    final homeService = ref.read(homeServiceProvider);
    final me = await homeService.fetchMe();
    final raw = _extractUserMap(me);
    return ProfileState(
      name: _resolveName(raw),
      email: (raw['email'] ?? '').toString(),
      avatarUrl: _resolveAvatar(raw),
      isFixer: _resolveIsFixer(raw),
      location: _resolveLocation(raw),
      phone: _resolvePhone(raw),
    );
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
        (raw['profile_photo_path'] ??
                raw['avatar'] ??
                raw['photo'] ??
                raw['profile_photo_url'] ??
                raw['profile_image'] ??
                raw['image'])
            ?.toString();
    final resolved = Api.resolveImageUrl(rawAvatar);
    return resolved.isEmpty ? null : resolved;
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
}

final profileControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProfileController, ProfileState>(
      ProfileController.new,
    );
