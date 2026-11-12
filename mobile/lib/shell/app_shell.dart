import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/nav.dart';
import '../core/query.dart';
import '../core/roles.dart';
import '../ui/widgets.dart';

/// Polls /health every 30 s; the shell shows a banner while the backend is unreachable.
class Health {
  static final ValueNotifier<bool> down = ValueNotifier<bool>(false);
  static Timer? _t;
  static void start() {
    _t ??= Timer.periodic(const Duration(seconds: 30), (_) => check());
    check();
  }

  static Future<void> check() async {
    try {
      await Api.health();
      down.value = false;
    } catch (_) {
      down.value = true;
    }
  }
}

/// Workspace frame: sidebar on desktop; top bar, drawer and (for phone-first roles) bottom tabs on phones.
class AppShell extends StatelessWidget {
  final String path;
  final Widget child;

  /// Detail screens (passport, case review) are opened on top of a workspace screen and close with Back.
  final bool detail;
  const AppShell({super.key, required this.path, required this.child, this.detail = false});

  @override
  Widget build(BuildContext context) {
    final role = auth.role;
    final base = role == null ? '/' : kBase[role]!;
    final mobileTabs = role != null && kMobileFirst.contains(role);
    final wide = context.wide;
    final c = context.c;

    final content = RefreshIndicator(
      onRefresh: () async {
        queryBus.invalidate(const ['']);
        await Health.check();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, mobileTabs && !wide ? 32 : 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!wide && context.screenW < 640) const Padding(padding: EdgeInsets.only(bottom: 16), child: BatchSearch()),
              child,
            ]),
          ),
        ),
      ),
    );

    final body = Column(children: [
      const BackendBanner(),
      Expanded(child: content),
    ]);

    Widget scaffold;
    if (wide) {
      scaffold = Scaffold(
        backgroundColor: c.bg,
        body: Row(children: [
          SizedBox(
            width: 240,
            child: Container(
              color: c.side,
              child: SafeArea(
                right: false,
                child: Column(children: [
                  const Brand(),
                  Expanded(child: SideNav(path: path)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
                    child: Text('Connected to ReLoop API', style: TextStyle(fontSize: 11, color: c.sideFg)),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Column(children: [
              TopBar(detail: detail, showMenu: false),
              Expanded(child: body),
            ]),
          ),
        ]),
      );
    } else {
      scaffold = Scaffold(
        backgroundColor: c.bg,
        drawer: Drawer(
          backgroundColor: c.side,
          width: 272,
          child: SafeArea(child: Column(children: [const Brand(), Expanded(child: SideNav(path: path, onNavigate: () {}))])),
        ),
        appBar: PreferredSize(preferredSize: const Size.fromHeight(56), child: TopBar(detail: detail, showMenu: !mobileTabs)),
        body: body,
        bottomNavigationBar: mobileTabs ? BottomTabs(path: path) : null,
      );
    }

    if (detail || path == base) return scaffold;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(base);
      },
      child: scaffold,
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final role = auth.role;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: const Color(0xFF2E9B72), borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.recycling, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ReLoop', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(role != null ? kRoleLabel[role]! : '', style: TextStyle(fontSize: 11, color: c.sideFg), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

bool _isActive(String path, String to, String base) => to == base ? path == to : (path == to || path.startsWith('$to/'));

class SideNav extends StatelessWidget {
  final String path;
  final VoidCallback? onNavigate;
  const SideNav({super.key, required this.path, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final role = auth.role;
    if (role == null) return const SizedBox.shrink();
    final base = kBase[role]!;
    final groups = kNav[role]!;
    // Longest matching item wins, so /g/listings/new does not also highlight /g/listings.
    String? active;
    for (final g in groups) {
      for (final it in g.items) {
        if (_isActive(path, it.to, base) && (active == null || it.to.length > active.length)) active = it.to;
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 16), children: [
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
          child: Text(g.label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: c.sideFg.withValues(alpha: 0.6))),
        ),
        for (final it in g.items)
          Material(
            color: it.to == active ? c.sideAct : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                if (onNavigate != null) Navigator.of(context).maybePop();
                go(it.to);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Icon(it.icon, size: 16, color: it.to == active ? Colors.white : c.sideFg),
                  const SizedBox(width: 10),
                  Expanded(child: Text(it.label, style: TextStyle(fontSize: 13.5, color: it.to == active ? Colors.white : c.sideFg))),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }
}

class BottomTabs extends StatelessWidget {
  final String path;
  const BottomTabs({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final role = auth.role!;
    final base = kBase[role]!;
    final tabs = kNav[role]!.expand((g) => g.items).where((i) => i.tab).take(4).toList();
    bool on(NavItem t) => (t.to == base || t.to.endsWith('/new')) ? path == t.to : _isActive(path, t.to, base) && !tabs.any((o) => o != t && o.to.length > t.to.length && _isActive(path, o.to, base));
    final inTabs = tabs.any(on);
    Widget item(String label, IconData icon, bool active, VoidCallback onTap, {bool primary = false}) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                primary
                    ? Container(
                        width: 42,
                        height: 34,
                        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 20, color: c.brandFg),
                      )
                    : SizedBox(height: 34, child: Icon(icon, size: 22, color: active ? c.brand : c.fg3)),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: active ? c.brand : c.fg3)),
              ]),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (final t in tabs) item(t.label.split(' ').first, t.icon, on(t), () => go(t.to), primary: t.primaryAction),
          Builder(builder: (ctx) => item('More', Icons.more_horiz, !inTabs, () => Scaffold.of(ctx).openDrawer())),
        ]),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  final bool detail;
  final bool showMenu;
  const TopBar({super.key, required this.detail, required this.showMenu});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final org = auth.org;
    final role = auth.role;
    final name = sn(org?['legal_name']) ?? '';
    return Material(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            if (detail)
              IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => back(role == null ? '/' : kBase[role]!))
            else if (showMenu)
              Builder(builder: (ctx) => IconButton(tooltip: 'Open navigation', icon: const Icon(Icons.menu, size: 20), onPressed: () => Scaffold.of(ctx).openDrawer())),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(6)),
              child: Text(name.length >= 2 ? name.substring(0, 2).toUpperCase() : name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.brandFg)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(role != null ? kRoleLabel[role]! : '', style: TextStyle(fontSize: 11.5, color: c.fg3)),
              ]),
            ),
            if (context.screenW >= 640) const SizedBox(width: 340, child: BatchSearch()),
            const SizedBox(width: 6),
            const UserMenu(),
          ]),
        ),
      ),
    );
  }
}

