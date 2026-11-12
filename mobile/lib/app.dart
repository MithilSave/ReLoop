import 'package:flutter/material.dart';

import 'core/auth.dart';
import 'core/nav.dart';
import 'core/query.dart';
import 'core/roles.dart';
import 'pages/admin.dart';
import 'pages/collector.dart';
import 'pages/epr.dart';
import 'pages/generator.dart';
import 'pages/ngo.dart';
import 'pages/recycler.dart';
import 'pages/shared.dart';
import 'shell/app_shell.dart';
import 'ui/widgets.dart';

/// One screen of the workspace: which roles may open it and how to build it.
class RouteDef {
  final List<String>? roles;
  final Widget Function(Uri uri) build;
  const RouteDef(this.roles, this.build);
}

const _g = ['generator'], _c = ['collector'], _r = ['recycler'], _n = ['ngo'], _e = ['epr'], _a = ['admin'];

/// The same 52 routes as the web app.
final Map<String, RouteDef> kRoutes = {
  '/profile': RouteDef(null, (_) => const ProfilePage()),
  '/g': RouteDef(_g, (_) => const GeneratorOverview()),
  '/g/listings': RouteDef(_g, (_) => const GeneratorListings()),
  '/g/listings/new': RouteDef(_g, (_) => const CreateListing()),
  '/g/offers': RouteDef(_g, (_) => const GeneratorOffers()),
  '/g/handover': RouteDef(_g, (_) => const GeneratorHandover()),
  '/g/batches': RouteDef(_g, (_) => const GeneratorBatches()),
  '/g/payments': RouteDef(_g, (_) => const GeneratorPayments()),
  '/g/statements': RouteDef(_g, (_) => const GeneratorStatements()),
  '/g/analytics': RouteDef(_g, (_) => const GeneratorAnalytics()),
  '/c': RouteDef(_c, (_) => const CollectorOverview()),
  '/c/listings': RouteDef(_c, (_) => const CollectorListings()),
  '/c/assignments': RouteDef(_c, (_) => const CollectorAssignments()),
  '/c/pickup': RouteDef(_c, (u) => CollectorPickup(batchId: u.queryParameters['batch'])),
  '/c/consignments': RouteDef(_c, (_) => const CollectorConsignments()),
  '/c/plans': RouteDef(_c, (_) => const CollectorPlans()),
  '/c/deliveries': RouteDef(_c, (_) => const CollectorDeliveries()),
  '/c/transactions': RouteDef(_c, (_) => const CollectorTransactions()),
  '/c/performance': RouteDef(_c, (_) => const CollectorPerformance()),
  '/r': RouteDef(_r, (_) => const RecyclerDashboard()),
  '/r/requirements': RouteDef(_r, (_) => const RecyclerRequirements()),
  '/r/suppliers': RouteDef(_r, (_) => const RecyclerSuppliers()),
  '/r/planner': RouteDef(_r, (_) => const RecyclerPlanner()),
  '/r/costs': RouteDef(_r, (_) => const RecyclerCosts()),
  '/r/outlook': RouteDef(_r, (_) => const RecyclerOutlook()),
  '/r/incoming': RouteDef(_r, (_) => const RecyclerIncoming()),
  '/r/receipts': RouteDef(_r, (_) => const RecyclerReceipts()),
  '/r/runs': RouteDef(_r, (_) => const RecyclerRuns()),
  '/r/yield': RouteDef(_r, (_) => const RecyclerYield()),
  '/r/allocations': RouteDef(_r, (_) => const RecyclerAllocations()),
  '/n': RouteDef(_n, (_) => const NgoDashboard()),
  '/n/cases': RouteDef(_n, (_) => const NgoCases()),
  '/n/custody': RouteDef(_n, (_) => const NgoCustody()),
  '/n/reconciliation': RouteDef(_n, (_) => const NgoReconciliation()),
  '/n/documents': RouteDef(_n, (_) => const NgoDocuments()),
  '/n/discrepancies': RouteDef(_n, (_) => const NgoDiscrepancies()),
  '/n/reports': RouteDef(_n, (_) => const NgoReports()),
  '/n/audit': RouteDef(_n, (_) => const NgoAudit()),
  '/e': RouteDef(_e, (_) => const EprOverview()),
  '/e/obligations': RouteDef(_e, (_) => const EprObligations()),
  '/e/ledger': RouteDef(_e, (_) => const EprLedger()),
  '/e/verified': RouteDef(_e, (_) => const EprVerified()),
  '/e/trace': RouteDef(_e, (_) => const EprTrace()),
  '/e/recyclers': RouteDef(_e, (_) => const EprRecyclers()),
  '/e/discrepancies': RouteDef(_e, (_) => const EprDiscrepancies()),
  '/e/reports': RouteDef(_e, (_) => const EprReports()),
  '/a': RouteDef(_a, (_) => const AdminOverview()),
  '/a/organisations': RouteDef(_a, (_) => const AdminOrganisations()),
  '/a/anomalies': RouteDef(_a, (_) => const AdminAnomalies()),
  '/a/audit': RouteDef(_a, (_) => const AdminAudit()),
  '/a/lookup': RouteDef(_a, (_) => const AdminLookup()),
};

