import 'package:fixitzed_app/services/home_service.dart';

/// Cache for categories and subcategories lists.
class CategoriesRepository {
  CategoriesRepository(this._api);

  final HomeService _api;

  List<dynamic>? _categories;
  List<dynamic>? _subcategories;
  DateTime? _categoriesFetchedAt;
  DateTime? _subcategoriesFetchedAt;
  static const _ttl = Duration(minutes: 10);

  List<dynamic>? get cachedCategories =>
      _categories == null ? null : List<dynamic>.from(_categories!);

  List<dynamic>? get cachedSubcategories =>
      _subcategories == null ? null : List<dynamic>.from(_subcategories!);

  bool _stale(DateTime? fetchedAt) {
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories != null && !_stale(_categoriesFetchedAt)) {
      return List<dynamic>.from(_categories!);
    }
    try {
      final data = await _api.fetchCategories();
      if (data.isNotEmpty) {
        _categories = List<dynamic>.from(data);
        _categoriesFetchedAt = DateTime.now();
      }
    } catch (_) {}
    return _categories == null ? <dynamic>[] : List<dynamic>.from(_categories!);
  }

  Future<List<dynamic>> getSubcategories({
    bool forceRefresh = false,
    int? categoryId,
  }) async {
    if (categoryId == null &&
        !forceRefresh &&
        _subcategories != null &&
        !_stale(_subcategoriesFetchedAt)) {
      return List<dynamic>.from(_subcategories!);
    }
    try {
      final data = await _api.fetchSubcategories(categoryId: categoryId);
      if (data.isNotEmpty && categoryId == null) {
        _subcategories = List<dynamic>.from(data);
        _subcategoriesFetchedAt = DateTime.now();
      }
      return data;
    } catch (_) {
      return _subcategories == null
          ? <dynamic>[]
          : List<dynamic>.from(_subcategories!);
    }
  }
}
