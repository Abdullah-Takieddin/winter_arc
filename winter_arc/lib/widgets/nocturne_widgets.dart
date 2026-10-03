import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nocturne.dart';

/// `.btn` variants. The primary is an accent outline, never a fill.
enum NocButtonVariant { primary, secondary, ghost }

class NocButton extends StatelessWidget {
  const NocButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.variant = NocButtonVariant.primary,
    this.block = false,
    this.iconOnlySize = 36,
    this.height,
    this.fontSize = 14,
    this.iconSize,
    this.tooltip,
  }) : assert(label != null || icon != null);

  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final NocButtonVariant variant;
  final bool block;

  /// Edge length of an icon-only button (`.btn-icon`, 36 px by default).
  final double iconOnlySize;
  final double? height;
  final double fontSize;
  final double? iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final iconOnly = label == null;
    final (fg, edge, hover, press) = switch (variant) {
      NocButtonVariant.primary => (Noc.accent, Noc.accent, Noc.accentMix(.12), Noc.accentMix(.22)),
      NocButtonVariant.secondary => (Noc.text, Noc.divider, Noc.textMix(.07), Noc.textMix(.14)),
      NocButtonVariant.ghost => (Noc.accent, Colors.transparent, Noc.accentMix(.10), Noc.accentMix(.18)),
    };
    final style = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(fg),
      overlayColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return press;
        if (s.contains(WidgetState.hovered)) return hover;
        return Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? const BorderSide(color: Noc.accent, width: 2)
            : BorderSide(color: edge),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Noc.radiusMd))),
      ),
      padding: WidgetStatePropertyAll(
        iconOnly
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: variant == NocButtonVariant.ghost ? Noc.space1 : Noc.space3 * 1.2,
                vertical: Noc.space2,
              ),
      ),
      minimumSize: WidgetStatePropertyAll(
        iconOnly ? Size.square(iconOnlySize) : Size(block ? double.infinity : 0, height ?? 0),
      ),
      fixedSize: iconOnly ? WidgetStatePropertyAll(Size.square(iconOnlySize)) : null,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: fontSize, height: 1.2),
      ),
    );
    final glyph = icon == null ? null : Icon(icon, size: iconSize ?? fontSize);
    Widget child = iconOnly
        ? glyph!
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[glyph, const SizedBox(width: 6)],
              Text(label!),
            ],
          );
    Widget button = TextButton(onPressed: onPressed, style: style, child: child);
    if (onPressed == null) button = Opacity(opacity: .45, child: button);
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// `.card` — a surface-filled block.
class NocCard extends StatelessWidget {
  const NocCard({super.key, required this.child, this.padding = 16, this.onTap});

  final Widget child;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: EdgeInsets.all(padding), child: child);
    return Material(
      color: Noc.surface,
      borderRadius: BorderRadius.circular(Noc.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              hoverColor: Noc.textMix(.04),
              highlightColor: Noc.textMix(.06),
              splashFactory: NoSplash.splashFactory,
              child: body,
            ),
    );
  }
}

enum NocTagVariant { accent, neutral, outline }

/// `.tag` — a small tinted label.
class NocTag extends StatelessWidget {
  const NocTag(this.label, {super.key, this.icon, this.variant = NocTagVariant.accent, this.onTap});

  final String label;
  final IconData? icon;
  final NocTagVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      NocTagVariant.accent => (Noc.accent800, Noc.accent100, null),
      NocTagVariant.neutral => (Noc.neutral800, Noc.neutral100, null),
      NocTagVariant.outline => (Colors.transparent, Noc.accent, Border.all(color: Noc.accent)),
    };
    final radius = BorderRadius.circular(Noc.radiusMd * .75);
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: radius, border: border),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(fontSize: 11, letterSpacing: 11 * .02, color: fg, height: 1.55),
          ),
        ],
      ),
    );
    if (onTap == null) return tag;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, borderRadius: radius, splashFactory: NoSplash.splashFactory, child: tag),
    );
  }
}

/// The 64 px progress ring from the Heute cards (r 27, stroke 5, round cap,
/// starting at 12 o'clock).
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 64});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => CustomPaint(size: Size.square(size), painter: _RingPainter(v)),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 27 * scale);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale;
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke..color = Noc.neutral800);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        stroke
          ..color = Noc.accent
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// `.seg` + `.seg-opt` — the segmented switch. The active option takes the
/// accent text and a 1 px inset accent outline.
class NocSegmented<T> extends StatelessWidget {
  const NocSegmented({super.key, required this.options, required this.selected, required this.onChanged});

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Noc.divider),
        borderRadius: BorderRadius.circular(Noc.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: Noc.divider),
              _segOption(entries[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segOption(MapEntry<T, String> e) {
    final on = e.key == selected;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: () => onChanged(e.key),
        hoverColor: on ? Colors.transparent : Noc.textMix(.07),
        splashFactory: NoSplash.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: on ? BoxDecoration(border: Border.all(color: Noc.accent)) : null,
          child: Text(e.value, style: TextStyle(fontSize: 13, color: on ? Noc.accent : Noc.text)),
        ),
      ),
    );
  }
}

/// A 1 px rule that fades to transparent over 48 px at each end — the
/// Nocturne signature for freestanding rules.
class FadingRule extends StatelessWidget {
  const FadingRule({super.key, this.color = Noc.divider});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final w = c.maxWidth;
      final f = w > 96 ? 48 / w : .5;
      return Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
            stops: [0, f, 1 - f, 1],
          ),
        ),
      );
    },
  );
}

/// The screen header: uppercase kicker, large title, optional aside text and
/// a trailing action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.kicker, required this.title, this.aside, this.trailing});

  final String kicker;
  final String title;
  final String? aside;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker.toUpperCase(), style: NocText.kicker),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title, style: NocText.title),
                if (aside != null) ...[const SizedBox(width: 10), Text(aside!, style: NocText.titleAside)],
              ],
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// `.dialog` over `.dialog-backdrop`.
Future<T?> showNocDialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required List<Widget> actions,
}) => showDialog<T>(
  context: context,
  barrierColor: Noc.neutral900.withValues(alpha: .5),
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(16),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(Noc.space4 * 1.6),
      decoration: BoxDecoration(
        color: Noc.surface,
        borderRadius: BorderRadius.circular(Noc.radiusLg),
        boxShadow: Noc.shadowLg,
      ),
      // Scrolls when the keyboard leaves too little room for a form.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: Noc.space3 * 1.5),
            DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: body),
            // A body that renders its own (stateful) buttons passes no actions.
            if (actions.isNotEmpty) ...[const SizedBox(height: Noc.space3 * 2), NocActions(actions)],
          ],
        ),
      ),
    ),
  ),
);

/// The right-aligned button row at the foot of a dialog.
class NocActions extends StatelessWidget {
  const NocActions(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(alignment: WrapAlignment.end, spacing: Noc.space2, runSpacing: Noc.space2, children: children);
}

/// `.field` + `.input` — a labelled text field on the surface.
class NocInput extends StatelessWidget {
  const NocInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder edge(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Noc.radiusMd),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Noc.textMix(.7))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: !obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Noc.text),
          cursorColor: Noc.accent,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Noc.neutral600),
            filled: true,
            fillColor: Noc.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: edge(Noc.divider),
            enabledBorder: edge(Noc.divider),
            disabledBorder: edge(Noc.divider),
            focusedBorder: edge(Noc.accent),
          ),
        ),
      ],
    );
  }
}
