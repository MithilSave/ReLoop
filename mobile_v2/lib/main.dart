import 'package:flutter/material.dart';

import 'app.dart';

/// ReLoop mobile and desktop app. Every screen reads and writes the FastAPI backend; there is no mock data.
///
/// Backend address: set it on the login screen ("API: …"), or at build time with
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReLoopApp());
}
