import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';

const _bad = Color(0xFFB00020);
const _purple = Color(0xFF602D90);
const _purpleBg = Color(0xFFF1EAFD);
const _greenBg = Color(0xFFE7F6EC);
const _green = Color(0xFF0F9D58);

/// ═══════════════════════════════════════════════════════════════
/// الهدايا — المندوب بيسجّل اداها لمين
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **من غير الشاشة دي، «صرفنا 200 عينة» رقم مالوش تفصيل.** السؤال
/// اللي بيتسأل بعد أي حملة هو «اداها لمين»، والإجابة لازم تكون صف
/// لكل توزيعة مش عدّاد.
///
/// ⚠️ **الباقي لازم يوصل صفر قبل قفل العهدة.** الهدية اللي مااتوزّعتش
/// ومارجعتش المخزن هي بضاعة ضايعة مسجّلة كأنها اتصرفت تسويق.
///
/// المستلم ممكن يكون: عميل من عملائه، **طلب عميل جديد** (تحت الموافقة
/// أو اتوافق عليه ولسه ماتحوّلش)، أو توزيع عام. ولو الشاشة اتفتحت من
/// جوه زيارة، العميل بيبقى محدد سلفاً والهدية بتتربط بالزيارة.
class GiftsScreen extends StatefulWidget {
  /// عميل محدد سلفاً — لما الشاشة تتفتح من صفحة العميل/الزيارة
  final int? presetClientId;
  final String? presetClientName;
  final int? visitId;

  const GiftsScreen(
      {super.key, this.presetClientId, this.presetClientName, this.visitId});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

/// المستلم المختار — واحد من التلاتة
class _Recipient {
  final int? clientId;
  final int? requestId;
  final String label;

  const _Recipient.none() : clientId = null, requestId = null, label = '';
  const _Recipient.client(int this.clientId, this.label) : requestId = null;
  const _Recipient.request(int this.requestId, this.label) : clientId = null;

  bool get isGeneral => clientId == null && requestId == null;
}

class _GiftsScreenState extends State<GiftsScreen> {
  bool _loading = true;
  String? _error;
  List _items = [];
  List _handouts = [];

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

