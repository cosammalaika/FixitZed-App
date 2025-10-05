import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_summary.dart';
import '../data/repositories/user_repository.dart';
import 'repository_providers.dart';
import '../core/api.dart';

class UserController extends StateNotifier<AsyncValue<UserSummary?>> {
  UserController(this._repo)
      : super(const AsyncValue<UserSummary?>.loading()) {
    refresh();
  }

  final UserRepository _repo;

  Future<void> refresh() async {
    state = const AsyncValue<UserSummary?>.loading();
    final result = await AsyncValue.guard<UserSummary?>(() async {
      final raw = await _repo.fetchCurrentUser();
      if (raw == null) return null;
      final displayName = _extractDisplayName(raw);
      final location = _extractLocation(raw);
      final avatarRaw =
          (raw['profile_photo_path'] ??
                  raw['avatar_url'] ??
                  raw['avatar'] ??
                  raw['profile_photo_url'] ??
                  raw['photo'] ??
                  raw['image'])
              ?.toString();
      final avatar = Api.resolveImageUrl(avatarRaw);
      return UserSummary(
        displayName: displayName,
        location: location,
        avatarUrl: avatar.isEmpty ? null : avatar,
        raw: raw,
      );
    });
    state = result;
  }

  String _extractDisplayName(Map<String, dynamic> raw) {
    final first = (raw['first_name'] ?? raw['firstName'] ?? '')
        .toString()
        .trim();
    final last = (raw['last_name'] ?? raw['lastName'] ?? '').toString().trim();
    final explicit = (raw['name'] ?? raw['full_name'] ?? raw['username'])
        ?.toString()
        .trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'there' : combined;
  }

  String _extractLocation(Map<String, dynamic> raw) {
    final candidates = [
      raw['address'],
      raw['location'],
      raw['city'],
      raw['country'],
      raw['region'],
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    return candidates.isEmpty ? '' : candidates.first;
  }
}

final userControllerProvider =
    StateNotifierProvider<UserController, AsyncValue<UserSummary?>>((ref) {
      final repository = ref.read(userRepositoryProvider);
      final controller = UserController(repository);
      ref.onDispose(controller.dispose);
      return controller;
    });
