import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../session.dart';
import 'shared.dart';

class ManagerApprovalsScreen extends StatefulWidget {
  const ManagerApprovalsScreen({super.key});

  @override
  State<ManagerApprovalsScreen> createState() => _ManagerApprovalsScreenState();
}

class _ManagerApprovalsScreenState extends State<ManagerApprovalsScreen> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final all = Session.I.pendingRequests;
        final list = switch (_filter) {
          'open' => all.where((r) => r.isOpen).toList(),
          'done' => all.where((r) => !r.isOpen).toList(),
          _ => all,
        };

        return Scaffold(
          appBar: AppBar(title: Text(L.t('client_approvals'))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SegmentedButton<String>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: 'open',
                        label: Text(L.t('waiting_count', {'n': '${all.where((r) => r.isOpen).length}'}))),
                    ButtonSegment(value: 'done', label: Text(L.t('decided'))),
                    ButtonSegment(value: 'all', label: Text(L.t('all'))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: Session.I.refresh,
                  child: list.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 160),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 44, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(L.t('no_requests'),
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              RequestCard(request: list[i]),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= كارت الطلب =================

class RequestCard extends StatefulWidget {
  final PendingRequest request;
  const RequestCard({super.key, required this.request});

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _busy = false;

  Future<void> _decide(String decision, {double? discount, String? note}) async {
    setState(() => _busy = true);
    final err = await Session.I
        .decideRequest(widget.request, decision, discount: discount, note: note);
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ??
          switch (decision) {
            'approved' => L.t('approved_added'),
            'review' => L.t('sent_to_review'),
            _ => L.t('request_rejected'),
          }),
    ));
  }

  /// حوار الموافقة — بيسأل عن نسبة الخصم
  void _approveDialog() {
    final disc = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('approve_n', {'n': '${widget.request.name}'})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L.t('approve_note'),
                style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 14),
            TextField(
              controller: disc,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: L.t('contract_discount_pct'),
                helperText: L.t('leave_zero'),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(style: kDialogCancel, onPressed: () => Navigator.pop(ctx), child: Text(L.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              Navigator.pop(ctx);
              _decide('approved',
                  discount: double.tryParse(disc.text.trim()) ?? 0);
            },
            child: Text(L.t('approve')),
          ),
        ],
      ),
    );
  }

  /// حوار الرفض / المراجعة — بيسأل عن السبب
  void _noteDialog(String decision) {
    final note = TextEditingController();
    final isReject = decision == 'rejected';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReject
            ? L.t('reject_n', {'n': '${widget.request.name}'})
            : L.t('review_n', {'n': '${widget.request.name}'})),
        content: TextField(
          controller: note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: L.t('reason_to_rep'),
            hintText: isReject ? L.t('reason_example') : L.t('needs_revisit'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          OutlinedButton(style: kDialogCancel, onPressed: () => Navigator.pop(ctx), child: Text(L.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    isReject ? const Color(0xFFB00020) : const Color(0xFFB86E00)),
            onPressed: () {
              Navigator.pop(ctx);
              _decide(decision, note: note.text.trim());
            },
            child: Text(isReject ? L.t('reject') : L.t('review')),
          ),
        ],
      ),
    );
  }

  void _viewAttachment(String? url, String label) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (widget.request.docsType == 'pdf' && label.contains(L.t('docs')))
                Column(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        size: 60, color: Color(0xFFB00020)),
                    const SizedBox(height: 10),
                    Text(L.t('pdf_attached'),
                        style: TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 6),
                    SelectableText(url,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center),
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, cacheWidth: 800,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Column(
                      children: [
                        const Icon(Icons.broken_image,
                            size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(L.t('image_failed'),
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        SelectableText(url,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center),
                      ],
                    ),
                    loadingBuilder: (_, child, p) => p == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(),
                          ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(L.t('close'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final (statusColor, statusLabel) = r.info;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.storefront, color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.5)),
                      Text('${r.number} • ${r.rep ?? ''} • ${fmtTime(r.time)}',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Chip2(text: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),

            InfoRow(icon: Icons.place_outlined, text: r.address),
            InfoRow(icon: Icons.phone_outlined, text: r.phone),
            if (r.zone != null)
              InfoRow(icon: Icons.map_outlined, text: L.t('zone_is', {'z': '${r.zone}'})),

            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.photoUrl != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () =>
                        _viewAttachment(r.photoUrl, L.t('place_photo')),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(L.t('place_photo'),
                        style: TextStyle(fontSize: 11.5)),
                  )
                else
                  Chip2(text: L.t('no_image'), color: Color(0xFFB00020)),

                if (r.docsUrl != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () =>
                        _viewAttachment(r.docsUrl, L.t('official_docs')),
                    icon: Icon(
                        r.docsType == 'pdf'
                            ? Icons.picture_as_pdf_outlined
                            : Icons.description_outlined,
                        size: 16),
                    label: Text(
                        r.docsType == 'pdf' ? L.t('docs_pdf') : L.t('documents'),
                        style: const TextStyle(fontSize: 11.5)),
                  )
                else if (r.hasDocs)
                  Chip2(text: L.t('says_has_docs'), color: Color(0xFFB86E00))
                else
                  Chip2(text: L.t('no_docs'), color: Color(0xFFB00020)),
              ],
            ),

            if (r.isOpen) ...[
              const SizedBox(height: 12),
              if (_busy)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          minimumSize: const Size(0, 40),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _approveDialog,
                        child: Text(L.t('approve'),
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    if (r.status == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB86E00),
                            minimumSize: const Size(0, 40),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _noteDialog('review'),
                          child: Text(L.t('review'),
                              style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB00020),
                          minimumSize: const Size(0, 40),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => _noteDialog('rejected'),
                        child:
                            Text(L.t('reject'), style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
