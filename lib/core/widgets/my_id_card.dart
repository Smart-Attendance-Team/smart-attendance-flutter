import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../network/api_client.dart';
import '../storage/session_manager.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Display-only card with the logged-in user's own numbers:
/// - account ID (`userId` from GET /me),
/// - the assignment/enrollment number if one was saved for this account
///   (`staff_id` for lecturers, `student_id` for students).
/// No buttons or editing — view only.
class MyIdCard extends StatefulWidget {
  /// Storage key: 'staff_id' or 'student_id'.
  final String metaKey;

  /// Translated label for the second row.
  final String metaLabel;

  const MyIdCard({
    super.key,
    required this.metaKey,
    required this.metaLabel,
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
    if (session != null) {
      saved = await SessionManager.readMeta(session.email, widget.metaKey);
    }
    return {'uid': uid, 'saved': saved};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _future,
      builder: (context, snapshot) {
        final uid = snapshot.data?['uid'];
        final saved = snapshot.data?['saved'];
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
            ],
          ),
        );
      },
    );
  }
}
