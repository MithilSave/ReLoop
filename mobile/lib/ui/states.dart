import 'package:flutter/material.dart';

import '../core/api.dart';
import 'theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? action;
  final IconData icon;
  const EmptyState({super.key, required this.title, this.body, this.action, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 26, color: c.fg3),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: c.fg)),
            if (body != null) ...[
              const SizedBox(height: 3),
              Text(body!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.fg2)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final ApiError error;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = describeError(error);
    final icon = error.status == 0 ? Icons.wifi_off : error.status == 403 ? Icons.gpp_bad_outlined : Icons.warning_amber_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 26, color: c.bad),
            const SizedBox(height: 8),
            Text(d.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(d.body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.fg2)),
            if (error.status > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${error.status} · ${error.code}', style: TextStyle(fontFamily: kMono, fontFamilyFallback: kMonoFallback, fontSize: 11, color: c.fg3)),
              ),
            if (onRetry != null && error.status != 403) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
            ],
          ]),
        ),
      ),
    );
  }
}

class LoadingRows extends StatelessWidget {
  final int rows;
  const LoadingRows({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            rows,
            (i) => Container(
              height: 14,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }
}
