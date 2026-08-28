import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// ترتيب الرف — صور قبل وبعد (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب بيصوّر شكل الرف قبل ما يرتّب، يرتّب، ويصوّر بعد —
/// **أكتر من صورة للمرحلتين عادي** (طلب المالك). كل صورة بتترفع
/// فوراً وقت التقاطها، فقطع النت في النص مايضيّعش اللي اترفع.
///
/// ⚠️ ده غير فلو البروموتر (`promoter_visit`) — ده جوه زيارة
/// السيلز العادية، والصور بتبان للمدير في «يوم المندوب».
class ShelfPhotosScreen extends StatefulWidget {
  final Client client;

  const ShelfPhotosScreen({super.key, required this.client});

  @override
  State<ShelfPhotosScreen> createState() => _ShelfPhotosScreenState();
}

class _ShelfPhotosScreenState extends State<ShelfPhotosScreen> {
  // الصور اللي اترفعت في الجلسة دي — محلية للعرض بس، السيرفر خزّنها
  final List<String> _before = [];
  final List<String> _after = [];
  bool _busy = false;

  Future<void> _shoot(String stage) async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 75, maxWidth: 1800);
      if (x == null || !mounted) return;

      setState(() => _busy = true);

      final (err, count) =
          await Session.I.visitShelfPhoto(widget.client, stage, x.path);

      if (!mounted) return;
      setState(() => _busy = false);

      if (err != null) {
        snack(context, err, bad: true);
        return;
      }

      setState(() => (stage == 'before' ? _before : _after).add(x.path));
      snack(
          context,
          stage == 'before'
              ? L.t('shelf_before_saved', {'n': '${count ?? _before.length}'})
              : L.t('shelf_after_saved', {'n': '${count ?? _after.length}'}));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        snack(context, L.t('camera_failed', {'e': '$e'}));
      }
    }
  }

  Widget _section(String stage, List<String> paths) {
    final isBefore = stage == 'before';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isBefore ? Icons.photo_camera_outlined : Icons.auto_awesome,
                    size: 20,
                    color: isBefore
                        ? const Color(0xFFB45309)
                        : const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBefore ? L.t('shelf_before_title') : L.t('shelf_after_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14.5),
                  ),
                ),
                if (paths.isNotEmpty)
                  Chip2(text: '${paths.length}', color: const Color(0xFF2563EB)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isBefore ? L.t('shelf_before_hint') : L.t('shelf_after_hint'),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            if (paths.isNotEmpty) ...[
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(paths[i]),
                        width: 96, height: 96, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined, size: 19),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              label: Text(paths.isEmpty
                  ? L.t('shelf_take_photo')
                  : L.t('shelf_take_more')),
              onPressed: _busy ? null : () => _shoot(stage),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('shelf_title'))),
      body: ListView(
        // viewPadding صريح (مسح ٢١/٨)
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          Text(widget.client.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 6),
          _section('before', _before),
          const SizedBox(height: 12),
          _section('after', _after),
          const SizedBox(height: 16),
          // الرجوع عادي — الصور اترفعت أول بأول، مفيش «حفظ» مستني
          OutlinedButton.icon(
            icon: const Icon(Icons.check),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            label: Text(L.t('shelf_done')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
