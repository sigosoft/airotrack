import 'package:get/get.dart';

import '../../../../Services/AppSettings.dart';
import '../../../../Services/FcmService.dart';

/// General Settings screen. Values live in [AppSettings] (saved on the
/// phone); this only tracks which section is open.
class GeneralSettingsController extends GetxController {
  AppSettings get settings => AppSettings.to;

  /// Key of the expanded section, or '' when all are closed.
  final expanded = ''.obs;

  void toggleSection(String key) {
    expanded.value = expanded.value == key ? '' : key;
  }

  Future<void> setNotifications(bool on) async {
    settings.setNotifications(on);
    await FcmService.instance.setEnabled(on);
  }
}
