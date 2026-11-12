import 'package:flutter/foundation.dart';

import 'api.dart';
import 'query.dart';
import 'roles.dart';

enum AuthStatus { loading, anonymous, authenticated }

/// Session state. The backend remains the authority on every permission.
class AuthController extends ChangeNotifier {
  AuthStatus status = AuthStatus.loading;
  J? me;

  /// Why the user is on the login screen, e.g. session expiry.
  String? notice;

  String? get role => me == null ? null : roleOf(me!);
  J? get user => jo(me?['user']);
  J? get org => jo(me?['active_org']);

  Future<void> start() async {
    await Api.init();
    Api.onSessionExpired = _expired;
    if (Api.access == null) {
      status = AuthStatus.anonymous;
      notifyListeners();
      return;
    }
    await _loadMe();
  }

  Future<J?> _loadMe() async {
    try {
      final m = await Api.me();
      me = m;
      status = AuthStatus.authenticated;
      notifyListeners();
      return m;
    } catch (_) {
      await Api.clearTokens();
      me = null;
      status = AuthStatus.anonymous;
      notifyListeners();
      return null;
    }
  }

  void _expired() {
    if (status == AuthStatus.anonymous) return;
    queryBus.clear();
    me = null;
    status = AuthStatus.anonymous;
    notice = 'Your session has ended. Sign in again to continue.';
    notifyListeners();
  }

  /// Throws [ApiError] when the credentials are refused or the server is unreachable.
  Future<String?> signIn(String login, String password) async {
    final res = await Api.login(login, password);
    await Api.setTokens(res['access_token'].toString(), res['refresh_token'].toString());
    queryBus.clear();
    notice = null;
    final m = await _loadMe();
    return m == null ? null : roleOf(m);
  }

  /// Quick role switcher for testing and demos across all 6 participants
  Future<String?> switchRole(String roleName) async {
    final email = '$roleName@reloop.in';
    return await signIn(email, 'reloop123');
  }

  Future<void> signOut() async {
    final rt = Api.refresh;
    try {
      if (rt != null) await Api.logout(rt);
    } catch (_) {
      // Token already invalid: nothing to revoke.
    }
    await Api.clearTokens();
    queryBus.clear();
    me = null;
    status = AuthStatus.anonymous;
    notice = 'You have signed out.';
    notifyListeners();
  }
}

final AuthController auth = AuthController();
