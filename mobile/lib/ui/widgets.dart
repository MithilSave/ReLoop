import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/nav.dart';
import '../core/query.dart';
import 'states.dart';
import 'theme.dart';

export 'states.dart';
export 'theme.dart';

/* ───────────── Tones, badges, tags ───────────── */

enum Tone { ok, warn, bad, info, neutral }

(Color fg, Color bg) toneColors(BuildContext context, Tone t) {
  final c = context.c;
  switch (t) {
    case Tone.ok:
      return (c.ok, c.okBg);
    case Tone.warn:
      return (c.warn, c.warnBg);
    case Tone.bad:
      return (c.bad, c.badBg);
    case Tone.info:
      return (c.info, c.infoBg);
    case Tone.neutral:
      return (c.fg2, c.neuBg);
  }
}

/// Status badge (the web app's `Badge`).
class Pill extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool dot;
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.dot = true});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = toneColors(context, tone);
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg.withValues(alpha: 0.85), shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: fg), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;
  const TagChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: c.fg2)),
    );
  }
}

const Map<String, (Tone, String)> kBatchStatus = {
  'LISTED': (Tone.info, 'Listed'),
  'ASSIGNED': (Tone.warn, 'Assigned'),
  'PICKED_UP': (Tone.warn, 'Picked up'),
  'IN_TRANSIT': (Tone.warn, 'In transit'),
  'RECEIVED': (Tone.ok, 'Received'),
  'REJECTED_AT_RECEIPT': (Tone.bad, 'Rejected at receipt'),
  'PROCESSED': (Tone.ok, 'Processed'),
  'CANCELLED': (Tone.neutral, 'Cancelled'),
};
final List<(String, String)> kBatchStatusOptions = kBatchStatus.entries.map((e) => (e.key, e.value.$2)).toList();

const Map<String, (Tone, String)> kNgo = {
  'PENDING': (Tone.info, 'Pending review'),
  'UNDER_REVIEW': (Tone.warn, 'Under review'),
  'VERIFIED': (Tone.ok, 'Verified'),
  'FLAGGED': (Tone.bad, 'Flagged'),
  'REJECTED': (Tone.bad, 'Rejected'),
  'REQUIRES_CORRECTION': (Tone.warn, 'Correction requested'),
};
final List<(String, String)> kNgoOptions = kNgo.entries.map((e) => (e.key, e.value.$2)).toList();

const Map<String, (Tone, String)> kConsStatus = {
  'IN_TRANSIT': (Tone.info, 'In transit'),
  'ARRIVED': (Tone.warn, 'At recycler · awaiting receipt'),
  'RECEIVED': (Tone.ok, 'Received'),
};

const Map<String, (Tone, String)> kPlanStatus = {
  'PROPOSED': (Tone.info, 'Proposed'),
  'ACCEPTED': (Tone.warn, 'Accepted by one party'),
  'ACTIVE': (Tone.ok, 'Active'),
  'CANCELLED': (Tone.neutral, 'Cancelled'),
  'COMPLETED': (Tone.ok, 'Completed'),
};

class StatusPill extends StatelessWidget {
  final String? status;
  final Map<String, (Tone, String)> map;
  const StatusPill(this.status, this.map, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = map[status];
    return Pill(e?.$2 ?? humanize(status), tone: e?.$1 ?? Tone.neutral);
  }
}

class BatchStatusPill extends StatelessWidget {
  final String? status;
  const BatchStatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) => StatusPill(status, kBatchStatus);
}

class NgoPill extends StatelessWidget {
  final String? decision;
  const NgoPill(this.decision, {super.key});

  @override
  Widget build(BuildContext context) {
    if (decision == null || decision!.isEmpty) return Text('Not in review', style: TextStyle(fontSize: 12, color: context.c.fg3));
    return StatusPill(decision, kNgo);
  }
}

/* ───────────── Text helpers ───────────── */

TextStyle mono(BuildContext context, {double size = 12.5, Color? color, FontWeight? weight}) =>
    TextStyle(fontFamily: kMono, fontFamilyFallback: kMonoFallback, fontSize: size, color: color ?? context.c.fg, fontWeight: weight);