/// Open any batch's passport by its code.
class BatchSearch extends StatefulWidget {
  const BatchSearch({super.key});
  @override
  State<BatchSearch> createState() => _BatchSearchState();
}

class _BatchSearchState extends State<BatchSearch> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final code = _c.text.trim().toUpperCase();
    if (code.isEmpty) return;
    _c.clear();
    openPassport(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _c,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _go(),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Open batch by code, e.g. RL-MUM-2026-000105',
          fillColor: c.surface2,
          prefixIcon: Icon(Icons.search, size: 16, color: c.fg3),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final u = auth.user;
    if (u == null) return const SizedBox.shrink();
    final fullName = sn(u['full_name']) ?? '';
    final initials = fullName.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      position: PopupMenuPosition.under,
      onSelected: (v) async {
        if (v == 'profile') push('/profile');
        if (v == 'out') auth.signOut();
        if (v.startsWith('role:')) {
          final r = v.split(':')[1];
          final newRole = await auth.switchRole(r);
          if (newRole != null) go(kBase[newRole]!);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text('${u['email'] ?? ''}\n${auth.org?['legal_name'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fg3)),
        ),
        const PopupMenuDivider(),
        if (auth.role != 'admin')
          const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.apartment, size: 16), SizedBox(width: 8), Text('Organisation profile')])),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(enabled: false, child: Text('Switch Role (Demo):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        const PopupMenuItem(value: 'role:generator', child: Row(children: [Icon(Icons.eco, size: 16), SizedBox(width: 8), Text('Generator')])),
        const PopupMenuItem(value: 'role:collector', child: Row(children: [Icon(Icons.local_shipping, size: 16), SizedBox(width: 8), Text('Collector')])),
        const PopupMenuItem(value: 'role:recycler', child: Row(children: [Icon(Icons.recycling, size: 16), SizedBox(width: 8), Text('Recycler')])),
        const PopupMenuItem(value: 'role:ngo', child: Row(children: [Icon(Icons.verified_user, size: 16), SizedBox(width: 8), Text('NGO Auditor')])),
        const PopupMenuItem(value: 'role:epr', child: Row(children: [Icon(Icons.business, size: 16), SizedBox(width: 8), Text('EPR Brand')])),
        const PopupMenuItem(value: 'role:admin', child: Row(children: [Icon(Icons.admin_panel_settings, size: 16), SizedBox(width: 8), Text('Admin')])),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'out',
            child: Row(children: [Icon(Icons.logout, size: 16, color: c.bad), const SizedBox(width: 8), Text('Sign out', style: TextStyle(color: c.bad))])),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 16, backgroundColor: c.accentSoft, child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.brand))),
          if (context.screenW >= 768) ...[
            const SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${auth.me?['active_role'] ?? ''}${u['is_platform_admin'] == true ? ' · Platform admin' : ''}', style: TextStyle(fontSize: 11.5, color: c.fg3)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class BackendBanner extends StatelessWidget {
  const BackendBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<bool>(
      valueListenable: Health.down,
      builder: (context, down, _) => !down
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              color: c.badBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Icon(Icons.wifi_off, size: 14, color: c.bad),
                const SizedBox(width: 8),
                Expanded(child: Text('The ReLoop backend is not responding. Records shown may be out of date; changes cannot be saved.', style: TextStyle(fontSize: 12, color: c.bad))),
              ]),
            ),
    );
  }
}
