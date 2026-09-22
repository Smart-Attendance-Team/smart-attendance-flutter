import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// POST /corrections {attendance_id, requested_status, reason}
/// GET /corrections/mine -> own requests.
class CorrectionRequestScreen extends StatefulWidget {
  const CorrectionRequestScreen({super.key});

  @override
  State<CorrectionRequestScreen> createState() =>
      _CorrectionRequestScreenState();
}

class _CorrectionRequestScreenState extends State<CorrectionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _attendanceId = TextEditingController();
  final _reason = TextEditingController();
  final _evidence = TextEditingController();
  final _api = ApiClient();
  String _status = 'present';
  bool _sending = false;
  late Future<List<dynamic>> _mine;

  @override
  void initState() {
    super.initState();
    _mine = _api.getList('/corrections/mine');
  }

  @override
  void dispose() {
    _attendanceId.dispose();
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<bool> _refreshMine() {
    final future = _api.getList('/corrections/mine');
    setState(() {
      _mine = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final evidence = _evidence.text.trim();
      await _api.postMap(
        '/corrections',
        data: {
          'attendance_id': int.parse(_attendanceId.text.trim()),
          'requested_status': _status,
          'reason': _reason.text.trim(),
          if (evidence.isNotEmpty) 'evidence_url': evidence,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('req_sent'))),
      );
      _reason.clear();
      setState(() {
        _mine = _api.getList('/corrections/mine');
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('corr')),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _refreshMine),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('new_request'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      controller: _attendanceId,
                      label: tr('nm_attendance'),
                      hint: tr('from_att'),
                      helper: tr('h_attendance_id'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      prefixIcon: Icons.tag_rounded,
                      validator: (v) => Validators.number(v, 'nm_attendance'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: tr('req_status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'present',
                          child: Text(tr('st_present')),
                        ),
                        DropdownMenuItem(
                          value: 'excused',
                          child: Text(tr('st_excused')),
                        ),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'present'),
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      controller: _reason,
                      label: tr('nm_reason'),
                      hint: tr('why'),
                      maxLines: 3,
                      validator: (v) => Validators.min(v, 3, 'nm_reason'),
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      controller: _evidence,
                      label: tr('evidence_url'),
                      hint: 'https://…',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: tr('submit_req'),
                      icon: Icons.send_rounded,
                      loading: _sending,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
            SectionBar(title: tr('my_requests')),
            FutureBuilder<List<dynamic>>(
              future: _mine,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }
                if (snapshot.hasError) {
                  return Text(
                    tr('cant_load'),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  );
                }
                final items = (snapshot.data ?? const [])
                    .whereType<Map>()
                    .map(Map<String, dynamic>.from)
                    .toList();
                if (items.isEmpty) {
                  return Text(
                    tr('no_requests'),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${ltr(r['attendance_id'])} → ${trStatus(r['requested_status']?.toString() ?? '')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r['reason'] ?? ''} • ${ltr(Format.dateShort(r['created_at']?.toString()))}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                                if (r['review_reason'] != null &&
                                    '${r['review_reason']}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      tr('review_by', {
                                        'r': '${r['review_reason']}',
                                      }),
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusChip(
                            status:
                                r['status']?.toString() ?? 'pending',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