    // ⚠️ **`Api` بترمي `ApiException` مش بترجّع نتيجة فيها `ok`.**
    // ده نمط كل الشاشات التانية — والخروج عنه بيخلّي أخطاء الشبكة
    // تعدّي من غير ما تتعرض للمندوب.
    try {
      final d = await Api.I.get('/gifts');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _items = (d['items'] ?? []) as List;
        _handouts = (d['handouts'] ?? []) as List;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(L.t('gifts'))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  // viewPadding صريح (مسح ٢١/٨)
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.viewPaddingOf(context).bottom),
                  children: [
                    if (_error != null)
                      Card(
                        color: const Color(0xFFFDECEC),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFB00020))),
                        ),
                      ),

                    if (_items.isEmpty && _error == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(L.t('no_gifts'),
                              style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),

                    ..._items.map(_giftCard),

                    if (_handouts.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(L.t('gift_history'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._handouts.map(_historyRow),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _giftCard(dynamic i) {
    final left = (i['left'] ?? 0) as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text('${i['code'] ?? ''} • ${i['unit'] ?? ''}',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // ⚠️ الباقي هو الرقم اللي بيهم — الموزّع تاريخ،
                // والباقي مسؤولية لسه على المندوب.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: left > 0
                        ? _purpleBg
                        : _greenBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${L.t('gift_left')} $left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: left > 0
                          ? _purple
                          : _green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${L.t('gift_given')} ${i['given'] ?? 0} / ${i['assigned'] ?? 0}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            if (left > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _record(i),
                  icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                  label: Text(L.t('record_handout')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyRow(dynamic h) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.card_giftcard_outlined, size: 18),
          title: Text('${h['product'] ?? ''} × ${h['qty'] ?? 0}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(h['client'] ?? '—',
              style: const TextStyle(fontSize: 11.5)),
        ),
      );

  /// اختيار المستلم — عملاؤه + طلباته الجديدة + توزيع عام
  Future<_Recipient?> _pickRecipient() async {
    final clients = <Client>[
      for (final z in Session.I.zones) ...z.clients,
    ];
    // ⚠️ الطلبات المرفوضة برضه بتظهر؟ لأ — هدية لطلب مرفوض ملهاش معنى
    final requests = Session.I.requests
        .where((r) => r.status == 'pending' || r.status == 'approved')
        .toList();

    final search = TextEditingController();

    return showModalBottomSheet<_Recipient>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: L.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = search.text.trim();
            final cs =
                clients.where((c) => q.isEmpty || c.name.contains(q)).toList();
            final rs =
                requests.where((r) => q.isEmpty || r.name.contains(q)).toList();

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        hintText: L.t('gift_recipient'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      children: [
                        // توزيع عام — معرض/مارّة
                        ListTile(
                          leading: const Icon(Icons.public, size: 20),
                          title: Text(L.t('gift_general'),
                              style: const TextStyle(fontSize: 13)),
                          onTap: () =>
                              Navigator.pop(ctx, const _Recipient.none()),
                        ),
                        if (rs.isNotEmpty) ...[
                          const Divider(),
                          Text(L.t('new_client_requests'),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          // ⚠️ **الطلب الجديد مستلم شرعي** — المندوب
                          // بيكسب العميل بالعينة قبل ما يبقى رسمي
                          for (final r in rs)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_add_alt,
                                  size: 19, color: _purple),
                              title: Text(r.name,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(r.statusLabel,
                                  style: const TextStyle(fontSize: 11)),
                              onTap: () => Navigator.pop(
                                  ctx, _Recipient.request(r.id, r.name)),
                            ),
                        ],
                        if (cs.isNotEmpty) ...[
                          const Divider(),
                          Text(L.t('clients'),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          // ⚠️ الاسم متقسم صح: السلسلة عنوان تقيل
                          // والفرع تحتها — «Madenaty» / «1- kiosk»
                          for (final c in cs)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.storefront, size: 19),
                              title: Text(c.chain ?? c.branch,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              subtitle: c.chain == null
                                  ? null
                                  : Text(c.branch,
                                      style: const TextStyle(fontSize: 11.5)),
                              onTap: () => Navigator.pop(
                                  ctx, _Recipient.client(c.id, c.name)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _record(dynamic item) async {
    final left = (item['left'] ?? 0) as int;
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    // السبب — الـAPI بيخزّنه وبيرجّعه في `handouts` وشاشة الهدايا
    // بتعرضه، لكن الفورم عمره ما بعته فالعمود كان فاضي دايماً (٩/٩)
    final reasonCtrl = TextEditingController();

    // من صفحة العميل؟ المستلم محدد سلفاً
    var recipient = widget.presetClientId != null
        ? _Recipient.client(
            widget.presetClientId!, widget.presetClientName ?? '')
        : const _Recipient.none();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: L.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: Text(item['name'] ?? ''),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: L.t('gift_qty'),
                    helperText: '${L.t('gift_left')}: $left',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // ═══ المستلم — عميل / طلب جديد / توزيع عام ═══
                InkWell(
                  onTap: () async {
                    final picked = await _pickRecipient();
                    if (picked != null) setDlg(() => recipient = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: L.t('gift_recipient'),
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      recipient.isGeneral
                          ? L.t('gift_general')
                          : recipient.label,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: L.t('gift_reason'),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: L.t('gift_note'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(L.t('cancel'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(L.t('save'))),
            ],
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

    if (qty <= 0 || qty > left) return;

    try {
      await Api.I.post('/gifts', {
        'product_id': item['product_id'],
        'qty': qty,
        'client_id': recipient.clientId,
        'client_request_id': recipient.requestId,
        'visit_id': widget.visitId,
        'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.t('gift_saved'))));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: _bad));
    }
  }
}
