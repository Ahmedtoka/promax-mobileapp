import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../locator.dart';
import 'lead_confirm.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// تاب «العملاء المحتملين» (بايبلاين ٢٦/٨ — مرحلة ٣)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب بيشوف ليداته بالمناطق (زي تاب المناطق)، ومن كارت الليد:
/// اتصال · اتجاهات · **تأكيد البيانات** (النقطة الأولى) · تحديث
/// الحالة · **افتح أكاونت** — بيفتح فورم طلب العميل الجديد متملي
/// بمرساة الليد، والاعتماد بيقفله «كسبناه» (النقطة التانية).
///
/// ⚠️ الليد مش عميل: مفيش بيع ولا زيارة عليه — بورد المكتب ستايل:
/// الشاشة بتنادي Api.I مباشرة وبتدير التحميل بنفسها.
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _zones = const [];
  List<Map<String, dynamic>> _today = const [];
  Map<String, dynamic> _counts = const {};

  static const _stColor = {
    'new': Color(0xFF2563EB),
    'contacted': Color(0xFF6B7280),
    'visited': Color(0xFF7C3AED),
    'negotiating': Color(0xFFB45309),
    'won': Color(0xFF0F7A38),
    'lost': Color(0xFFDC2626),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ترتيب المسافة (٦/٩): نبعت مكان المندوب فالسيرفر يرتب الليدات
      // «الأقرب فالأقرب». فشل الـGPS مش بيوقف الشاشة — الترتيب القديم.
      final pos = await Locator.get();
      final res = await Api.I.myLeads(lat: pos?.$1, lng: pos?.$2);
      if (!mounted) return;
      setState(() {
        _zones = (res['zones'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _today = (res['today'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _counts = Map<String, dynamic>.from((res['counts'] ?? const {}) as Map);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('leads_title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),

                  // ═══ سامري فوق: مفتوح · اتأكد · كسبتهم الشهر ده ═══
                  Row(children: [
                    Expanded(
                        child: Kpi(
                            title: L.t('lead_open_n'),
                            value: '${_counts['open'] ?? 0}',
                            icon: Icons.flag_outlined,
                            color: const Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Kpi(
                            title: L.t('lead_confirmed_n'),
                            value: '${_counts['confirmed'] ?? 0}',
                            icon: Icons.verified_outlined,
                            color: const Color(0xFF7C3AED))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Kpi(
                            title: L.t('lead_won_month'),
                            value: '${_counts['won_month'] ?? 0}',
                            icon: Icons.emoji_events_outlined,
                            color: const Color(0xFF0F7A38))),
                  ]),
                  const SizedBox(height: 12),

                  // ═══ 📅 مجدولين النهارده — خطة المدير بترتيبها ═══
                  if (_today.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Brand.royalBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Brand.royalBlue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.event_available,
                                size: 18, color: Brand.royalBlue),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(L.t('lead_today_title'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Chip2(
                                text: '${_today.length}',
                                color: Brand.royalBlue),
                          ]),
                          const SizedBox(height: 8),
                          for (var i = 0; i < _today.length; i++)
                            _leadCard(_today[i], order: i + 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_zones.isEmpty && _today.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text(L.t('lead_none'),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: Colors.grey))),
                    ),

                  // ═══ المناطق — كل منطقة وليداتها ═══
                  for (final z in _zones) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.place_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text('${z['zone'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        Chip2(
                            text: '${(z['leads'] as List? ?? const []).length}',
                            color: Brand.royalBlue),
                      ]),
                    ),
                    for (final raw in (z['leads'] as List? ?? const []))
                      _leadCard(Map<String, dynamic>.from(raw as Map)),
                  ],
                ],
              ),
      ),
    );
  }

  /// مسافة مقروءة: 850 م / 1.2 كم — بمفاتيح اللغتين
  String _distTxt(dynamic m) {
    final v = (m is num) ? m.toDouble() : double.tryParse('$m') ?? 0;

    return v < 1000
        ? '${v.round()} ${L.t('unit_m')}'
        : '${(v / 1000).toStringAsFixed(1)} ${L.t('unit_km')}';
  }

  Widget _leadCard(Map<String, dynamic> l, {int? order}) {
    final st = '${l['status'] ?? 'new'}';
    final c = _stColor[st] ?? const Color(0xFF2563EB);
    final confirmed = l['confirmed'] == true;
    final won = st == 'won';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: won ? null : () => _openActions(l),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (order != null) ...[
                  CircleAvatar(
                      radius: 11,
                      backgroundColor: Brand.royalBlue,
                      child: Text('$order',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: Text('${l['name'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14))),
                Chip2(text: L.t('lead_st_$st'), color: c),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                // ليبل المسافة (٦/٩): الأقرب ليك / على بعد كذا من اللي قبله
                if (l['near'] == 'first')
                  Text(
                      '📍 ${L.t('lead_nearest')}'
                      '${l['dist_m'] != null ? ' • ${_distTxt(l['dist_m'])}' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF12399B),
                          fontWeight: FontWeight.w800)),
                if (l['near'] == 'next' && l['dist_m'] != null)
                  Text(
                      '↔ ${L.t('lead_dist_prev', {'n': _distTxt(l['dist_m'])})}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w700)),
                if ((l['category'] ?? '') != '')
                  Text('🏷 ${l['category']}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('⚡ ${L.t('lead_score')}: ${l['score'] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (confirmed)
                  Text('✓ ${L.t('lead_confirmed_chip')}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F7A38),
                          fontWeight: FontWeight.w700)),
              ]),
              if ((l['address'] ?? '') != '') ...[
                const SizedBox(height: 4),
                Text('📍 ${l['address']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// أكشنات الليد (فلو ٢٦/٨): ٣ أزرار — اتجاهات · تأكيد البيانات ·
  /// تأكيد وفتح العميل. التليفون في الهيدر بيتصل بضغطة، وتحديث
  /// الحالة سطر صغير تحت (بنتفاوض/خسرناه لسه محتاجينهم).
  void _openActions(Map<String, dynamic> l) {
    final phone = '${l['phone'] ?? ''}'.trim();
    final lat = l['lat'];
    final lng = l['lng'];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${l['name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: phone.isEmpty
                  ? Text('${l['number'] ?? ''}')
                  : Text('📞 $phone', textDirection: TextDirection.ltr),
              onTap: phone.isEmpty
                  ? null
                  : () {
                      Navigator.of(sheetCtx).pop();
                      Locator.openUrl('tel:$phone');
                    },
            ),
            const Divider(height: 1),

            // ═══ ١) الاتجاهات — بيفتح اللوكيشن ═══
            if (lat != null && lng != null)
              ListTile(
                leading:
                    const Icon(Icons.directions_outlined, color: Brand.royalBlue),
                title: Text(L.t('lead_directions'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Locator.openUrl(
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                },
              ),

            // ═══ ٢) تأكيد البيانات — شاشة زي تسجيل العميل ═══
            ListTile(
              leading: const Icon(Icons.verified_outlined,
                  color: Color(0xFF7C3AED)),
              title: Text(L.t('lead_confirm_btn'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(L.t('lead_confirm_hint'),
                  style: const TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LeadConfirmScreen(lead: l)));
                _load();
              },
            ),

            // ═══ ٣) تأكيد وفتح العميل — أكاونت فوري وبيع على طول ═══
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined,
                  color: Color(0xFF0F7A38)),
              title: Text(L.t('lead_confirm_open_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(L.t('lead_confirm_open_hint'),
                  style: const TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        LeadConfirmScreen(lead: l, openAccount: true)));
                _load();
              },
            ),

            // تحديث الحالة — سطر صغير: بنتفاوض/خسرناه
            TextButton(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _statusSheet(l);
              },
              child: Text(L.t('lead_status'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// تحديث الحالة — اتكلمنا / بنتفاوض / خسرناه بسبب
  void _statusSheet(Map<String, dynamic> l) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final st in const ['contacted', 'negotiating', 'lost'])
              ListTile(
                leading: Icon(Icons.circle, size: 14, color: _stColor[st]),
                title: Text(L.t('lead_st_$st')),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();

                  String? reason;
                  if (st == 'lost') {
                    reason = await _askLostReason();
                    if (reason == null || reason.trim().isEmpty) return;
                  }

                  try {
                    await Api.I.leadSetStatus((l['id'] as num).toInt(), st,
                        lostReason: reason);
                    if (!mounted) return;
                    snack(context, L.t('lead_saved'));
                    _load();
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    snack(context, e.message, bad: true);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askLostReason() {
    final c = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(L.t('lead_lost_reason')),
        content: TextField(controller: c, autofocus: true, maxLines: 2),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).maybePop(),
              child: Text(L.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(dlgCtx).pop(c.text),
              child: Text(L.t('save'))),
        ],
      ),
    );
  }
}
