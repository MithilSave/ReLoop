import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const ReLoopApp(),
    ),
  );
}

class ReLoopApp extends StatelessWidget {
  const ReLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReLoop Circular Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeShell(),
    );
  }
}