class Mono extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final FontWeight? weight;
  const Mono(this.text, {super.key, this.size = 12.5, this.color, this.weight});
  @override
  Widget build(BuildContext context) => Text(text, style: mono(context, size: size, color: color, weight: weight));
}

class Small extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;
  final FontWeight? weight;
  const Small(this.text, {super.key, this.color, this.size = 12, this.weight});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: size, color: color ?? context.c.fg3, fontWeight: weight));
}

/// "RL-MUM-2026-000123" shown as "…000123"; tapping opens the material passport.
class BatchLink extends StatelessWidget {
  final String code;
  final bool full;
  const BatchLink(this.code, {super.key, this.full = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: code,
      child: InkWell(
        onTap: () => openPassport(code),
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(full ? code : shortCode(code),
              style: mono(context, size: 12.5, color: context.c.accent).copyWith(decoration: TextDecoration.underline, decorationColor: context.c.accent.withValues(alpha: 0.4))),
        ),
      ),
    );
  }
}

/// Inline link-style action inside a sentence.
class LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const LinkText(this.text, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: context.c.accent, decoration: TextDecoration.underline, fontSize: 12.5)),
      );
}

/* ───────────── Notes ───────────── */

class Note extends StatelessWidget {
  final String? title;
  final String? text;
  final Widget? child;
  final Tone tone;
  const Note({super.key, this.title, this.text, this.child, this.tone = Tone.info});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color bg, Color border, IconData icon, Color ic) = switch (tone) {
      Tone.warn => (c.warnBg, Colors.transparent, Icons.warning_amber_rounded, c.warn),
      Tone.bad => (c.badBg, Colors.transparent, Icons.cancel_outlined, c.bad),
      Tone.ok => (c.okBg, Colors.transparent, Icons.check_circle_outline, c.ok),
      _ => (c.surface2, c.line, Icons.info_outline, c.fg3),
    };
    return Semantics(
      liveRegion: tone == Tone.bad,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: ic)),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.fg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title != null) Text(title!, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (text != null) Text(text!),
                if (child != null) child!,
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/* ───────────── Page layout ───────────── */

class PageHeader extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.description, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: context.phone ? 18 : 21, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
      if (description != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Text(description!, style: TextStyle(fontSize: 13.5, color: c.fg2))),
        ),
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 12,
        children: [
          head,
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

class SourceLine extends StatelessWidget {
  final String source;
  final String? period;
  const SourceLine(this.source, {super.key, this.period});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.info_outline, size: 14, color: c.fg3),
      const SizedBox(width: 6),
      Flexible(child: Text('Source: $source${period != null ? ' · Period: $period' : ''}', style: TextStyle(fontSize: 11.5, color: c.fg3))),
    ]);
  }
}

/// Vertical stack with consistent gaps (the web app's `flex flex-col gap-4`).
class Gap extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment cross;
  const Gap(this.children, {super.key, this.gap = 16, this.cross = CrossAxisAlignment.stretch});

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (final w in children) {
      if (out.isNotEmpty) out.add(SizedBox(height: gap));
      out.add(w);
    }
    return Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: out);
  }
}

/// Responsive grid: as many columns of at least [minWidth] as fit, capped at [maxCols].
class RGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final int maxCols;
  final double gap;
  const RGrid({super.key, required this.children, this.minWidth = 260, this.maxCols = 4, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final cols = ((w + gap) / (minWidth + gap)).floor().clamp(1, maxCols);
      final cw = (w - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: cw, child: ch)]);
    });
  }
}

/// KPI tiles: 2 per row on phones, up to [cols] on wider screens.
class KpiGrid extends StatelessWidget {
  final List<Widget> children;
  final int cols;
  const KpiGrid(this.children, {super.key, this.cols = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final n = w >= 900 ? cols : (w >= 560 ? (cols > 3 ? 3 : cols) : 2);
      const gap = 12.0;
      final cw = (w - gap * (n - 1)) / n;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: cw, child: ch)]);
    });
  }
}

/// Two columns on wide screens (main + side), stacked on narrow ones.
class TwoCol extends StatelessWidget {
  final Widget main;
  final Widget side;
  final int mainFlex;
  final int sideFlex;
  final double breakpoint;
  const TwoCol({super.key, required this.main, required this.side, this.mainFlex = 2, this.sideFlex = 1, this.breakpoint = 900});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < breakpoint) return Gap([main, side]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: mainFlex, child: main),
        const SizedBox(width: 16),
        Expanded(flex: sideFlex, child: side),
      ]);
    });
  }
}

