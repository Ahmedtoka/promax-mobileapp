import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// طلباتي — طلبات البضاعة اللي المندوب طلبها وحالتها (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **المندوب كان بيطلب في الفراغ** (تدقيق ٩/٨): يبعت طلب بضاعة
/// من عند العميل ومفيش أي مكان يشوف فيه اتوافق ولا اترفض ولا بقى
/// أمر رقم كام. البروموتر ليه تاب ريفيل — دي المقابلة بتاعة السيلز.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequest {
  final String number;
  final String client;
  final String status;
  final String statusLabel;
  final int qtyTotal;
  final String? poNumber;
  final String? pickWarehouse;
  final String? assignee;
  final DateTime time;
  /// (الاسم، الكمية، الصورة) — الصورة انضافت ١٥/٨
  final List<(String, int, String?)> items;

  _MyRequest.fromJson(Map<String, dynamic> j)
      : number = j['number'] ?? '',
        client = j['client'] ?? '—',
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label']?.toString() ?? '',
        qtyTotal = (j['qty_total'] as num?)?.toInt() ?? 0,
        // ⚠️ **أمر التجهيز بدل أمر التوريد** (فلو ١٥/٨): طلب الريفيل
        // مابقاش ياخد PO — بينزل المخزن بأمر تجهيز، والمندوب بيستلمه
        // في عهدته. الفولباك على `po_number` عشان الطلبات القديمة
        // اللي اتعملت قبل التغيير تفضل تعرض رقمها.
        poNumber = (j['pick_number'] ?? j['po_number'])?.toString(),
        pickWarehouse = j['pick_warehouse']?.toString(),
        assignee = j['assignee']?.toString(),
        time = parseTime(j['time']) ?? DateTime.now(),
        items = ((j['items'] ?? []) as List)
            .map((e) => (
                  (e['name'] ?? '').toString(),
                  ((e['qty'] as num?)?.toInt() ?? 0),
                  e['image']?.toString(),
                ))
            .toList();

  // ⚠️ `ready` حالة جديدة (فلو ١٥/٨): المخزن جهّز والمندوب لسه
  // مااستلمش. لونها ذهبي عشان تبان إنها **محتاجة منه حركة** —
  // مش خضرا زي المستلمة ولا زرقا زي اللي لسه بتتجهّز.
  Color get color => switch (status) {
        'delivered' => const Color(0xFF16A34A),
        'ready' => const Color(0xFFB8860B),
        'assigned' => const Color(0xFF2563EB),
        'cancelled' => const Color(0xFFB00020),
        _ => const Color(0xFFB86E00),
      };
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<_MyRequest> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.myGoodsRequests();
      if (!mounted) return;
      setState(() {
        _rows = ((res['requests'] ?? []) as List)
            .map((e) => _MyRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('my_requests_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Center(
                          child: Text(_error!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
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
                  : _rows.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 140),
                          Icon(Icons.add_shopping_cart,
                              size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Center(
                              child: Text(L.t('my_requests_empty'),
                                  style: TextStyle(
                                      color: Colors.grey.shade600))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _rows.length,
                          itemBuilder: (_, i) => _card(_rows[i]),
                        ),
            ),
    );
  }

  Widget _card(_MyRequest r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${r.number} — ${r.client}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
                Chip2(text: r.statusLabel, color: r.color),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 3,
              children: [
                Text(L.t('n_units', {'n': '${r.qtyTotal}'}),
                    style: const TextStyle(fontSize: 11.5)),
                if (r.poNumber != null)
                  Text('${L.t('pick_number')}: ${r.poNumber}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                if (r.pickWarehouse != null)
                  Text(r.pickWarehouse!, style: const TextStyle(fontSize: 11.5)),
                if (r.assignee != null)
                  Text(L.t('with_person', {'p': r.assignee!}),
                      style: const TextStyle(fontSize: 11.5)),
                Text(fmtDate(r.time),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            if (r.items.isNotEmpty) ...[
              const Divider(height: 16),
              // ⚠️ **الصورة قبل الاسم** — المندوب واقف في الشارع
              // وبيتعرّف على الصنف بالعين أسرع بكتير من القراية.
              for (final it in r.items.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      if (it.$3 != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(it.$3!, cacheWidth: 800,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                              // مساحة محجوزة عشان الليست ماترقصش
                              // وهي بتحمّل (CLS)
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 34, height: 34)),
                        ),
                        const SizedBox(width: 9),
                      ],
                      Expanded(
                          child: Text(it.$1,
                              style: const TextStyle(fontSize: 12))),
                      Text('${it.$2}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                ),
              if (r.items.length > 6)
                Text('+${r.items.length - 6}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }
}
