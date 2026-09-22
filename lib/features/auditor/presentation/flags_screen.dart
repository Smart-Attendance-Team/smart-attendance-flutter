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
  final _threshold = TextEditingController(text: '75');
  final _minSessions = TextEditingController(text: '1');
  final _corrections = TextEditingController(text: '3');
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _threshold.dispose();
    _minSessions.dispose();
    _corrections.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final q = <String, dynamic>{};
    final t = num.tryParse(_threshold.text.trim());
    final m = int.tryParse(_minSessions.text.trim());
    final c = int.tryParse(_corrections.text.trim());
    if (t != null) q['threshold'] = t;
    if (m != null) q['min_sessions'] = m;
    if (c != null) q['corrections'] = c;
    final res = await _api.get('/flags', queryParameters: q);
    return ApiClient.asMap(res.data);
  }

  Future<bool> _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('flags')),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                        controller: _threshold,
                        label: tr('f_threshold'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _minSessions,
                        label: tr('f_min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _corrections,
                        label: tr('f_corr'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: tr('apply'),
                  icon: Icons.tune_rounded,
                  onPressed: () => refreshWithToast(context, _reload),
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
                              '${ltr(f['course_code'])} • ${ltr(f['section_name'] ?? '')}',
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
