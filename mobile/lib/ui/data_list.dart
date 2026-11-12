import 'package:flutter/material.dart';

import 'widgets.dart';

/// Column of a [DataList].
class Col<T> {
  final String key;
  final String header;
  final Widget Function(T row) cell;
  final Comparable<Object>? Function(T row)? sort;
  final bool numeric;

  /// Hidden on phones (the web app's hideOnMobile).
  final bool hideOnMobile;
  const Col(this.key, this.header, this.cell, {this.sort, this.numeric = false, this.hideOnMobile = false});
}

/// Text column helper.
Col<T> tcol<T>(String key, String header, String Function(T row) text, {bool sortable = true, bool numeric = false, bool hideOnMobile = false, bool small = false}) => Col<T>(
      key,
      header,
      (r) => numeric ? numText(text(r)) : Text(text(r), style: TextStyle(fontSize: small ? 12 : 13)),
      sort: sortable ? (r) => text(r) : null,
      numeric: numeric,
      hideOnMobile: hideOnMobile,
    );

/// Numeric column with a number formatter; sorting uses the raw number.
Col<T> ncol<T>(String key, String header, double? Function(T row) v, String Function(double? v) fmt, {bool sortable = true, bool hideOnMobile = false}) => Col<T>(
      key,
      header,
      (r) => numText(fmt(v(r))),
      sort: sortable ? (r) => v(r) : null,
      numeric: true,
      hideOnMobile: hideOnMobile,
    );

class Flt<T> {
  final String key;
  final String label;
  final List<(String, String)> options;
  final String Function(T row) get;
  const Flt(this.key, this.label, this.options, this.get);
}

/// Totals shown under the list.
class FootItem {
  final String label;
  final String value;
  const FootItem(this.label, this.value);
}

/// Search, filter, sort and paginate on the device: the backend returns full lists with no paging.
/// Wide screens show a table; phones show one card per row.
class DataList<T> extends StatefulWidget {
  final List<T> rows;
  final List<Col<T>> cols;
  final String Function(T row) rowKey;
  final void Function(T row)? onTap;
  final String Function(T row)? search;
  final String searchHint;
  final List<Flt<T>> filters;
  final int pageSize;
  final String? sortKey;
  final bool sortAsc;
  final String emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;
  final List<FootItem> Function(List<T> rows)? footer;
  final List<Widget> toolbar;
  final bool Function(T row)? dim;
  final String label;
  const DataList({
    super.key,
    required this.rows,
    required this.cols,
    required this.rowKey,
    required this.label,
    this.onTap,
    this.search,
    this.searchHint = 'Search',
    this.filters = const [],
    this.pageSize = 10,
    this.sortKey,
    this.sortAsc = true,
    this.emptyTitle = 'Nothing here yet',
    this.emptyBody,
    this.emptyAction,
    this.footer,
    this.toolbar = const [],
    this.dim,
  });

  @override
  State<DataList<T>> createState() => _DataListState<T>();
}

