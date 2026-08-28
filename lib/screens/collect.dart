import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// تحصيل من العميل أثناء الزيارة (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب واقف عند العميل وعامل تشيك إن: يكتب المبلغ، يختار
/// الطريقة (كاش/كارت/شيك/تحويل)، ويصوّر الإثبات لأي حاجة غير الكاش
/// — سكرين التحويل، الشيك نفسه، إيصال الماكينة.
///
/// ⚠️ **غير الكاش من غير صورة مايتبعتش أصلاً** — السيرفر هيرفض،
/// فالشاشة بتمنع بدري بدل ما المندوب يستنى رد فاشل على شبكة ضعيفة.
class CollectScreen extends StatefulWidget {
  final Client client;

  const CollectScreen({super.key, required this.client});

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _chequeBank = TextEditingController();
  final _note = TextEditingController();

  String _method = 'cash';
  DateTime? _chequeDue;
  String? _proofPath;
  bool _busy = false;

  // ⚠️ **مفتاح واحد لعمر الشاشة** — نفس درس المرتجعات: لو الطلب
  // عمل تايم أوت والمندوب داس تاني، السيرفر بيلاقي نفس المفتاح
  // ويرجّع القيد الأولاني بدل ما يضيف قيد دائن تاني.
  late final String _idemKey =
      'col-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}';

  bool get _needsProof => _method != 'cash';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _chequeBank.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _shootProof(ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1800);
      if (x == null) return;
      setState(() => _proofPath = x.path);
    } catch (e) {
      if (mounted) snack(context, L.t('camera_failed', {'e': '$e'}));
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;

    if (amount <= 0) {
      snack(context, L.t('collect_amount_required'), bad: true);
      return;
    }
    if (_needsProof && _reference.text.trim().isEmpty) {
      snack(context, L.t('collect_reference_required'), bad: true);
      return;
    }
    if (_method == 'cheque' &&
        (_chequeBank.text.trim().isEmpty || _chequeDue == null)) {
      snack(context, L.t('collect_cheque_required'), bad: true);
      return;
    }
    if (_needsProof && _proofPath == null) {
      snack(context, L.t('collect_proof_required'), bad: true);
      return;
    }

    setState(() => _busy = true);

    final (err, balance) = await Session.I.collectVisit(
      widget.client,
      amount: amount,
      method: _method,
      reference: _reference.text.trim(),
      chequeBank: _chequeBank.text.trim(),
      chequeDue: _chequeDue == null
          ? null
          : '${_chequeDue!.year}-${_chequeDue!.month.toString().padLeft(2, '0')}-${_chequeDue!.day.toString().padLeft(2, '0')}',
      note: _note.text.trim(),
      proofPath: _proofPath,
      idemKey: _idemKey,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      snack(context, err, bad: true);
      return;
    }

    // ⚠️ امسك الـNavigator قبل أي await تاني — `mounted` بعد
    // pop بترجع false والرسالة كانت بتضيع (فخ موثّق)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(SnackBar(
      content: Text(balance == null
          ? L.t('collect_done')
          : L.t('collect_done_balance', {'b': money(balance)})),
    ));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('collect_title'))),
      body: ListView(
        // viewPadding صريح (مسح ٢١/٨) — زرار «سجّل التحصيل» كان تحت بار النظام
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          // ═══ رصيده قدامه وهو بيكتب ═══
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          c.balance > 0
                              ? '${L.t('on_him')}: ${money(c.balance)}'
                              : L.t('balance_zero'),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.balance > 0
                                  ? const Color(0xFFB00020)
                                  : const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.account_balance_wallet_outlined, size: 30),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(L.t('collect_amount'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            decoration: InputDecoration(hintText: '0.00', suffixText: L.t('egp')),
          ),
          const SizedBox(height: 16),

          Text(L.t('collect_method'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [
                ('cash', Icons.payments_outlined),
                ('card', Icons.credit_card),
                ('cheque', Icons.receipt_long_outlined),
                ('transfer', Icons.swap_horiz),
              ])
                ChoiceChip(
                  selected: _method == m.$1,
                  avatar: Icon(m.$2, size: 17),
                  label: Text(L.t('pay_method_${m.$1}')),
                  onSelected: (_) => setState(() => _method = m.$1),
                ),
            ],
          ),

          // ═══ غير الكاش: مرجع + إثبات ═══
          if (_needsProof) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: L.t('collect_reference'),
                hintText: L.t('collect_reference_ph'),
              ),
            ),
          ],

          if (_method == 'cheque') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _chequeBank,
              decoration: InputDecoration(labelText: L.t('cheque_bank')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              label: Text(_chequeDue == null
                  ? L.t('cheque_due_pick')
                  : '${L.t('cheque_due')}: ${_chequeDue!.year}-${_chequeDue!.month.toString().padLeft(2, '0')}-${_chequeDue!.day.toString().padLeft(2, '0')}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (d != null) setState(() => _chequeDue = d);
              },
            ),
          ],

          if (_needsProof) ...[
            const SizedBox(height: 16),
            Text(L.t('collect_proof'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 4),
            Text(L.t('collect_proof_hint'),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            if (_proofPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_proofPath!),
                    height: 190, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    label: Text(L.t('proof_camera')),
                    onPressed:
                        _busy ? null : () => _shootProof(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 19),
                    label: Text(L.t('proof_gallery')),
                    onPressed:
                        _busy ? null : () => _shootProof(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: L.t('note_optional')),
          ),

          const SizedBox(height: 20),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 6),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            label: Text(L.t('collect_submit'),
                style: const TextStyle(fontSize: 16)),
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