class Panel extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? sub;
  final List<Widget> actions;
  final Widget? footer;
  final bool flush;
  final Widget child;
  const Panel({super.key, this.title, this.titleWidget, this.sub, this.actions = const [], this.footer, this.flush = false, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasHead = title != null || titleWidget != null || actions.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (hasHead)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (titleWidget != null) titleWidget! else if (title != null) Text(title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (sub != null) Text(sub!, style: TextStyle(fontSize: 12, color: c.fg3)),
                ]),
                if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
              ],
            ),
          ),
        Padding(padding: flush ? EdgeInsets.zero : const EdgeInsets.all(16), child: child),
        if (footer != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: DefaultTextStyle.merge(style: TextStyle(fontSize: 12, color: c.fg3), child: footer!),
          ),
      ]),
    );
  }
}

/// Footer content with a source line and an optional note.
class Foot extends StatelessWidget {
  final String source;
  final String? note;
  final String? period;
  const Foot(this.source, {super.key, this.note, this.period});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.spaceBetween, children: [
        SourceLine(source, period: period),
        if (note != null) Text(note!, style: TextStyle(fontSize: 12, color: context.c.fg3)),
      ]);
}

class Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Widget? subWidget;
  final IconData? icon;
  const Kpi({super.key, required this.label, required this.value, this.sub, this.subWidget, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c.fg2), const SizedBox(width: 6)],
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.fg2), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: context.phone ? 18 : 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        if (subWidget != null) Padding(padding: const EdgeInsets.only(top: 2), child: subWidget!),
        if (sub != null && subWidget == null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 12, color: c.fg3))),
      ]),
    );
  }
}

/// One key/value row. [v] may be a String or a Widget. [total] draws a rule above and bolds the row.
class KVRow {
  final String k;
  final Object? v;
  final bool total;
  const KVRow(this.k, this.v, {this.total = false});
}

class KV extends StatelessWidget {
  final List<KVRow> rows;
  const KV(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (final r in rows)
        Container(
          margin: EdgeInsets.only(top: r.total ? 4 : 0),
          padding: EdgeInsets.only(top: r.total ? 6 : 3, bottom: 3),
          decoration: r.total ? BoxDecoration(border: Border(top: BorderSide(color: c.line))) : null,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(r.k, style: TextStyle(fontSize: 13, color: r.total ? c.fg : c.fg2, fontWeight: r.total ? FontWeight.w600 : null))),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: r.v is Widget
                    ? r.v as Widget
                    : Text('${r.v ?? '—'}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, fontWeight: r.total ? FontWeight.w600 : FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/* ───────────── Buttons ───────────── */

enum BtnKind { primary, outline, ghost, destructive }

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool loading;
  final bool small;
  final bool large;
  final String? tooltip;
  const Btn(this.label,
      {super.key, this.onPressed, this.icon, this.kind = BtnKind.primary, this.loading = false, this.small = false, this.large = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;
    final h = small ? 32.0 : (large ? 46.0 : 38.0);
    final (Color bg, Color fg, Color? border) = switch (kind) {
      BtnKind.primary => (c.brand, c.brandFg, null),
      BtnKind.destructive => (c.bad, Colors.white, null),
      BtnKind.outline => (c.surface, c.fg, c.line2),
      BtnKind.ghost => (Colors.transparent, c.fg, null),
    };
    final content = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (loading)
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
      else if (icon != null)
        Icon(icon, size: small ? 15 : 16, color: fg),
      if (loading || icon != null) const SizedBox(width: 7),
      // No Flexible here: buttons sit in Rows with unbounded width and in intrinsic-width table cells.
      Text(label, maxLines: 1, style: TextStyle(fontSize: small ? 12.5 : 13.5, fontWeight: FontWeight.w500, color: fg)),
    ]);
    final btn = Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: border != null ? BorderSide(color: border) : BorderSide.none),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14), child: Center(widthFactor: 1, child: content)),
          ),
        ),
      ),
    );
    return Semantics(button: true, enabled: enabled, label: label, child: tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn);
  }
}

