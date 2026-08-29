import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../locator.dart';
import '../models.dart';

/// ═══════════════════════════════════════════════════════════════
/// البورد اللايف (٢٨/٨/٢٠٢٦) — فريق المدير لحظة بلحظة على الموبايل
/// ═══════════════════════════════════════════════════════════════
///
/// نفس داتا الشاشة اللايف في الـERP (`apiLive` → `liveRows` بنفس
/// حارس `fieldVisibleTo`): لكل مندوب حالته وشغله ومبيعاته وعهدته
/// وآخر إشارة — وعربية iTrack بتاعته لو مربوطة، مع إنذار «بعيد عن
/// العربية».
///
/// ⚠️ مفيش خرائط مضمنة في الأبلكيشن (سياسة صفر باكدجات) — زرار 🗺
/// بيفتح موقع المندوب/العربية على جوجل مابس بره، زي كل الشاشات.
class LiveBoardScreen extends StatefulWidget {
  const LiveBoardScreen({super.key});

  @override
  State<LiveBoardScreen> createState() => _LiveBoardScreenState();
}

class _LiveBoardScreenState extends State<LiveBoardScreen> {
  List<Map<String, dynamic>> _rows = [];
  String _at = '';
  bool _loaded = false;
  String? _err;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // رفرش لوحده كل دقيقة — نفس إيقاع شاشة الويب تقريباً
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.managerLive();
      if (!mounted) return;
      setState(() {
        _rows = ((d['rows'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _at = '${d['at'] ?? ''}';
        _loaded = true;
        _err = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _err = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _err = L.t('server_down');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('lv_title')),
        actions: [
          if (_at.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Text('🕐 $_at', style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _err != null
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Center(child: Text(_err!)),
                      Center(
                          child: TextButton(
                              onPressed: _load, child: Text(L.t('retry')))),
                    ])
                  : _rows.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Center(child: Text(L.t('lv_none'))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _rows.length,
                          itemBuilder: (context, i) => _RepLiveCard(
                              row: _rows[i]),
                        ),
            ),
    );
  }
}

class _RepLiveCard extends StatelessWidget {
  const _RepLiveCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final work = '${r['work']}';
    final liveState = '${r['live_state']}';

    // لون الحالة: شغال أخضر · بريك برتقاني · مفيش إشارة رمادي ·
    // مش حاضر أحمر باهت
    final (dotColor, stateText) = switch (work) {
      'in' => liveState == 'live'
          ? (const Color(0xFF16A34A), L.t('lv_working'))
          : (const Color(0xFFB86E00), L.t('lv_no_signal')),
      'break' => (const Color(0xFFEA8C1C), L.t('lv_break')),
      'out' => (Colors.grey, L.t('lv_left')),
      _ => (const Color(0xFFDC2626), L.t('lv_absent')),
    };

    final van = r['van'] is Map
        ? Map<String, dynamic>.from(r['van'] as Map)
        : null;
    final vanFar = van?['far'] == true;

    final lat = r['lat'], lng = r['lng'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundImage: r['avatar_url'] != null
                          ? NetworkImage('${r['avatar_url']}')
                          : null,
                      child: r['avatar_url'] == null
                          ? Text(
                              '${r['name']}'.isEmpty ? '؟' : '${r['name']}'[0])
                          : null,
                    ),
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text(
                        '$stateText'
                        '${r['signal_at'] != null ? ' • ${r['signal_at']}' : ''}'
                        '${r['open_client'] != null ? ' • 🏪 ${r['open_client']}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (lat != null && lng != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: L.t('lv_open_map'),
                    onPressed: () => Locator.openUrl(
                        'https://www.google.com/maps?q=$lat,$lng'),
                    icon: const Icon(Icons.map_outlined,
                        color: Color(0xFF2563EB)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ═══ أرقام اليوم ═══
            Row(
              children: [
                _cell(L.t('lv_sales'), money((r['sales_today'] as num?)?.toDouble() ?? 0)),
                _cell(L.t('lv_visits'), '${r['visits_today'] ?? 0}'),
                _cell(L.t('lv_pos'), '${r['pos_today'] ?? 0}'),
                _cell(L.t('lv_custody'),
                    money((r['remaining_value'] as num?)?.toDouble() ?? 0)),
              ],
            ),

            // ═══ العربية (iTrack) ═══
            if (van != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: vanFar
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(vanFar ? '🚨' : '🚚',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        vanFar
                            ? '${L.t('lv_van_far')} — ${van['gap_km'] ?? '?'} ${L.t('lv_km')}'
                            : '${van['plate'] ?? ''} • ${van['time'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                vanFar ? FontWeight.w800 : FontWeight.w600,
                            color: vanFar
                                ? const Color(0xFFDC2626)
                                : Colors.grey.shade700),
                      ),
                    ),
                    if (van['lat'] != null && van['lng'] != null)
                      GestureDetector(
                        onTap: () => Locator.openUrl(
                            'https://www.google.com/maps?q=${van['lat']},${van['lng']}'),
                        child: const Icon(Icons.map_outlined,
                            size: 17, color: Color(0xFF0F766E)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String v) {
    return Expanded(
      child: Column(
        children: [
          Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          Text(label,
              maxLines: 1,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
