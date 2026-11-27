import 'package:flutter/material.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

/// How an in-app message is drawn. Pass your own colors to match your app.
class InAppStyle {
  const InAppStyle({
    this.background,
    this.text,
    this.muted,
    this.button,
    this.buttonText,
    this.radius = 20,
  });

  final Color? background;
  final Color? text;
  final Color? muted;
  final Color? button;
  final Color? buttonText;
  final double radius;
}

class InAppCard extends StatelessWidget {
  const InAppCard({
    super.key,
    required this.message,
    required this.style,
    required this.onAction,
    required this.onClose,
  });

  final InAppMessage message;
  final InAppStyle style;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final modal = message.layout == InAppLayout.modal;
    final text = style.text ?? scheme.onSurface;
    final muted = style.muted ?? scheme.onSurfaceVariant;
    final label = message.buttonLabel;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message.title,
      child: Material(
        key: Key('ft-in-app-${message.id}'),
        color: style.background ?? scheme.surfaceContainerHigh,
        elevation: 12,
        borderRadius: BorderRadius.circular(modal ? style.radius : 14),
        child: Padding(
          padding: EdgeInsets.all(modal ? 20 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: modal
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.title,
                      textAlign: modal ? TextAlign.center : TextAlign.start,
                      style:
                          (modal
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(color: text),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).closeButtonLabel,
                    child: IconButton(
                      key: const Key('ft-in-app-close'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: muted),
                      onPressed: onClose,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.body,
                textAlign: modal ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              if (label != null && label.isNotEmpty) ...[
                SizedBox(height: modal ? 18 : 10),
                FilledButton(
                  key: const Key('ft-in-app-action'),
                  style: FilledButton.styleFrom(
                    backgroundColor: style.button,
                    foregroundColor: style.buttonText,
                  ),
                  onPressed: onAction,
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
