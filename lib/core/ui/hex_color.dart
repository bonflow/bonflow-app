import 'package:material_ui/material_ui.dart';

/// Parses a `#RRGGBB` colour as sent by the server; null for missing or malformed values.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return null;
  }
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// Black or white, whichever is more readable on [background].
Color onColor(Color background) => background.computeLuminance() > 0.4
    ? const Color(0xFF1B1B1B)
    : const Color(0xFFFFFFFF);

/// Large touch button in the venue's colour (area, table, category); a neutral tonal button
/// when no colour is configured.
class ColoredButton extends StatelessWidget {
  const ColoredButton({
    required this.color,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final Color? color;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    if (color == null) {
      return FilledButton.tonal(onPressed: onPressed, child: child);
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: onColor(color),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
