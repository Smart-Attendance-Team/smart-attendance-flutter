import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_history.dart';
import '../../../core/storage/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';
import 'active_session_screen.dart';
import 'live_roster_screen.dart';

/// Lecturer/TA flow per openapi.yaml:
///  GET /sessions/my-slots -> slots of assigned sections, each with
///   {slot_id, course_code, course_name, section_name, room_name,
///    day_of_week, start_time, end_time, session_id?, session_status?,
///    is_today}
///  POST /sessions/open {slot_id} to open, then show the QR.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _api = ApiClient();
  final _roster = TextEditingController();
  late Future<List<Map<String, dynamic>>> _slotsFuture;
  final Set<int> _opening = {};

  @override
  void initState() {
    super.initState();
    _slotsFuture = _loadSlots();
  }

  @override
  void dispose() {
    _roster.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadSlots() async {
    final list = await _api.getList('/sessions/my-slots');
    return list
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  void _reload() => setState(() => _slotsFuture = _loadSlots());

  Future<void> _open(int slotId) async {
    setState(() => _opening.add(slotId));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('opened_ok', {
                'id': ltr(id),
                'n': ltr(res['roster_count'] ?? '-'),
              }),
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveSessionScreen(
              sessionId: id,
              sessionTitle: '${tr('sessions')} #${ltr(id)}',
            ),
          ),
        ).then((_) => _reload());
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
      if (mounted) setState(() => _opening.remove(slotId));
    }
  }

  void _openRoster(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveRosterScreen(sessionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('sessions')),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('my_slots_hint'),
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _slotsFuture,
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
                    onRetry: _reload,
                  );
                }
                final slots = snapshot.data ?? const [];
                if (slots.isEmpty) {
                  return AppEmpty(message: tr('no_slots'));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: slots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _SlotCard(
                        slot: slots[i],
                        opening: _opening.contains(
                          Format.asInt(slots[i]['slot_id']),
                        ),
                        onOpen: () {
                          final sid = Format.asInt(slots[i]['slot_id']);
                          if (sid != null) _open(sid);
                        },
                        onQr: () {
                          final sessionId =
                              slots[i]['session_id']?.toString();
                          if (sessionId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActiveSessionScreen(
                                  sessionId: sessionId,
                                  sessionTitle:
                                      '${tr('sessions')} #${ltr(sessionId)}',
                                ),
                              ),
                            ).then((_) => _reload());
                          }
                        },
                        onRoster: () {
                          final sessionId =
                              slots[i]['session_id']?.toString();
                          if (sessionId != null) _openRoster(sessionId);
                        },
                      ),
                );
              },
            ),
            const SizedBox(height: 12),
            _HistoryCard(onRoster: _openRoster),
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
                      _openRoster(v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One timetable slot from GET /sessions/my-slots.
class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onQr;
  final VoidCallback onRoster;

  const _SlotCard({
    required this.slot,
    required this.opening,
    required this.onOpen,
    required this.onQr,
    required this.onRoster,
  });

  @override
  Widget build(BuildContext context) {
    final sessionId = slot['session_id']?.toString();
    final sessionStatus = slot['session_status']?.toString();
    final isToday = slot['is_today'] == true;
    final hasOpenSession =
        sessionId != null && sessionStatus == 'open';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ltr(slot['course_code'] ?? '')} • ${slot['course_name'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tr('today'),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${slot['section_name'] ?? ''} • ${slot['room_name'] ?? ''}',
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
            ),
          ),
          Text(
            '${ltr(slot['day_of_week'] ?? '')} • ${ltr(slot['start_time'] ?? '')} – ${ltr(slot['end_time'] ?? '')} • Slot ${ltr(slot['slot_id'] ?? '-')}',
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
          if (sessionId != null) ...[
            const SizedBox(height: 6),
            StatusChip(status: sessionStatus ?? '-'),
          ],
          const SizedBox(height: 12),
          if (hasOpenSession)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: onQr,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    label: Text(tr('open_qr')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: onRoster,
                    icon: const Icon(Icons.groups_rounded, size: 20),
                    label: Text(tr('roster')),
                  ),
                ),
              ],
            )
          else
            AppButton(
              label: tr('open_btn'),
              icon: Icons.play_arrow_rounded,
              loading: opening,
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}

/// Sessions opened from this device by the current user.
class _HistoryCard extends StatelessWidget {
  final void Function(String id) onRoster;
  const _HistoryCard({required this.onRoster});

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
              Text(
                '${tr('my_sessions')} (${items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
