import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/routes/app_routes.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData;

/// Reminders list (`vehicle_reminders`) with search, paging, edit and delete.
class RemindersController extends PagedRecordsController<ReminderModel> {
  @override
  Future<(List<ReminderModel>, PageInfo, Map<String, dynamic>)> fetchPage(
    Map<String, dynamic> query,
  ) async {
    final response = await DioClient().get(ApiEndPoints.vehicleReminders, query: query);
    final data = apiData(response, fallbackError: 'Could not load reminders');
    final list = data['reminders'];
    final rows = list is List
        ? list.whereType<Map>().map(ReminderModel.fromJson).toList()
        : <ReminderModel>[];
    return (rows, PageInfo.fromJson(data['pagination']), data);
  }

  /// Opens Add Reminder; reloads the list when something was saved.
  Future<void> openAdd() async {
    dismissKeyboard();
    final saved = await Get.toNamed(Routes.ADD_REMINDER);
    if (saved == true) refreshList();
  }

  Future<void> openEdit(ReminderModel reminder) async {
    dismissKeyboard();
    final saved = await Get.toNamed(Routes.ADD_REMINDER, arguments: {'reminder': reminder});
    if (saved == true) refreshList();
  }

  Future<void> delete(ReminderModel reminder) async {
    if (!await confirmDelete('reminder')) return;
    try {
      await ensureApiToken();
      final form = FormData.fromMap({'id': reminder.id});
      final response = await DioClient().post(ApiEndPoints.deleteVehicleReminder, body: form);
      apiData(response, fallbackError: 'Could not delete reminder');
      items.removeWhere((r) => r.id == reminder.id);
      showRecordSuccess('Reminder deleted');
    } catch (e) {
      showRecordError(e);
    }
  }
}
