import 'package:flutter/widgets.dart';

import '../ft_engage.dart';

String? _routeName(Route<dynamic> route) => route.settings.name;

class EngageNavigatorObserver extends NavigatorObserver {
  EngageNavigatorObserver(
    this.engage, {
    String? Function(Route<dynamic>)? nameOf,
  }) : _nameOf = nameOf ?? _routeName;

  final FtEngage engage;
  final String? Function(Route<dynamic>) _nameOf;

  void _show(Route<dynamic>? route) {
    engage.navigationEpoch += 1;
    if (route == null || route is PopupRoute) return;
    final name = _nameOf(route);
    if (name != null) engage.screen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);
}
