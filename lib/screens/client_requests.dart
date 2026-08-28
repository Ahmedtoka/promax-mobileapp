import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'zones.dart';

/// ═══════════════════════════════════════════════════════════════
/// طلبات العملاء الجدد — كل اللي المندوب سجّلهم وحالتهم
/// ═══════════════════════════════════════════════════════════════
///
/// «سجلت مين ومين اتوافق عليه ومين لسه مستني» — من غير ما يتصل
/// بالمدير. الحالة بلونها: مستني برتقالي، اتوافق أخضر، مرفوض أحمر.
class ClientRequestsScreen extends StatelessWidget {
  const ClientRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('new_client_requests'))),
      body: ListenableBuilder(
        listenable: Session.I,
        builder: (context, _) {
          final rows = Session.I.requests;

          // ⚠️ الحالة الفاضية **جوه** الـRefreshIndicator (تدقيق ٩/٨):
          // `Center` بره كانت بتقفل السحب للتحديث بالظبط في اللحظة
          // اللي المندوب عاوز يشوف فيها إذا كان طلبه اتوافق.
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: Session.I.refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 130),
                  Icon(Icons.person_add_alt, size: 52, color: Brand.muted),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(L.t('no_client_requests'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: Session.I.refresh,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final r in rows)
                  Builder(builder: (context) {
                    final (color, label) = r.info;

                    // ═══ المتوافق عليه كليك أبل (١٩/٨) ═══
                    //
                    // «لما بيتوافق عليه مفهاش أدوس على العميل وأدخل
                    // أبيع له» — الطلب المعتمد بيوديك على شاشة العميل
                    // مباشرة: تشيك إن وتبيع. لو العميل لسه مانزلش في
                    // مناطقه (البول بيتحدث مع الريفريش) بنقوله يسحب
                    // للتحديث بدل ما مايحصلش حاجة في صمت.
                    final sellable = r.status == 'approved';

                    void openClient() {
                      final c = r.clientId == null
                          ? null
                          : Session.I.clientById(r.clientId!);

                      if (c == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(L.t('request_client_syncing'))));
                        Session.I.refresh();
                        return;
                      }

                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ClientScreen(client: c)));
                    }

                    return Card(
                      child: ListTile(
                        onTap: sellable ? openClient : null,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: .12),
                          child:
                              Icon(Icons.storefront, color: color, size: 19),
                        ),
                        title: Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        subtitle: Text('${r.number} • ${fmtDate(r.time)}',
                            style: const TextStyle(fontSize: 11.5)),
                        // ⚠️ الجملة الخضرا اتشالت (طلب المالك ٢٠/٨) —
                        // الحالة + سهم دخول للمتوافق عليه وبس
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: color)),
                            if (sellable)
                              Icon(Icons.chevron_left,
                                  size: 18, color: color),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
