import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/ui.dart';

/// GET /flags?threshold&min_sessions&corrections
/// Advisory only — never changes attendance. May answer 503.
class FlagsScreen extends StatefulWidget {
  const FlagsScreen({super.key});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await _api.get('/flags');
    return ApiClient.asMap(res.data);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('flags')),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final unavailable =
                err is ApiException && err.statusCode == 503;
            return AppError(
              message: unavailable
                  ? tr('flags_down')
                  : err is ApiException
                      ? err.message
                      : tr('cant_load'),
              onRetry: _reload,
            );
          }
          final flags = ApiClient.asList(snapshot.data?['flags'])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          if (flags.isEmpty) {
            return AppEmpty(
              message: tr('no_flags'),
              icon: Icons.verified_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: flags.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final f = flags[i];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${f['student_name'] ?? ''} (${f['student_code'] ?? ''})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusChip(
                          status: f['type']?.toString() ?? 'flag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f['explanation']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (f['course_code'] != null)
                      Text(
                        '${f['course_code']} • ${f['section_name'] ?? ''}',
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
    );
  }
}
