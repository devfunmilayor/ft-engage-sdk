import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import '../ft_engage.dart';
import 'in_app_card.dart';

/// Shows in-app messages over your app.
///
/// Put it in `MaterialApp.builder` so it sits above every screen:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => EngageInApp(
///     engage: engage,
///     onAction: (uri) => router.go(uri.path),
///     child: child!,
///   ),
/// )
/// ```
///
/// A card is centred over a dimmed screen, and a banner slides in at the top.
/// Tapping the button reports `inapp.clicked` and passes the message's link
/// to [onAction]. Closing it, or tapping outside a card, reports
/// `inapp.dismissed`.
class EngageInApp extends StatefulWidget {
  const EngageInApp({
    super.key,
    required this.engage,
    required this.child,
    this.onAction,
    this.style = const InAppStyle(),
  });

  final FtEngage engage;
  final Widget child;
  final void Function(Uri link)? onAction;
  final InAppStyle style;

  @override
  State<EngageInApp> createState() => _EngageInAppState();
}

class _EngageInAppState extends State<EngageInApp> {
  StreamSubscription<InAppMessage>? _sub;
  InAppMessage? _current;

  @override
  void initState() {
    super.initState();
    _sub = widget.engage.inApp?.due.listen(_show);
  }

  void _show(InAppMessage m) {
    if (!mounted) return;
    setState(() => _current = m);
    unawaited(widget.engage.inApp?.shown(m));
  }

  void _close({required bool acted}) {
    final m = _current;
    if (m == null) return;
    setState(() => _current = null);
    final engine = widget.engage.inApp;
    if (!acted) {
      unawaited(engine?.dismissed(m));
      return;
    }
    unawaited(engine?.clicked(m));
    final link = Uri.tryParse(m.actionUrl ?? '');
    if (link != null && link.hasScheme) widget.onAction?.call(link);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _current;
    final modal = m?.layout == InAppLayout.modal;
    return Stack(
      children: [
        widget.child,
        if (m != null && modal)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('ft-in-app-barrier'),
              onTap: () => _close(acted: false),
              child: const ColoredBox(color: Color(0x8A000000)),
            ),
          ),
        if (m != null)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: modal ? Alignment.center : Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(m.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (modal ? 12 : -24) * (1 - t)),
                          child: child,
                        ),
                      ),
                      child: InAppCard(
                        message: m,
                        style: widget.style,
                        onAction: () => _close(acted: true),
                        onClose: () => _close(acted: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
