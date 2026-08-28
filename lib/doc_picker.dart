import 'package:flutter/services.dart';
import 'l10n.dart';

/// ملف اتختار من جهاز المستخدم
class PickedDoc {
  final String path;
  final String name;
  const PickedDoc(this.path, this.name);

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// اختيار مستند (PDF أو صورة) — منفّذ بكود أصلي في MainActivity،
/// من غير أي باكدج خارجي عشان منتعلقش بمشاكل التوافق.
class DocPicker {
  static const _channel = MethodChannel('promax/doc_picker');

  /// بترجع null لو المستخدم لغى
  static Future<PickedDoc?> pick() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pickDocument');
      if (res == null) return null;

      final path = res['path']?.toString();
      final name = res['name']?.toString();
      if (path == null || name == null) return null;

      return PickedDoc(path, name);
    } on MissingPluginException {
      throw DocPickerException(L.t('files_mobile_only'));
    } on PlatformException catch (e) {
      throw DocPickerException(e.message ?? L.t('cannot_open_files'));
    }
  }
}

class DocPickerException implements Exception {
  final String message;
  DocPickerException(this.message);
  @override
  String toString() => message;
}
