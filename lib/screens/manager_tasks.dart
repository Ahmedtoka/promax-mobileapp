import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../l10n.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// إدارة المهام على الموبايل (٢٨/٨/٢٠٢٦) — مرآة شاشة الداشبورد
/// ═══════════════════════════════════════════════════════════════
///
/// تابين: «مهامي» (مفتوح/متأخر + زرار تم التسليم) و«اللي كلفتها»
/// (اعتماد/رفض) + إنشاء مهمة بصور. التفاصيل شات لايف زي الويب:
/// بولينج كل ٦ ثواني، ولو الحالة اتغيرت الشاشة بتتظبط لوحدها.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Map<String, dynamic>? _d;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final d = await Api.I.tasksBoard();
      if (!mounted) return;
      setState(() {
        _d = d;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = L.t('server_down');
      });
    }
  }

  List<Map<String, dynamic>> _list(String k) =>
      ((_d?[k] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  Widget build(BuildContext context) {
    final mine = _list('mine');
    final assigned = _list('assigned');

    final late = mine.where((t) => t['is_late'] == true).toList();
    final open = mine
        .where((t) => t['status'] == 'open' && t['is_late'] != true)
        .toList();
    final submitted = mine.where((t) => t['status'] == 'submitted').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L.t('tk_title')),
          bottom: TabBar(tabs: [
            Tab(text: '${L.t('tk_mine')} (${late.length + open.length + submitted.length})'),
            Tab(text: '${L.t('tk_assigned')} (${assigned.where((t) => t['status'] != 'approved').length})'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => TaskCreateScreen(
                    staff: _list('staff'))));
            if (created == true) _load();
          },
          icon: const Icon(Icons.add_task),
          label: Text(L.t('tk_new')),
        ),
        body: _err != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_err!),
                    TextButton(onPressed: _load, child: Text(L.t('retry'))),
                  ],
                ),
              )
            : _d == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    // ═══ مهامي ═══
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          if (mine.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 120),
                              child: Center(child: Text(L.t('tk_none'))),
                            ),
                          if (late.isNotEmpty) ...[
                            _SectionTitle(
                                '⏰ ${L.t('tk_late')} (${late.length})',
                                const Color(0xFFDC2626)),
                            ...late.map((t) => _card(t, mine: true)),
                          ],
                          if (open.isNotEmpty) ...[
                            _SectionTitle(
                                '🔵 ${L.t('tk_open')} (${open.length})',
                                const Color(0xFF2563EB)),
                            ...open.map((t) => _card(t, mine: true)),
                          ],
                          if (submitted.isNotEmpty) ...[
                            _SectionTitle(
                                '⏳ ${L.t('tk_waiting')} (${submitted.length})',
                                const Color(0xFFB86E00)),
                            ...submitted.map((t) => _card(t, mine: true)),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                    // ═══ اللي كلفتها ═══
                    RefreshIndicator(
                      onRefresh: _load,
                      child: assigned.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 120),
                              Center(child: Text(L.t('tk_none_assigned'))),
                            ])
                          : ListView(
                              padding: const EdgeInsets.all(14),
                              children: [
                                ...assigned.map((t) => _card(t, mine: false)),
                                const SizedBox(height: 80),
                              ],
                            ),
                    ),
                  ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> t, {required bool mine}) {
    final status = '${t['status']}';
    final isLate = t['is_late'] == true;
    final (chipColor, chipText) = isLate
        ? (const Color(0xFFDC2626), L.t('tk_late'))
        : switch (status) {
            'submitted' => (const Color(0xFFB86E00), L.t('tk_waiting_short')),
            'approved' => (const Color(0xFF16A34A), L.t('tk_done')),
            _ => (const Color(0xFF2563EB), L.t('tk_open')),
          };

    final prColor = switch ('${t['priority']}') {
      'urgent' => const Color(0xFFDC2626),
      'high' => const Color(0xFFEA8C1C),
      'low' => Colors.grey,
      _ => const Color(0xFF2563EB),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: (t['id'] as num).toInt())));
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                    color: prColor, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(
                      mine
                          ? '${L.t('tk_from')}: ${t['creator'] ?? '—'}'
                              '${t['deadline'] != null ? ' • ${t['deadline']}' : ''}'
                          : '${L.t('tk_to')}: ${t['assignee'] ?? '—'}'
                              '${t['deadline'] != null ? ' • ${t['deadline']}' : ''}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(chipText,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: chipColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// ═══ إنشاء مهمة — موظف + عنوان + وصف + أولوية + ديدلاين + صور ═══
class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({super.key, required this.staff});

  final List<Map<String, dynamic>> staff;

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  int? _assignee;
  String _priority = 'normal';
  DateTime? _deadline;
  final List<File> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null && mounted) setState(() => _photos.add(File(x.path)));
  }

  Future<void> _submit() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_title.text.trim().isEmpty || _assignee == null) {
      snack(context, L.t('tk_need_title_assignee'), bad: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await Api.I.taskCreate(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        assignedTo: _assignee!,
        priority: _priority,
        deadline: _deadline == null
            ? null
            : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
        photoPaths: _photos.map((f) => f.path).toList(),
      );
      nav.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(L.t('tk_created'))));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      snack(context, e.message, bad: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      snack(context, L.t('server_down'), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('tk_new'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: L.t('tk_f_title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: L.t('tk_f_desc'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // دروب داون عادي جوه بوردر — نفس نمط تسجيل العميل (مش
          // FormField عشان فروقات إصدارات باراميتر القيمة)
          Container(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _assignee,
                isExpanded: true,
                hint: Text(L.t('tk_f_assignee')),
                items: [
                  for (final s in widget.staff)
                    DropdownMenuItem(
                        value: (s['id'] as num).toInt(),
                        child: Text('${s['name']}')),
                ],
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (k, label) in [
                ('low', L.t('tk_p_low')),
                ('normal', L.t('tk_p_normal')),
                ('high', L.t('tk_p_high')),
                ('urgent', L.t('tk_p_urgent')),
              ]) ...[
                Expanded(
                  child: ChoiceChip(
                    label: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    selected: _priority == k,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _priority = k),
                  ),
                ),
                if (k != 'urgent') const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null && mounted) setState(() => _deadline = d);
            },
            icon: const Icon(Icons.event),
            label: Text(_deadline == null
                ? L.t('tk_f_deadline')
                : '${_deadline!.year}-${_deadline!.month}-${_deadline!.day}'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(L.t('tk_attach')),
              ),
              const SizedBox(width: 8),
              if (_photos.isNotEmpty)
                Text('${_photos.length} 📎',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_photos[i],
                            width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 11, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(L.t('tk_create_btn')),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// ═══ تفاصيل المهمة + الشات — بولينج ٦ ثواني زي الويب ═══
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final int taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _msgs = [];
  final _body = TextEditingController();
  final _scroll = ScrollController();
  File? _photo;
  bool _sending = false;
  bool _acting = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // بولينج زي شات الويب — ولو الحالة اتغيرت بنعيد تحميل الكل
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.taskShow(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = Map<String, dynamic>.from((d['task'] ?? const {}) as Map);
        _msgs = ((d['comments'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
      _jumpToEnd();
    } catch (_) {
      // البولينج هيلحق
    }
  }

  Future<void> _tick() async {
    if (_task == null) return;
    final last = _msgs.isEmpty ? 0 : (_msgs.last['id'] as num).toInt();
    try {
      final d = await Api.I.taskComments(widget.taskId, last);
      if (!mounted) return;
      final fresh = ((d['comments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final status = '${d['status']}';
      if (status != '${_task!['status']}') {
        _load(); // الحالة اتغيرت — الأزرار لازم تتظبط
        return;
      }
      if (fresh.isNotEmpty) {
        setState(() => _msgs.addAll(fresh));
        _jumpToEnd();
      }
    } catch (_) {}
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _body.text.trim();
    if (text.isEmpty && _photo == null) return;

    setState(() => _sending = true);
    try {
      final d = await Api.I
          .taskComment(widget.taskId, body: text, photoPath: _photo?.path);
      if (!mounted) return;
      final c = Map<String, dynamic>.from((d['comment'] ?? const {}) as Map);
      setState(() {
        _sending = false;
        _photo = null;
        _body.clear();
        if (c.isNotEmpty) _msgs.add(c);
      });
      _jumpToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      snack(context, e.message, bad: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      snack(context, L.t('server_down'), bad: true);
    }
  }

  Future<void> _action(Future<Map<String, dynamic>> Function() fn) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await fn();
      if (!mounted) return;
      setState(() => _acting = false);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      snack(context, e.message, bad: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _acting = false);
      snack(context, L.t('server_down'), bad: true);
    }
  }

  Future<void> _rejectDialog() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('tk_reject')),
        content: TextField(
          controller: reason,
          decoration: InputDecoration(
              labelText: L.t('tk_reject_reason'),
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L.t('tk_reject'))),
        ],
      ),
    );
    if (ok == true) {
      await _action(
          () => Api.I.taskReject(widget.taskId, reason: reason.text.trim()));
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;

    return Scaffold(
      appBar: AppBar(
        title: Text(t == null ? L.t('tk_title') : '${t['title']}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: t == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ═══ هيدر المهمة ═══
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ('${t['description'] ?? ''}'.isNotEmpty)
                        Text('${t['description']}',
                            style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(
                        '${L.t('tk_from')}: ${t['creator'] ?? '—'} → ${t['assignee'] ?? '—'}'
                        '${t['deadline'] != null ? ' • ⏰ ${t['deadline']}' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),

                // ═══ الشات ═══
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length,
                    itemBuilder: (context, i) => _msgTile(_msgs[i]),
                  ),
                ),

                // ═══ أزرار الحالة ═══
                _actionsBar(t),

                // ═══ صف الإرسال ═══
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            final x = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80);
                            if (x != null && mounted) {
                              setState(() => _photo = File(x.path));
                            }
                          },
                          icon: Badge(
                            isLabelVisible: _photo != null,
                            child: const Icon(Icons.attach_file),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _body,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: L.t('tk_msg_hint'),
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : IconButton.filled(
                                onPressed: _send,
                                icon: const Icon(Icons.send, size: 19)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _actionsBar(Map<String, dynamic> t) {
    final status = '${t['status']}';

    // «تم التسليم» بيظهر للمكلَّف والمهمة مفتوحة، والاعتماد/الرفض
    // للمكلِّف والمهمة متسلمة — السيرفر هو الحارس النهائي (403/422)
    // فالأزرار اجتهاد عرض مش صلاحية.
    final buttons = <Widget>[];
    if (status == 'open') {
      buttons.add(Expanded(
        child: FilledButton.icon(
          onPressed: _acting
              ? null
              : () => _action(() => Api.I.taskSubmit(widget.taskId)),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(L.t('tk_submit')),
        ),
      ));
    } else if (status == 'submitted') {
      buttons.addAll([
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            onPressed: _acting
                ? null
                : () => _action(() => Api.I.taskApprove(widget.taskId)),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: Text(L.t('tk_approve')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626)),
            onPressed: _acting ? null : _rejectDialog,
            icon: const Icon(Icons.replay, size: 18),
            label: Text(L.t('tk_reject')),
          ),
        ),
      ]);
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('🏁 ${L.t('tk_approved_line')}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A))),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: buttons),
    );
  }

  Widget _msgTile(Map<String, dynamic> m) {
    if (m['is_system'] == true) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${m['body'] ?? ''} • ${m['t'] ?? ''}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${m['name'] ?? '—'}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              Text('${m['t'] ?? ''}',
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          if ('${m['body'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${m['body']}', style: const TextStyle(fontSize: 13)),
          ],
          if (m['file_url'] != null) ...[
            const SizedBox(height: 6),
            m['is_img'] == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network('${m['file_url']}',
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image)),
                  )
                : Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${m['file_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }
}