Route<dynamic> _instant(RouteSettings s, Widget w) => PageRouteBuilder<dynamic>(
      settings: s,
      pageBuilder: (_, __, ___) => w,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );

Route<dynamic> onGenerateRoute(RouteSettings s) {
  final uri = Uri.parse(s.name ?? '/');
  final path = uri.path.length > 1 && uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;

  if (auth.status == AuthStatus.loading) return _instant(s, const _Splash());
  if (auth.status == AuthStatus.anonymous || path == '/login') {
    return _instant(const RouteSettings(name: '/login'), const LoginPage());
  }
  final role = auth.role;
  if (path == '/') {
    final base = role == null ? null : kBase[role];
    if (base == null) return _instant(s, const AppShell(path: '/', child: UnauthorisedPage()));
    final def = kRoutes[base]!;
    return _instant(RouteSettings(name: base), AppShell(path: base, child: def.build(uri)));
  }

  // Detail screens open on top of the current screen.
  final segs = uri.pathSegments;
  if (segs.length == 2 && segs[0] == 'passport') {
    return MaterialPageRoute<dynamic>(settings: s, builder: (_) => AppShell(path: path, detail: true, child: PassportPage(code: segs[1])));
  }
  if (segs.length == 3 && segs[0] == 'n' && segs[1] == 'cases') {
    final child = role == 'ngo' ? NgoCaseReview(id: segs[2]) : const UnauthorisedPage(needs: ['ngo']);
    return MaterialPageRoute<dynamic>(settings: s, builder: (_) => AppShell(path: path, detail: true, child: child));
  }
  if (path == '/profile') {
    return MaterialPageRoute<dynamic>(settings: s, builder: (_) => const AppShell(path: '/profile', detail: true, child: ProfilePage()));
  }

  final def = kRoutes[path];
  if (def == null) return _instant(s, AppShell(path: path, child: const NotFoundPage()));
  if (def.roles != null && (role == null || !def.roles!.contains(role))) {
    return _instant(s, AppShell(path: path, child: UnauthorisedPage(needs: def.roles)));
  }
  return _instant(s, AppShell(path: path, child: def.build(uri)));
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.c.bg,
        body: const Center(child: SizedBox(width: 360, child: LoadingRows(rows: 3))),
      );
}

class ReLoopApp extends StatefulWidget {
  const ReLoopApp({super.key});
  @override
  State<ReLoopApp> createState() => _ReLoopAppState();
}

class _ReLoopAppState extends State<ReLoopApp> {
  AuthStatus _last = AuthStatus.loading;

  @override
  void initState() {
    super.initState();
    auth.addListener(_onAuth);
    // Health checks start once the saved server address has been loaded.
    auth.start().then((_) => Health.start());
  }

  @override
  void dispose() {
    auth.removeListener(_onAuth);
    super.dispose();
  }

  /// Sign-in goes to the workspace home; sign-out or an expired session goes to the login screen.
  void _onAuth() {
    final s = auth.status;
    if (s == _last) return;
    _last = s;
    if (s == AuthStatus.authenticated) {
      go(kBase[auth.role] ?? '/');
    } else if (s == AuthStatus.anonymous) {
      go('/login');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ReLoop',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        onGenerateRoute: onGenerateRoute,
        onGenerateInitialRoutes: (name) => [onGenerateRoute(RouteSettings(name: name))],
      );
}
