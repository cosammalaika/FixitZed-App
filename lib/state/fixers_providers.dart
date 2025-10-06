import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

final topFixersProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final service = ref.read(homeServiceProvider);
  final list = await service.fetchFixers();
  return List<dynamic>.from(list);
});

final allFixersProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final service = ref.read(homeServiceProvider);
  final list = await service.fetchAllFixers();
  return List<dynamic>.from(list);
});
