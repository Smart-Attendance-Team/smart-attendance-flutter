import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../network/api_client.dart';
import '../storage/session_manager.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Display-only card with the logged-in user's own numbers:
/// - account ID (`userId` from GET /me),
/// - the real assignment/enrollment number saved at login
///   (`staff_id` from GET /staff/me for lecturers,
///    `student_id` from GET /students/me for students).
/// No buttons or editing — view only.
class MyIdCard extends StatefulWidget {
  /// Storage key: 'staff_id' or 'student_id'.
  final String metaKey;

  /// Translated label for the second row.
  final String metaLabel;

  /// Optional third row (e.g. student_code).
  final String? extraMetaKey;
  final String? extraMetaLabel;

  const MyIdCard({
    super.key,
    required this.metaKey,
    required this.metaLabel,
    this.extraMetaKey,
    this.extraMetaLabel,
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
    String? uid;
    try {
      final me = await ApiClient().get('/me');
      if (me.data is Map) uid = (me.data as Map)['userId']?.toString();
    } catch (_) {}
    String? saved;
    String? extra;
    if (session != null) {
      saved = await SessionManager.readMeta(session.email, widget.metaKey);
      if (widget.extraMetaKey != null) {
        extra = await SessionManager.readMeta(
          session.email,
          widget.extraMetaKey!,
        );
      }
    }
    return {'uid': uid, 'saved': saved, 'extra': extra};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _future,
      builder: (context, snapshot) {
        final uid = snapshot.data?['uid'];
        final saved = snapshot.data?['saved'];
        final extra = snapshot.data?['extra'];
        final showExtra =
            widget.extraMetaKey != null && widget.extraMetaLabel != null;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tr('my_id')}: ${uid == null ? '…' : ltr(uid)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.metaLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          saved == null ? '—' : ltr(saved),
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
              if (showExtra) ...[
                const Divider(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.tag_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.extraMetaLabel!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          Text(
                            extra == null ? '—' : ltr(extra),
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
