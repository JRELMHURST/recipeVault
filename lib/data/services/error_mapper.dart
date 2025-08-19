import 'package:cloud_functions/cloud_functions.dart';

String mapBackendError(Object e) {
  final err = e is FirebaseFunctionsException ? e : null;
  final code = err?.code ?? '';
  final msg = (err?.message ?? '').toString();

  if (code == 'permission-denied' && msg.contains('SUB_REQUIRED')) {
    return 'A subscription is required.';
  }
  if (code == 'resource-exhausted' && msg.contains('RECIPES_LIMIT')) {
    return 'You’ve reached this month’s recipe limit.';
  }
  if (code == 'resource-exhausted' && msg.contains('TRANS_LIMIT')) {
    return 'You’ve reached this month’s translation limit.';
  }
  if (code == 'resource-exhausted' && msg.contains('IMAGES_LIMIT')) {
    return 'You’ve reached this month’s image limit.';
  }
  return 'Something went wrong. Please try again.';
}
