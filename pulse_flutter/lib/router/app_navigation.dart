import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Pushes [location] through the app router.
///
/// Without a router above [context], e.g. in a widget test that pumps a
/// single screen, [fallback] is pushed as a plain route instead.
Future<T?> pushAppRoute<T extends Object?>(
  BuildContext context,
  String location, {
  required WidgetBuilder fallback,
}) {
  if (GoRouter.maybeOf(context) != null) return context.push<T>(location);
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: fallback));
}