class _DataListState<T> extends State<DataList<T>> {
  final _q = TextEditingController();
  final Map<String, String> _f = {};
  String? _sort;
  bool _asc = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _sort = widget.sortKey;
    _asc = widget.sortAsc;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    Iterable<T> out = widget.rows;
    final s = _q.text.trim().toLowerCase();
    if (s.isNotEmpty && widget.search != null) out = out.where((r) => widget.search!(r).toLowerCase().contains(s));
    for (final f in widget.filters) {
      final v = _f[f.key];
      if (v != null && v.isNotEmpty) out = out.where((r) => f.get(r) == v);
    }
    final list = out.toList();
    final col = widget.cols.where((c) => c.key == _sort && c.sort != null).firstOrNull;
    if (col != null) {
      final g = col.sort!;
      list.sort((a, b) {
        final x = g(a), y = g(b);
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        final r = x.compareTo(y);
        return _asc ? r : -r;
      });
    }
    return list;
  }

  bool get _filtering => _q.text.isNotEmpty || _f.values.any((v) => v.isNotEmpty);

  void _toggleSort(String key) => setState(() {
        if (_sort == key) {
          _asc = !_asc;
        } else {
          _sort = key;
          _asc = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _filtered;
    final pages = (rows.length / widget.pageSize).ceil().clamp(1, 1 << 30);
    final p = _page.clamp(0, pages - 1);
    final view = rows.skip(p * widget.pageSize).take(widget.pageSize).toList();
    final sortable = widget.cols.where((c) => c.sort != null).toList();
    final showBar = widget.search != null || widget.filters.isNotEmpty || widget.toolbar.isNotEmpty;

    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 720;
      final cols = narrow ? widget.cols.where((c) => !c.hideOnMobile).toList() : widget.cols;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (showBar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (widget.search != null)
                SizedBox(
                  width: narrow ? box.maxWidth - 24 : 260,
                  height: 36,
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() => _page = 0),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: Icon(Icons.search, size: 16, color: c.fg3),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              for (final f in widget.filters)
                SizedBox(
                  width: narrow ? (box.maxWidth - 32) / 2 : 180,
                  child: Sel<String>(
                    value: _f[f.key] ?? '',
                    items: [('', '${f.label}: all'), ...f.options],
                    onChanged: (v) => setState(() {
                      _f[f.key] = v ?? '';
                      _page = 0;
                    }),
                  ),
                ),
              if (narrow && sortable.isNotEmpty)
                SizedBox(
                  width: (box.maxWidth - 32) / 2,
                  child: Row(children: [
                    Expanded(
                      child: Sel<String>(
                        value: _sort ?? '',
                        items: [('', 'Sort: default'), for (final s in sortable) (s.key, 'Sort: ${s.header.isEmpty ? s.key : s.header}')],
                        onChanged: (v) => setState(() => _sort = (v == null || v.isEmpty) ? null : v),
                      ),
                    ),
                    IconButton(
                      tooltip: _asc ? 'Ascending' : 'Descending',
                      onPressed: _sort == null ? null : () => setState(() => _asc = !_asc),
                      icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                    ),
                  ]),
                ),
              ...widget.toolbar,
              Text(plural(rows.length, 'record'), style: TextStyle(fontSize: 12, color: c.fg3)),
            ]),
          ),
        if (view.isEmpty)
          _filtering
              ? EmptyState(
                  title: 'No records match these filters',
                  body: 'Clear the search or change a filter.',
                  action: Btn('Clear filters', small: true, kind: BtnKind.outline, onPressed: () => setState(() {
                        _q.clear();
                        _f.clear();
                      })),
                )
              : EmptyState(title: widget.emptyTitle, body: widget.emptyBody, action: widget.emptyAction)
        else if (narrow)
          _cards(context, view, cols)
        else
          _table(context, view, cols, box.maxWidth),
        if (widget.footer != null && rows.isNotEmpty)
          Container(
            color: c.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(spacing: 18, runSpacing: 4, children: [
              for (final f in widget.footer!(rows))
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${f.label}${f.value.isEmpty ? '' : ': '}', style: TextStyle(color: c.fg2)),
                  TextSpan(text: f.value, style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                ]), style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        if (rows.length > widget.pageSize)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text('Showing ${p * widget.pageSize + 1}–${(p * widget.pageSize + widget.pageSize).clamp(0, rows.length)} of ${rows.length}', style: TextStyle(fontSize: 12, color: c.fg3)),
              IconButton(tooltip: 'Previous page', onPressed: p == 0 ? null : () => setState(() => _page = p - 1), icon: const Icon(Icons.chevron_left, size: 18)),
              Text('Page ${p + 1} of $pages', style: TextStyle(fontSize: 12, color: c.fg3)),
              IconButton(tooltip: 'Next page', onPressed: p >= pages - 1 ? null : () => setState(() => _page = p + 1), icon: const Icon(Icons.chevron_right, size: 18)),
            ]),
          ),
      ]);
    });
  }

  Widget _table(BuildContext context, List<T> view, List<Col<T>> cols, double width) {
    final c = context.c;
    Widget headCell(Col<T> col) {
      final sorted = _sort == col.key;
      final t = Text(col.header, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sorted ? c.fg : c.fg2));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: col.sort == null
            ? t
            : InkWell(
                onTap: () => _toggleSort(col.key),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  t,
                  const SizedBox(width: 3),
                  Icon(sorted ? (_asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 12, color: sorted ? c.fg : c.fg3),
                ]),
              ),
      );
    }

    Widget bodyCell(Col<T> col, T row) {
      final cell = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13), child: col.cell(row)),
      );
      final dimmed = widget.dim != null && widget.dim!(row) ? Opacity(opacity: 0.6, child: cell) : cell;
      if (widget.onTap == null) return dimmed;
      return InkWell(onTap: () => widget.onTap!(row), child: dimmed);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: width),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(horizontalInside: BorderSide(color: c.line)),
          children: [
            TableRow(decoration: BoxDecoration(color: c.surface2), children: [for (final col in cols) headCell(col)]),
            for (final r in view) TableRow(key: ValueKey(widget.rowKey(r)), children: [for (final col in cols) bodyCell(col, r)]),
          ],
        ),
      ),
    );
  }

  Widget _cards(BuildContext context, List<T> view, List<Col<T>> cols) {
    final c = context.c;
    final first = cols.first;
    final rest = cols.skip(1).toList();
    final labelled = rest.where((x) => x.header.isNotEmpty).toList();
    final actions = rest.where((x) => x.header.isEmpty).toList();
    return Column(children: [
      for (final r in view)
        Opacity(
          opacity: widget.dim != null && widget.dim!(r) ? 0.6 : 1,
          child: InkWell(
            key: ValueKey(widget.rowKey(r)),
            onTap: widget.onTap == null ? null : () => widget.onTap!(r),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500), child: first.cell(r))),
                  if (widget.onTap != null) Icon(Icons.chevron_right, size: 18, color: c.fg3),
                ]),
                const SizedBox(height: 6),
                for (final col in labelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 120, child: Text(col.header, style: TextStyle(fontSize: 12, color: c.fg3))),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13), child: col.cell(r)),
                        ),
                      ),
                    ]),
                  ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(alignment: WrapAlignment.end, spacing: 6, children: [for (final a in actions) a.cell(r)]),
                  ),
              ]),
            ),
          ),
        ),
    ]);
  }
}
