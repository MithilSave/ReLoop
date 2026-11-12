import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/demo_data.dart';
import '../theme/app_theme.dart';

class PersonaSelectorSheet extends StatelessWidget {
  const PersonaSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PersonaSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final activeId = state.currentPersona.id;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Switch Participant Role',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                    ),
                    Text(
                      'Experience live closed-loop traceability across all 5 roles',
                      style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: demoPersonas.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final p = demoPersonas[i];
                  final isSel = p.id == activeId;

                  return InkWell(
                    onTap: () {
                      state.setPersona(p.id);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryLight : AppTheme.slate50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppTheme.primary
                              : AppTheme.slate200,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.slate200),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p.avatar,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSel
                                            ? AppTheme.primaryDark
                                            : AppTheme.slate900,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppTheme.slate300),
                                      ),
                                      child: Text(
                                        p.orgTypeLabel,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.slate700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.orgName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.slate700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.slate500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Padding(
                              padding: EdgeInsets.only(left: 8, top: 10),
                              child: Icon(Icons.check_circle,
                                  color: AppTheme.primary, size: 18),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
