import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../network/api_client.dart';
import '../storage/session_manager.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Display-only card with the single ID that matters for this role
/// (refreshed live from the role profile endpoint on every view):
/// - student  -> `student_id` from GET /students/me (used for enrollment)
/// - lecturer -> `staff_id` from GET /staff/me (used for assignment)
/// For students the level row is shown too. No other IDs are displayed.
class MyIdCard extends StatefulWidget {
  /// 'student_id' or 'staff_id'.
  final String metaKey;

  /// Translated label for the ID row.
  final String metaLabel;

  /// Translated level label, or null to hide the level row (lecturers).
  final String? levelLabel;

  const MyIdCard({
    super.key,
    required this.metaKey,
    required this.metaLabel,
    this.levelLabel,
  });

  @override
  State<MyIdCard> createState() => _MyIdCardState();
}

class _MyIdCardState extends State<MyIdCard> {
  late final Future<Map<String, String?>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, String?>> _load() async {
    final session = await SessionManager.read();
    String? saved;
    String? level;
    if (session != null) {
      saved = await SessionManager.readMeta(session.email, widget.metaKey);
      level = await SessionManager.readMeta(session.email, 'level');
    }
    try {
      final endpoint = widget.metaKey == 'student_id'
          ? '/students/me'
          : '/staff/me';
      final response = await ApiClient().get(endpoint);
      if (response.data is Map) {
        final profile = Map<String, dynamic>.from(response.data as Map);
        final current = profile[widget.metaKey]?.toString();
        if (current != null && current.isNotEmpty) {
          saved = current;
          if (session != null) {
            await SessionManager.saveMeta(
              session.email,
              widget.metaKey,
              current,
            );
          }
        }
        level = profile['level']?.toString();
        if (level != null && level.isNotEmpty) {
          if (session != null) {
            await SessionManager.saveMeta(session.email, 'level', level);
          }
        }
      }
    } catch (_) {
      // Keep the last verified role ID when the profile cannot be refreshed.
    }
    return {'saved': saved, 'level': level};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _future,
      builder: (context, snapshot) {
        final saved = snapshot.data?['saved'];
        final level = snapshot.data?['level'];
        final showLevel = widget.levelLabel != null && level != null;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.metaLabel}: ${saved == null ? '…' : ltr(saved)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (showLevel) ...[
                const Divider(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.levelLabel!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          Text(
                            ltr(level),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