/* ───────────── Form fields ───────────── */

class Field extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final String? error;
  final Widget child;
  const Field({super.key, required this.label, this.required = false, this.hint, this.error, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label),
        if (required) TextSpan(text: ' *', style: TextStyle(color: c.bad)),
      ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.fg)),
      const SizedBox(height: 5),
      child,
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!, style: TextStyle(fontSize: 12, color: c.bad)))
      else if (hint != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: TextStyle(fontSize: 11.5, color: c.fg3))),
    ]);
  }
}

class In extends StatelessWidget {
  final TextEditingController controller;
  final String? placeholder;
  final bool decimal;
  final bool numeric;
  final bool monoFont;
  final bool big;
  final int maxLines;
  final bool readOnly;
  final bool enabled;
  final bool obscure;
  final bool hasError;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign align;
  final Iterable<String>? autofill;
  const In(this.controller,
      {super.key,
      this.placeholder,
      this.decimal = false,
      this.numeric = false,
      this.monoFont = false,
      this.big = false,
      this.maxLines = 1,
      this.readOnly = false,
      this.enabled = true,
      this.obscure = false,
      this.hasError = false,
      this.maxLength,
      this.onChanged,
      this.onSubmitted,
      this.align = TextAlign.start,
      this.autofill});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      minLines: 1,
      maxLength: maxLength,
      textAlign: align,
      autofillHints: autofill,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : (numeric ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text)),
      style: (monoFont ? mono(context, size: big ? 22 : 13.5) : TextStyle(fontSize: big ? 20 : 13.5, color: c.fg)).copyWith(letterSpacing: monoFont && big ? 6 : null),
      decoration: InputDecoration(
        hintText: placeholder,
        counterText: '',
        fillColor: readOnly ? c.surface2 : c.surface,
        enabledBorder: hasError ? OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.bad)) : null,
        contentPadding: big ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14) : null,
      ),
    );
  }
}

/// Dropdown select. [items] are (value, label). A null value shows [placeholder].
class Sel<T> extends StatelessWidget {
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;
  final String placeholder;
  final bool hasError;
  final bool Function(T value)? disabled;
  const Sel({super.key, required this.value, required this.items, required this.onChanged, this.placeholder = 'Select', this.hasError = false, this.disabled});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = items.any((i) => i.$1 == value);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: onChanged == null ? c.surface2 : c.surface,
        border: Border.all(color: hasError ? c.bad : c.line2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: has ? value : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: c.surface,
          hint: Text(placeholder, style: TextStyle(fontSize: 13.5, color: c.fg3), overflow: TextOverflow.ellipsis),
          style: TextStyle(fontSize: 13.5, color: c.fg),
          onChanged: onChanged,
          items: [
            for (final i in items)
              DropdownMenuItem<T>(
                value: i.$1,
                enabled: disabled == null || !disabled!(i.$1),
                child: Text(i.$2, overflow: TextOverflow.ellipsis, style: TextStyle(color: (disabled != null && disabled!(i.$1)) ? c.fg3 : c.fg)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Date (and optionally time) picker shown as a read-only field.
class DateTimeIn extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool dateOnly;
  final bool hasError;
  const DateTimeIn({super.key, required this.value, required this.onChanged, this.dateOnly = false, this.hasError = false});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final init = value ?? now;
    final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 3));
    if (d == null || !context.mounted) return;
    if (dateOnly) {
      onChanged(DateTime(d.year, d.month, d.day));
      return;
    }
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null) return;
    onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final text = value == null ? 'Choose' : (dateOnly ? localDate(value!) : localDateTime(value!));
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: c.surface, border: Border.all(color: hasError ? c.bad : c.line2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: value == null ? c.fg3 : c.fg), overflow: TextOverflow.ellipsis)),
          Icon(dateOnly ? Icons.calendar_today_outlined : Icons.schedule, size: 16, color: c.fg3),
        ]),
      ),
    );
  }
}

class CheckLine extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  const CheckLine({super.key, required this.value, required this.onChanged, required this.label});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      );
}

/* ───────────── Simple tables ───────────── */

