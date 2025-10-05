import '../../services/home_service.dart';

class UserRepository {
  UserRepository(this._homeService);

  final HomeService _homeService;

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    final payload = await _homeService.fetchMe();
    if (payload == null) return null;
    if (payload['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload['user'] as Map);
    }
    return Map<String, dynamic>.from(payload);
  }
}
