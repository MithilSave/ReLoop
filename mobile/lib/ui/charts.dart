import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import 'widgets.dart';

class Series {
  final String name;
  final Color color;
  final List<double> values;
  const Series(this.name, this.color, this.values);
}

/// Vertical bar chart (grouped or stacked) drawn with plain widgets. Tap a bar to see its value.
class BarChart extends StatefulWidget {
  final List<String> labels;
  final List<Series> series;
  final bool stacked;
  final double height;
  final String Function(double v) format;
  const BarChart({super.key, required this.labels, required this.series, this.stacked = false, this.height = 220, this.format = _kg});

  static String _kg(double v) => kg(v);

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  (int, int)? _sel;

  double _nice(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (m * p >= v) return m * p;
    }
    return 10 * p;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = widget.labels.length;
    double maxV = 0;
    for (var i = 0; i < n; i++) {
      if (widget.stacked) {
        maxV = math.max(maxV, widget.series.fold<double>(0, (s, x) => s + math.max(0, x.values[i])));
      } else {
        for (final s in widget.series) {
          maxV = math.max(maxV, s.values[i]);
        }
      }
    }
    final top = _nice(maxV);
    final sel = _sel;
    String? selText;
    if (sel != null && sel.$1 < n && sel.$2 < widget.series.length) {
      final s = widget.series[sel.$2];
      selText = '${widget.labels[sel.$1]} · ${s.name}: ${widget.format(s.values[sel.$1])}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: widget.height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 52,
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var t = 4; t >= 0; t--) Text(num0(top * t / 4), style: TextStyle(fontSize: 10.5, color: c.fg3)),
              const SizedBox(height: 18),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(children: [
              Expanded(
                child: Stack(children: [
                  Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var t = 0; t < 5; t++) Container(height: 1, color: c.line)]),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: LayoutBuilder(builder: (context, box) {
                            final h = box.maxHeight;
                            if (widget.stacked) {
                              return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                for (var s = widget.series.length - 1; s >= 0; s--)
                                  GestureDetector(
                                    onTap: () => setState(() => _sel = (i, s)),
                                    child: Container(
                                      height: (math.max(0, widget.series[s].values[i]) / top * h).clamp(0, h),
                                      color: widget.series[s].color,
                                    ),
                                  ),
                              ]);
                            }
                            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              for (var s = 0; s < widget.series.length; s++)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _sel = (i, s)),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      height: (math.max(0, widget.series[s].values[i]) / top * h).clamp(0, h),
                                      decoration: BoxDecoration(color: widget.series[s].color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                                    ),
                                  ),
                                ),
                            ]);
                          }),
                        ),
                      ),
                  ]),
                ]),
              ),
              SizedBox(
                height: 18,
                child: Row(children: [
                  for (var i = 0; i < n; i++)
                    Expanded(child: Text(widget.labels[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: c.fg3))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        if (widget.series.length > 1)
          for (final s in widget.series) Legend(s.name, s.color),
        Text(selText ?? 'Tap a bar for its value', style: TextStyle(fontSize: 11.5, color: selText != null ? c.fg : c.fg3)),
      ]),
    ]);
  }
}

class Legend extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  const Legend(this.label, this.color, {super.key, this.outlined = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2), border: outlined ? Border.all(color: context.c.line2) : null)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.c.fg2)),
      ]);
}

/// One horizontal bar split into coloured segments, each a fraction of [total].
class SegBar extends StatelessWidget {
  final List<(double, Color)> parts;
  final double total;
  final double height;
  const SegBar(this.parts, this.total, {super.key, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: height,
        color: context.c.surface2,
        child: LayoutBuilder(builder: (context, box) {
          var used = 0.0;
          return Row(children: [
            for (final p in parts)
              Builder(builder: (context) {
                final double w = total <= 0 ? 0.0 : (p.$1 / total * box.maxWidth).clamp(0.0, math.max(0.0, box.maxWidth - used)).toDouble();
                used += w;
                return Container(width: w, color: p.$2);
              }),
          ]);
        }),
      ),
    );
  }
}
