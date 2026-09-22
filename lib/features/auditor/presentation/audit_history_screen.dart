import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /audit-events?entity_type&action&entity_id&actor_user_id&from&to&limit&offset
/// -> {count, limit, offset, events[]}
class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  final _api = ApiClient();
  final _action = TextEditingController();
  final _entity = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load({});
  }

  @override
  void dispose() {
    _action.dispose();
    _entity.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load(Map<String, dynamic> f) async {
    final res = await _api.get(
      '/audit-events',
      queryParameters: {'limit': 100, ...f},
    );
    return ApiClient.asMap(res.data);
  }

  Future<bool> _apply() {
    final f = <String, dynamic>{};
    if (_action.text.trim().isNotEmpty) f['action'] = _action.text.trim();
    if (_entity.text.trim().isNotEmpty) {
      f['entity_type'] = _entity.text.trim();
    }
    final future = _load(f);
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('audit'))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _action,
                        label: tr('action_f'),
                        hint: 'attendance.manual_update',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _entity,
                        label: tr('entity_f'),
                        hint: 'attendance',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: tr('filter'),
                  icon: Icons.search_rounded,
                  onPressed: () => refreshWithToast(context, _apply),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }
                if (snapshot.hasError) {
                  final err = snapshot.error;
                  return AppError(
                    message: err is ApiException
                        ? err.message
                        : tr('cant_load'),
                    onRetry: _apply,
                  );
                }
                final events = ApiClient.asList(snapshot.data?['events'])
                    .whereType<Map>()
                    .map(Map<String, dynamic>.from)
                    .toList();
                if (events.isEmpty) {
                  return AppEmpty(message: tr('no_audit'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['action']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ltr(e['entity_type'] ?? '')}'
                            '${e['entity_id'] != null ? ' #${ltr(e['entity_id'])}' : ''}'
                            ' • ${ltr(e['actor_email'] ?? '?')} (${ltr(e['actor_role'] ?? '')})',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            ltr(Format.date(e['created_at']?.toString())),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
