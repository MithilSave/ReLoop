import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/query.dart';
import '../core/roles.dart';
import '../features/passport.dart';
import '../ui/widgets.dart';

/// Seeded accounts from backend/seed_data.py. Shown only in debug builds or with --dart-define=SHOW_DEMO_ACCOUNTS=true.
const List<(String, String, String)> kDemoAccounts = [
  ('generator@reloop.in', 'Generator', 'Godrej Green Towers Housing Society'),
  ('collector@reloop.in', 'Collector', 'Dharavi Waste Collectors Welfare Society'),
  ('recycler@reloop.in', 'Recycler', 'Ecoplas Circular Solutions Ltd'),
  ('ngo@reloop.in', 'NGO auditor', 'Green Ledger Foundation India'),
  ('epr@reloop.in', 'EPR brand', 'Hindustan Consumer Goods Ltd'),
  ('admin@reloop.in', 'Platform admin', 'ReLoop Platform Governance'),
];
const bool _kDemoFlag = bool.fromEnvironment('SHOW_DEMO_ACCOUNTS', defaultValue: false);
bool get showDemoAccounts => _kDemoFlag || !const bool.fromEnvironment('dart.vm.product');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = TextEditingController();
  final _pw = TextEditingController();
  String? _loginErr, _pwErr;
  ApiError? _error;
  bool _busy = false;

  @override
  void dispose() {
    _login.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loginErr = _login.text.trim().length < 3 ? 'Enter your email or phone number' : null;
      _pwErr = _pw.text.isEmpty ? 'Enter your password' : null;
      _error = null;
    });
    if (_loginErr != null || _pwErr != null) return;
    setState(() => _busy = true);
    try {
      await auth.signIn(_login.text.trim(), _pw.text);
    } catch (e) {
      if (mounted) setState(() => _error = toApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editServer() async {
    final ctl = TextEditingController(text: Api.origin);
    final v = await showSheet<String>(
      context,
      Builder(
        builder: (ctx) => SheetScaffold(
          title: 'Server address',
          description: 'Where the ReLoop backend is running.',
          actions: [
            Btn('Reset to default', kind: BtnKind.outline, onPressed: () => Navigator.pop(ctx, '')),
            Btn('Save', onPressed: () => Navigator.pop(ctx, ctl.text)),
          ],
          children: [
            Field(label: 'API origin', hint: 'Android emulator: http://10.0.2.2:8000 · Same computer: http://localhost:8000 · Real phone: http://<your PC\'s Wi-Fi IP>:8000', child: In(ctl, placeholder: 'http://10.0.2.2:8000')),
            const Note(text: 'On a real phone, start the backend with "--host 0.0.0.0" so it accepts connections from your Wi-Fi network.'),
          ],
        ),
      ),
    );
    if (v == null) return;
    await Api.setOrigin(v);
    setState(() {});
    toast('Server set to ${Api.origin}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final e = _error;
    final err = e == null ? null : (e.status == 401 ? (title: 'Sign-in failed', body: 'The email/phone or password is incorrect.') : describeError(e));
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.recycling, color: c.brandFg, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ReLoop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Plastic traceability, procurement and EPR records', style: TextStyle(fontSize: 12, color: c.fg3)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
                  child: AutofillGroup(
                    child: Gap([
                      const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (auth.notice != null && err == null) Note(text: auth.notice),
                      if (err != null) Note(tone: Tone.bad, title: err.title, text: err.body),
                      Field(label: 'Email or phone', error: _loginErr, child: In(_login, autofill: const [AutofillHints.username], hasError: _loginErr != null)),
                      Field(
                        label: 'Password',
                        error: _pwErr,
                        child: In(_pw, obscure: true, autofill: const [AutofillHints.password], hasError: _pwErr != null, onSubmitted: (_) => _submit()),
                      ),
                      Btn('Sign in', large: true, loading: _busy, onPressed: _submit),
                    ]),
                  ),
                ),
                if (showDemoAccounts) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: c.line2), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Local demo accounts (seed data, password '),
                          TextSpan(text: 'reloop123', style: mono(context, size: 12)),
                          const TextSpan(text: ')'),
                        ]),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.fg2),
                      ),
                      const SizedBox(height: 6),
                      for (final d in kDemoAccounts)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() {
                            _login.text = d.$1;
                            _pw.text = 'reloop123';
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
                              Text.rich(TextSpan(children: [
                                TextSpan(text: d.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: ' · ${d.$3}', style: TextStyle(color: c.fg3)),
                              ]), style: const TextStyle(fontSize: 12.5)),
                              Text(d.$1, style: mono(context, size: 11, color: c.fg3)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: _editServer,
                    icon: Icon(Icons.dns_outlined, size: 14, color: c.fg3),
                    label: Text('API: ${Api.origin}', style: TextStyle(fontSize: 11.5, color: c.fg3)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PassportPage extends StatelessWidget {
  final String code;
  const PassportPage({super.key, required this.code});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Material passport',
          description: 'Every recorded stage of this batch, with custody, verification and allocation history.',
          actions: [Btn('Back', icon: Icons.arrow_back, kind: BtnKind.outline, onPressed: () => back(kBase[auth.role] ?? '/'))],
        ),
        PassportView(code: code),
      ]);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final me = auth.me;
    final u = auth.user;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Organisation profile', description: 'Registration details held by ReLoop for your organisation.'),
      QueryView<J>(
        qk: K.myOrg,
        fetch: Api.myOrg,
        builder: (context, o) {
          final profile = jo(o['profile']);
          return RGrid(minWidth: 380, maxCols: 2, gap: 16, children: [
            Panel(
              title: sn(o['legal_name']),
              sub: humanize(o['org_type']),
              actions: [Pill(humanize(o['approval_status']), tone: o['approval_status'] == 'APPROVED' ? Tone.ok : Tone.warn)],
              child: KV([
                KVRow('Display name', o['display_name'] ?? '—'),
                KVRow('City', o['city_id']),
                KVRow('Address', o['address']),
                KVRow('GSTIN', o['gstin'] ?? '—'),
              ]),
            ),
            Panel(
              title: 'Profile details',
              sub: 'Type-specific registration and capacity fields',
              child: (profile == null || profile.isEmpty)
                  ? const Small('No profile details recorded.', size: 13.5)
                  : KV([for (final e in profile.entries) KVRow(humanize(e.key), e.value == null ? '—' : '${e.value}')]),
            ),
            Panel(
              title: 'Your access',
              child: KV([
                KVRow('Name', u?['full_name'] ?? '—'),
                KVRow('Email', u?['email'] ?? '—'),
                KVRow('Role in organisation', me?['active_role'] ?? '—'),
                KVRow('Memberships', jl(me?['memberships']).map((m) => m['org_name']).join(', ')),
              ]),
            ),
          ]);
        },
      ),
    ]);
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        body: 'The address does not match any screen in ReLoop.',
        action: Btn('Go to my workspace', onPressed: () => go(kBase[auth.role] ?? '/')),
      );
}

/// Frontend visibility only; the backend still enforces every permission and returns 403 otherwise.
class UnauthorisedPage extends StatelessWidget {
  final List<String>? needs;
  const UnauthorisedPage({super.key, this.needs});
  @override
  Widget build(BuildContext context) {
    final role = auth.role;
    return EmptyState(
      icon: Icons.gpp_bad_outlined,
      title: 'This area is not available to your organisation',
      body: '${needs != null ? 'It is for ${needs!.map((r) => kRoleLabel[r]).join(' or ')} accounts. ' : ''}You are signed in as ${role != null ? kRoleLabel[role] : 'an account without a role'}.',
      action: role != null ? Btn('Go to my workspace', onPressed: () => go(kBase[role]!)) : Btn('Sign out', onPressed: auth.signOut),
    );
  }
}
