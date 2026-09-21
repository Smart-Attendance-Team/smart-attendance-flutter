import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_history.dart';
import '../../../core/storage/session_manager.dart';
import '../../../core/widgets/ui.dart';
import 'active_session_screen.dart';
import 'live_roster_screen.dart';

/// POST /sessions/open {slot_id} -> {session_id, ...}
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _api = ApiClient();
  final _slot = TextEditingController();
  final _roster = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _slot.dispose();
    _roster.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final slotId = int.tryParse(_slot.text.trim());
    if (slotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bad_slot'))),
      );
      return;
    }
    setState(() => _opening = true);
    try {
      final res = await _api.postMap(
        '/sessions/open',
        data: {'slot_id': slotId},
      );
      final id = res['session_id']?.toString() ?? res['id']?.toString() ?? '';
      if (id.isEmpty) throw ApiException(tr('no_sid'));
      final email = (await SessionManager.read())?.email ?? '';
      if (email.isNotEmpty) {
        await SessionHistory.add(email: email, id: id, title: 'Session #$id');
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveSessionScreen(
              sessionId: id,
              sessionTitle: '${tr('sessions')} #${ltr(id)}',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('sessions'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('open_session'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('open_hint'),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _slot,
                  label: tr('slot_id'),
                  hint: 'e.g. 5',
                  helper: tr('h_slot_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.schedule_rounded,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: tr('open_btn'),
                  icon: Icons.play_arrow_rounded,
                  loading: _opening,
                  onPressed: _open,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MySessionsCard(api: _api),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('join_session'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _roster,
                  label: tr('nm_session'),
                  hint: 'e.g. 12',
                  helper: tr('h_session_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.groups_rounded,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: tr('view_roster'),
                  icon: Icons.visibility_rounded,
                  outlined: true,
                  onPressed: () {
                    final v = _roster.text.trim();
                    if (v.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('need_sid'))),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveRosterScreen(sessionId: v),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sessions opened from this device by the current user,
/// with the session number used to re-open its QR/roster.
class _MySessionsCard extends StatelessWidget {
  final ApiClient api;
  const _MySessionsCard({required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OpenedSession>>(
      future: Future(() async {
        final s = await SessionManager.read();
        if (s == null) return const <OpenedSession>[];
        return SessionHistory.list(s.email);
      }),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <OpenedSession>[];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr('my_sessions')} (${items.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr('tap_qr'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (items.isEmpty)
                Text(
                  tr('no_sessions_yet'),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${ltr(s.id)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      title: Text(
                        s.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveSessionScreen(
                            sessionId: s.id,
                            sessionTitle: s.title,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
