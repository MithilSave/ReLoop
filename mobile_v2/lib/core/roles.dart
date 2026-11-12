import 'package:flutter/material.dart';

import 'api.dart';

const Map<String, String> kRoleLabel = {
  'generator': 'Generator',
  'collector': 'Collector',
  'recycler': 'Recycler',
  'ngo': 'NGO verification',
  'epr': 'EPR company',
  'admin': 'Platform admin',
};

const Map<String, String> _byOrgType = {
  'GENERATOR': 'generator',
  'COLLECTOR': 'collector',
  'RECYCLER': 'recycler',
  'NGO': 'ngo',
  'EPR_CLIENT': 'epr',
};

/// Admin is a user flag (is_platform_admin), not an org type; it takes precedence.
String? roleOf(J me) {
  final user = jo(me['user']);
  if (user != null && user['is_platform_admin'] == true) return 'admin';
  final org = jo(me['active_org']);
  if (org == null) return null;
  return _byOrgType[org['org_type']];
}

const List<String> kMobileFirst = ['generator', 'collector', 'recycler'];

const Map<String, String> kBase = {'generator': '/g', 'collector': '/c', 'recycler': '/r', 'ngo': '/n', 'epr': '/e', 'admin': '/a'};

class NavItem {
  final String to;
  final String label;
  final IconData icon;
  final bool tab;
  final bool primaryAction;
  const NavItem(this.to, this.label, this.icon, {this.tab = false, this.primaryAction = false});
}

class NavGroup {
  final String label;
  final List<NavItem> items;
  const NavGroup(this.label, this.items);
}

const Map<String, List<NavGroup>> kNav = {
  'generator': [
    NavGroup('Operate', [
      NavItem('/g', 'Overview', Icons.dashboard_outlined, tab: true),
      NavItem('/g/listings', 'Waste listings', Icons.list_alt, tab: true),
      NavItem('/g/listings/new', 'Create listing', Icons.add_box_outlined, tab: true, primaryAction: true),
      NavItem('/g/offers', 'Offers', Icons.sell_outlined),
      NavItem('/g/handover', 'Handover', Icons.back_hand_outlined),
    ]),
    NavGroup('Trace', [NavItem('/g/batches', 'Batch tracking', Icons.inventory_2_outlined, tab: true)]),
    NavGroup('Finance & impact', [
      NavItem('/g/payments', 'Payments', Icons.account_balance_wallet_outlined),
      NavItem('/g/statements', 'Contribution statements', Icons.workspace_premium_outlined),
      NavItem('/g/analytics', 'Contribution analytics', Icons.bar_chart),
    ]),
  ],
  'collector': [
    NavGroup('Operate', [
      NavItem('/c', 'Operations overview', Icons.dashboard_outlined, tab: true),
      NavItem('/c/listings', 'Available listings', Icons.list_alt, tab: true),
      NavItem('/c/pickup', 'Pickup verification', Icons.qr_code_scanner, tab: true, primaryAction: true),
      NavItem('/c/assignments', 'Collection assignments', Icons.assignment_turned_in_outlined),
      NavItem('/c/plans', 'Aggregation plans', Icons.layers_outlined),
    ]),
    NavGroup('Logistics', [
      NavItem('/c/consignments', 'Transport consignments', Icons.local_shipping_outlined, tab: true),
      NavItem('/c/deliveries', 'Delivery records', Icons.inbox_outlined),
    ]),
    NavGroup('Finance', [
      NavItem('/c/transactions', 'Payments & earnings', Icons.account_balance_wallet_outlined),
      NavItem('/c/performance', 'Performance', Icons.speed),
    ]),
  ],
  'recycler': [
    NavGroup('Overview', [NavItem('/r', 'Operations dashboard', Icons.dashboard_outlined, tab: true)]),
    NavGroup('Procurement', [
      NavItem('/r/requirements', 'Procurement requirements', Icons.track_changes),
      NavItem('/r/suppliers', 'Suppliers', Icons.groups_outlined),
      NavItem('/r/planner', 'Aggregation planner', Icons.layers_outlined, tab: true),
      NavItem('/r/costs', 'Landed cost', Icons.payments_outlined),
      NavItem('/r/outlook', 'Supply outlook', Icons.show_chart),
    ]),
    NavGroup('Receiving & processing', [
      NavItem('/r/incoming', 'Incoming consignments', Icons.local_shipping_outlined, tab: true, primaryAction: true),
      NavItem('/r/receipts', 'Material receipts', Icons.inbox_outlined),
      NavItem('/r/runs', 'Processing runs', Icons.science_outlined, tab: true),
      NavItem('/r/yield', 'Material yield', Icons.speed),
    ]),
    NavGroup('EPR', [NavItem('/r/allocations', 'EPR allocations', Icons.link)]),
  ],
  'ngo': [
    NavGroup('Overview', [
      NavItem('/n', 'Verification dashboard', Icons.dashboard_outlined),
      NavItem('/n/cases', 'Cases', Icons.assignment_turned_in_outlined),
    ]),
    NavGroup('Review', [
      NavItem('/n/custody', 'Chain of custody', Icons.account_tree_outlined),
      NavItem('/n/reconciliation', 'Quantity reconciliation', Icons.balance),
    ]),
    NavGroup('Follow-up', [
      NavItem('/n/documents', 'Document requests', Icons.description_outlined),
      NavItem('/n/discrepancies', 'Discrepancies', Icons.warning_amber),
      NavItem('/n/reports', 'Verification reports', Icons.workspace_premium_outlined),
      NavItem('/n/audit', 'Audit history', Icons.receipt_long),
    ]),
  ],
  'epr': [
    NavGroup('Compliance', [
      NavItem('/e', 'Compliance overview', Icons.dashboard_outlined),
      NavItem('/e/obligations', 'Obligations & targets', Icons.track_changes),
      NavItem('/e/ledger', 'Allocation ledger', Icons.link),
      NavItem('/e/verified', 'Verified quantities', Icons.verified_user_outlined),
    ]),
    NavGroup('Traceability', [
      NavItem('/e/trace', 'Batch traceability', Icons.account_tree_outlined),
      NavItem('/e/recyclers', 'Recycler records', Icons.factory_outlined),
      NavItem('/e/discrepancies', 'Discrepancy monitoring', Icons.warning_amber),
    ]),
    NavGroup('Reporting', [NavItem('/e/reports', 'Reports & exports', Icons.download_outlined)]),
  ],
  'admin': [
    NavGroup('Platform', [
      NavItem('/a', 'Platform overview', Icons.dashboard_outlined),
      NavItem('/a/organisations', 'Organisation approvals', Icons.apartment),
      NavItem('/a/anomalies', 'Anomaly alerts', Icons.warning_amber),
      NavItem('/a/audit', 'Audit trail', Icons.receipt_long),
      NavItem('/a/lookup', 'Batch lookup', Icons.search),
    ]),
  ],
};
