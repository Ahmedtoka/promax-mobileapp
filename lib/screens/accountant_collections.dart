import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import 'office_home.dart' show OfficeBoardHeader;
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// تحصيلات الميدان للمحاسب — قراءة بس (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// إشعار «تحصيل شيك/تحويل» كان بيوصل المحاسب ومايفتحش على حاجة.
/// هنا بيشوف آخر التحصيلات بطرقها ومراجعها وصور إثباتها — يطابق
/// الشيك من موبايله، والتسجيل والاعتماد فاضلين للويب عن قصد.
class AccountantCollectionsBoard extends StatefulWidget {
  const AccountantCollectionsBoard({super.key});

  @override
  State<AccountantCollectionsBoard> createState() =>
      _AccountantCollectionsBoardState();
}

class _CollectionRow {
  final String client;
  final double amount;
  final String method;
  final String methodLabel;
  final String? reference;
  final String? chequeBank;
  final String? chequeDue;
  final String? proofUrl;
  final String? collectedBy;
  final DateTime time;

  _CollectionRow.fromJson(Map<String, dynamic> j)
      : client = j['client'] ?? '—',
        amount = (j['amount'] as num?)?.toDouble() ?? 0,
        method = j['method'] ?? '',
        methodLabel = j['method_label']?.toString() ?? '',
        reference = j['reference']?.toString(),
        chequeBank = j['cheque_bank']?.toString(),
        chequeDue = j['cheque_due']?.toString(),
        proofUrl = j['proof_url']?.toString(),
        collectedBy = j['collected_by']?.toString(),
        time = parseTime(j['time']) ?? DateTime.now();
}

class _AccountantCollectionsBoardState
    extends State<AccountantCollectionsBoard> {
  List<_CollectionRow> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.accountantCollections();
      if (!mounted) return;
      setState(() {
        _rows = ((res['collections'] ?? []) as List)
            .map((e) => _CollectionRow.fromJson(Map<String, dynamic>.from(e)))
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
    return OfficeBoardHeader(
      child: _loading
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
                          const SizedBox(height: 120),
                          Icon(Icons.receipt_long_outlined,
                              size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Center(
                              child: Text(L.t('no_collections_yet'),
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

  Widget _card(_CollectionRow r) {
    final cash = r.method == 'cash';

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
                  child: Text(r.client,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
                Text(money(r.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF16A34A))),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip2(
                    text: r.methodLabel,
                    color: cash
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF2563EB)),
                if (r.collectedBy != null)
                  Text('${L.t('collected_by')}: ${r.collectedBy}',
                      style: const TextStyle(fontSize: 11.5)),
                Text(fmtDate(r.time),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            if (r.reference != null && r.reference!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('${L.t('collect_reference')}: ${r.reference}',
                  style: const TextStyle(fontSize: 11.5)),
            ],
            if (r.method == 'cheque' && r.chequeDue != null) ...[
              const SizedBox(height: 3),
              Text('${r.chequeBank ?? ''} · ${L.t('cheque_due')}: ${r.chequeDue}',
                  style: const TextStyle(fontSize: 11.5)),
            ],
            if (r.proofUrl != null) ...[
              const SizedBox(height: 9),
              // صورة الإثبات — المطابقة من الموبايل
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  r.proofUrl!,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
