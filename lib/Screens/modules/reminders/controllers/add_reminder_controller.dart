import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData;

/// Add or edit a vehicle reminder.
///
/// Arguments (all optional):
/// - `reminder`: a [ReminderModel] to edit.
/// - `vehicleNumber`: preselects (and locks) the vehicle, e.g. from Track.
class AddReminderController extends GetxController {
  /// Used only if `reminder_types` fails.
  static const fallbackTypes = [
    OptionItem(1, 'Service'),
    OptionItem(2, 'Oil Change'),
    OptionItem(3, 'AC Service'),
    OptionItem(4, 'Filter Change'),
    OptionItem(5, 'Tyre Change'),
    OptionItem(6, 'Battery Change'),
    OptionItem(7, 'Others'),
  ];

  final odometerController = TextEditingController();
  final periodController = TextEditingController();
  final remarksController = TextEditingController();

  final reminderTypes = <OptionItem>[].obs;
  final vehicles = <String>[].obs;
  final selectedType = Rxn<OptionItem>();
  final selectedVehicle = ''.obs;
  final vehicleLocked = false.obs;
  final isSaving = false.obs;

  ReminderModel? editing;
  bool get isEdit => editing != null;

  final vehicleError = ''.obs;
  final typeError = ''.obs;
  final odometerError = ''.obs;
  final periodError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      final r = args['reminder'];
      if (r is ReminderModel) {
        editing = r;
        selectedVehicle.value = r.vehicleNumber;
        selectedType.value = OptionItem(r.type, r.typeLabel);
        odometerController.text = _plain(r.startOdometer);
        periodController.text = _plain(r.period);
        remarksController.text = r.remarks;
      }
      final v = (args['vehicleNumber'] ?? '').toString().trim();
      if (v.isNotEmpty) {
        selectedVehicle.value = v;
        vehicleLocked.value = true;
      }
    }
    clearErrorOnEdit(odometerController, odometerError);
    clearErrorOnEdit(periodController, periodError);
    _loadTypes();
    _loadVehicles();
  }

  static String _plain(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _loadTypes() async {
    try {
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.reminderTypes);
      final types = OptionItem.listFrom(apiData(response)['types']);
      reminderTypes.assignAll(types.isEmpty ? fallbackTypes : types);
    } catch (_) {
      reminderTypes.assignAll(fallbackTypes);
    }
    // Swap the edited reminder's type for the server's own entry.
    final t = selectedType.value;
    if (t != null) {
      selectedType.value = reminderTypes.firstWhereOrNull((o) => o.key == t.key) ?? t;
    }
  }

  Future<void> _loadVehicles() async {
    try {
      vehicles.assignAll(await VehicleNumbers.load());
      if (selectedVehicle.value.isEmpty && vehicles.length == 1) {
        selectedVehicle.value = vehicles.first;
      }
    } catch (e) {
      showRecordError(e);
    }
  }

  Future<void> pickVehicle() async {
    if (vehicleLocked.value) return;
    if (vehicles.isEmpty) await _loadVehicles();
    final v = await showOptionSheet<String>(
      title: 'Select Vehicle',
      options: vehicles,
      labelOf: (s) => s,
      selected: selectedVehicle.value,
      searchable: vehicles.length > 6,
    );
    if (v != null) {
      selectedVehicle.value = v;
      vehicleError.value = '';
    }
  }

  Future<void> pickType() async {
    final t = await showOptionSheet<OptionItem>(
      title: 'Select Reminder Type',
      options: reminderTypes,
      labelOf: (o) => o.label,
      selected: selectedType.value,
    );
    if (t != null) {
      selectedType.value = t;
      typeError.value = '';
    }
  }

  bool validate() {
    bool ok = true;
    vehicleError.value = selectedVehicle.value.isEmpty ? 'Vehicle is required' : '';
    typeError.value = selectedType.value == null ? 'Reminder type is required' : '';

    final start = num.tryParse(odometerController.text.trim());
    odometerError.value = odometerController.text.trim().isEmpty
        ? 'Starting odometer is required'
        : (start == null || start < 0 ? 'Enter a valid odometer reading' : '');

    final period = num.tryParse(periodController.text.trim());
    periodError.value = periodController.text.trim().isEmpty
        ? 'Odometer period is required'
        : (period == null || period <= 0 ? 'Enter a period greater than 0' : '');

    for (final e in [vehicleError, typeError, odometerError, periodError]) {
      if (e.value.isNotEmpty) ok = false;
    }
    return ok;
  }

  Future<void> submit() async {
    if (isSaving.value || !validate()) return;
    isSaving.value = true;
    try {
      await ensureApiToken();
      // update_vehicle_reminder replaces every field, so send them all.
      final form = FormData.fromMap({
        if (isEdit) 'id': editing!.id,
        'vehicle_number': selectedVehicle.value,
        'type': selectedType.value!.key,
        'start_odometer': odometerController.text.trim(),
        'period': periodController.text.trim(),
        'remarks': remarksController.text.trim(),
      });
      final response = await DioClient().post(
        isEdit ? ApiEndPoints.updateVehicleReminder : ApiEndPoints.addVehicleReminder,
        body: form,
      );
      apiData(response, fallbackError: 'Could not save reminder');
      Get.back(result: true);
      showRecordSuccess(isEdit ? 'Reminder updated' : 'Reminder added successfully');
    } catch (e) {
      showRecordError(e);
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    odometerController.dispose();
    periodController.dispose();
    remarksController.dispose();
    super.onClose();
  }
}