/// A small fixed table (no paging), scrolled sideways on narrow screens.
class MiniTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final Set<int> numeric;
  final String? emptyText;
  const MiniTable({super.key, required this.headers, required this.rows, this.numeric = const {}, this.emptyText});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (rows.isEmpty && emptyText != null) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(emptyText!, style: TextStyle(fontSize: 13.5, color: c.fg3)));
    }
    Widget cell(Widget w, int i, {bool head = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: numeric.contains(i) ? Alignment.centerRight : Alignment.centerLeft,
          child: head ? DefaultTextStyle.merge(style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.fg2), child: w) : DefaultTextStyle.merge(style: const TextStyle(fontSize: 13), child: w),
        );
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(horizontalInside: BorderSide(color: c.line)),
            children: [
              TableRow(decoration: BoxDecoration(color: c.surface2), children: [for (var i = 0; i < headers.length; i++) cell(Text(headers[i]), i, head: true)]),
              for (final r in rows) TableRow(children: [for (var i = 0; i < r.length; i++) cell(r[i], i)]),
            ],
          ),
        ),
      );
    });
  }
}

Widget numText(String s, {bool bold = false, Color? color}) =>
    Text(s, textAlign: TextAlign.right, style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], fontWeight: bold ? FontWeight.w600 : null, color: color));

/* ───────────── Dialogs and sheets ───────────── */

/// Opens [child] as a centred dialog on wide screens and a bottom sheet on phones (the web app's Dialog/Drawer).
Future<T?> showSheet<T>(BuildContext context, Widget child, {bool wide = false}) {
  if (context.screenW >= 720) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.c.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: wide ? 820 : 560, maxHeight: MediaQuery.sizeOf(ctx).height * 0.9), child: child),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.92), child: child),
    ),
  );
}

/// Title, scrollable body and footer actions for content shown with [showSheet].
class SheetScaffold extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  final List<Widget> actions;
  const SheetScaffold({super.key, required this.title, this.description, required this.children, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (description != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(description!, style: TextStyle(fontSize: 13, color: c.fg2))),
            ]),
          ),
          IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, size: 18), tooltip: 'Close'),
        ]),
      ),
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Gap(children))),
      if (actions.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: SafeArea(top: false, child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions)),
        ),
    ]);
  }
}

/// Shows exported CSV text with a copy button. The data comes from the API responses already on screen.
Future<void> showCsv(BuildContext context, String filename, List<List<Object?>> rows) {
  final text = toCsv(rows);
  return showSheet(
    context,
    SheetScaffold(
      title: 'Export CSV',
      description: '$filename · ${rows.length - 1} row${rows.length - 1 == 1 ? '' : 's'}',
      actions: [
        Builder(
            builder: (ctx) => Btn('Copy to clipboard', icon: Icons.copy, onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  toast('CSV copied. Paste it into a spreadsheet or a .csv file.');
                })),
      ],
      children: [
        const Note(text: 'Copy the text below into Excel, Google Sheets or a text file saved as .csv. It is built from the same API data shown on screen.'),
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: context.c.surface2, borderRadius: BorderRadius.circular(6)),
          child: SingleChildScrollView(child: SelectableText(text, style: mono(context, size: 11))),
        ),
      ],
    ),
    wide: true,
  );
}

/* ───────────── Query rendering helpers ───────────── */

/// Loading / error / empty / data for one named query in a [QSet] (the web app's `QueryState`).
Widget qView<T>(QSet q, String name, Widget Function(T data) builder,
    {String? emptyTitle, String? emptyBody, Widget? emptyAction, bool Function(T data)? isEmpty, int rows = 4}) {
  final d = q.get<T>(name);
  if (d == null) {
    final e = q.error(name);
    if (e != null) return ErrorState(error: e, onRetry: q.refetch);
    return LoadingRows(rows: rows);
  }
  if (emptyTitle != null) {
    final empty = isEmpty != null ? isEmpty(d) : (d is List && d.isEmpty);
    if (empty) return EmptyState(title: emptyTitle, body: emptyBody, action: emptyAction);
  }
  return builder(d);
}

/// "…" while loading, otherwise [f] of the data.
String qText<T>(QSet q, String name, String Function(T data) f) {
  final d = q.get<T>(name);
  return d == null ? '…' : f(d);
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
