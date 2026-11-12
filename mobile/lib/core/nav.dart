import 'package:flutter/widgets.dart';

import 'query.dart';

/// Path-based navigation, mirroring the web app's routes (/g/listings, /passport/CODE, …).

/// Switch to another screen of the workspace. The stack is replaced, so Back returns to the workspace home.
void go(String path) => navigatorKey.currentState?.pushNamedAndRemoveUntil(path, (_) => false);

/// Open a detail screen on top of the current one (passport, case review).
void push(String path) => navigatorKey.currentState?.pushNamed(path);

/// Close the top screen, or go to [fallback] when there is nothing to return to.
void back(String fallback) {
  final n = navigatorKey.currentState;
  if (n != null && n.canPop()) {
    n.pop();
  } else {
    go(fallback);
  }
}

String passportPath(String code) => '/passport/${Uri.encodeComponent(code)}';

void openPassport(String code) => push(passportPath(code));

/// The current route name, e.g. "/g/listings".
String currentPath(BuildContext context) => ModalRoute.of(context)?.settings.name ?? '/';
