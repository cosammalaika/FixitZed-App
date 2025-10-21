import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/core/fixer_utils.dart';
import 'package:fixitzed_app/state/service_providers.dart';

final topFixersProvider = FutureProvider<List<dynamic>>((
  ref,
) async {
  final service = ref.read(homeServiceProvider);
  var list = await service.fetchAllFixers();
  if (list.isEmpty) {
    list = await service.fetchFixers();
  }
  final mapped = list
      .whereType<Map>()
      .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
      .toList();
  mapped.sort((a, b) {
    final br = fixerRating(b) ?? 0;
    final ar = fixerRating(a) ?? 0;
    return br.compareTo(ar);
  });
  const maxItems = 5;
  return mapped.length <= maxItems
      ? List<dynamic>.from(mapped)
      : List<dynamic>.from(mapped.take(maxItems));
});

final allFixersProvider = FutureProvider<List<dynamic>>((
  ref,
) async {
  final service = ref.read(homeServiceProvider);
  final list = await service.fetchAllFixers();
  return List<dynamic>.from(list);
});
