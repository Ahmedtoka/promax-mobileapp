import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import 'office_home.dart' show OfficeBoardHeader;
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// أوامر التجهيز لأمين المخزن (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// الأمين بيشوف أوامر **مخازنه** على موبايله: يبدأ التجهيز، يعدّ،
/// ويعلّم «جاهز» — والمندوب بيوصله إشعار «تعالى استلم» أوتوماتيك
/// (من `PickOrder::markReady` في السيرفر).
///
/// ⚠️ **ويدجت جسم مش Scaffold** — بتتحط جوه `OfficeHome` اللي عنده
/// AppBar بتاعه. أول نسخة من شاشة الأمين اتشالت عشان بالظبط مشكلة
/// الـ«أب-بارين فوق بعض» دي (موثّقة في `office_home.dart`).
class KeeperPicksBoard extends StatefulWidget {
  const KeeperPicksBoard({super.key});

  @override
  State<KeeperPicksBoard> createState() => _KeeperPicksBoardState();
}

class _KeeperPick {
  final int id;
  final String number;
  final String? warehouse;
  final String status;
  final String statusLabel;
  final String? purposeLabel;
  final String? rep;
  final String? poClient;
  final int qtyRequested;
  final bool canStart;
  final bool canReady;
  final List<Map<String, dynamic>> items;

  _KeeperPick.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        warehouse = j['warehouse']?.toString(),
        status = j['status'] ?? '',
        statusLabel = j['status_label']?.toString() ?? '',
        purposeLabel = j['purpose_label']?.toString(),
        rep = j['rep']?.toString(),
        poClient = j['po_client']?.toString(),
        qtyRequested = (j['qty_requested'] as num?)?.toInt() ?? 0,
        canStart = j['can_start'] == true,
        canReady = j['can_ready'] == true,
        items = ((j['items'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

  Color get color => switch (status) {
        'requested' => const Color(0xFFB86E00),
        'picking' => const Color(0xFF2563EB),
        'ready' => const Color(0xFF16A34A),
        _ => const Color(0xFF6B6B7B),
      };
}

class _KeeperPicksBoardState extends State<KeeperPicksBoard> {
  List<_KeeperPick> _picks = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// false = المفتوح، true = هيستوري (المُسلَّم) — الإندبوينت كان
  /// بيدعم `?history=1` من الأول ومحدش بينده عليه (تدقيق ٩/٨)
  bool _history = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.keeperPicks(history: _history);
      if (!mounted) return;
      setState(() {
        _picks = ((res['picks'] ?? []) as List)
            .map((e) => _KeeperPick.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// «جاهز» بالكميات الفعلية — كل صنف خانة مبدوءة بالمطلوب
  Future<void> _readyDialog(_KeeperPick p) async {
    if (p.items.isEmpty) {
      await _action(() => Api.I.keeperReady(p.id));
      return;
    }
    final ctrls = <int, TextEditingController>{};
    for (final it in p.items) {
      final id = (it['id'] as num?)?.toInt();
      if (id == null) continue;
      ctrls[id] = TextEditingController(text: '${it['qty_requested'] ?? 0}');
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('keeper_ready_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(L.t('keeper_ready_hint'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                for (final it in p.items)
                  if (ctrls.containsKey((it['id'] as num?)?.toInt()))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${it['name'] ?? ''}',
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text('/ ${it['qty_requested'] ?? 0}',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade600)),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: ctrls[(it['id'] as num).toInt()],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).maybePop(false),
              child: Text(L.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).maybePop(true),
              child: Text(L.t('keeper_confirm_ready'))),
        ],
      ),
    );
    final items = <Map<String, dynamic>>[];
    var bad = false;
    ctrls.forEach((id, c) {
      final q = int.tryParse(c.text.trim());
      if (q == null || q < 0) bad = true;
      items.add({'id': id, 'qty': q ?? 0});
      c.dispose();
    });
    if (ok != true) return;
    if (bad) {
      snack(context, L.t('keeper_qty_invalid'), bad: true);
      return;
    }
    await _action(() => Api.I.keeperReady(p.id, items));
  }

  Future<void> _action(Future<Map<String, dynamic>> Function() fn) async {
    setState(() => _busy = true);
    try {
      final res = await fn();
      if (!mounted) return;
      final msg = res['message']?.toString();
      if (msg != null && msg.isNotEmpty) snack(context, msg);
      await _load();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message, bad: true);
    } catch (e) {
      if (mounted) snack(context, L.t('error_with', {'e': '$e'}), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchTab(bool history) {
    if (_history == history) return;
    setState(() {
      _history = history;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _list();

    return OfficeBoardHeader(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                          value: false, label: Text(L.t('keeper_open_tab'))),
                      ButtonSegment(
                          value: true, label: Text(L.t('keeper_history_tab'))),
                    ],
                    selected: {_history},
                    onSelectionChanged: (s) => _switchTab(s.first),
                  ),
                ),
              ],
            ),
          ),
          // ⚠️ بروجرس **واحد** فوق القايمة — كان جوه كل كارت فبيبان
          // N شريط لأكشن واحد (تدقيق ٩/٨)
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _error != null
          ? ListView(children: [
              const SizedBox(height: 120),
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L.t('error_with', {'e': '$_error'}),
                    textAlign: TextAlign.center),
              )),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(L.t('retry')),
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
              ),
            ])
          : _picks.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 140),
                  Icon(Icons.inventory_2_outlined,
                      size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Center(
                      child: Text(L.t('keeper_no_picks'),
                          style: TextStyle(color: Colors.grey.shade600))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _picks.length,
                  itemBuilder: (_, i) => _card(_picks[i]),
                ),
    );
  }

  Widget _card(_KeeperPick p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${p.number} · ${p.purposeLabel ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                Chip2(text: p.statusLabel, color: p.color),
              ],
            ),
            const SizedBox(height: 6),
            if (p.rep != null)
              InfoRow(
                  icon: Icons.person_outline,
                  text: '${L.t('keeper_for_rep')}: ${p.rep}'),
            if (p.poClient != null)
              InfoRow(
                  icon: Icons.storefront_outlined,
                  text: '${L.t('keeper_for_client')}: ${p.poClient}'),
            InfoRow(
                icon: Icons.numbers,
                text:
                    '${L.t('keeper_qty')}: ${p.qtyRequested} ${L.t('unit_piece')}'),

            // ═══ البنود — الأمين بيجهّز منها ═══
            if (p.items.isNotEmpty) ...[
              const Divider(height: 18),
              for (final it in p.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${it['name'] ?? ''}'
                          '${it['location'] != null ? ' — ${it['location']}' : ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Text('${it['qty_requested'] ?? 0}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 10),
            if (p.canStart)
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                label: Text(L.t('keeper_start_prep')),
                onPressed:
                    _busy ? null : () => _action(() => Api.I.keeperStart(p.id)),
              ),
            if (p.canReady)
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: const Color(0xFF16A34A),
                ),
                label: Text(L.t('keeper_mark_ready')),
                // الكميات الفعلية من الموبايل (٢٥/٩): ديالوج بكل صنف
                // وكميته المطلوبة، الأمين يقلّل لو الرف ناقص، والسيرفر
                // بيسجّل النقص (`markReady` بياخد `items[id => qty]`)
                onPressed: _busy ? null : () => _readyDialog(p),
              ),
            if (p.status == 'ready')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(L.t('keeper_waiting_pickup'),
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
    );
  }
}
