import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/state/service_providers.dart';

final allFixersProvider = FutureProvider<List<dynamic>>((
  ref,
) async {
  final service = ref.read(homeServiceProvider);
  final list = await service.fetchAllFixers();
  return List<dynamic>.from(list);
});
