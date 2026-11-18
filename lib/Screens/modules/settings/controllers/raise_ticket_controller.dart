import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData;
import 'dart:io';

import 'settings_controller.dart';

class RaiseTicketController extends GetxController {
  static const fallbackTypes = [
    OptionItem(1, 'Device offline'),
    OptionItem(2, 'Password issue'),
    OptionItem(3, 'Billing issue'),
    OptionItem(4, 'Recharge'),
    OptionItem(5, 'Others'),
  ];

  final vehicles = <String>[].obs;
  final ticketTypes = <OptionItem>[].obs;
  final selectedVehicle = ''.obs;
  final selectedType = Rxn<OptionItem>();
  final image = Rxn<File>();
  final isSaving = false.obs;

  final messageController = TextEditingController();
  final contactController = TextEditingController();

  final vehicleError = ''.obs;
  final typeError = ''.obs;
  final messageError = ''.obs;
  final contactError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Prefill the contact number with the signed-in user's mobile.
    if (Get.isRegistered<SettingsController>()) {
      contactController.text = Get.find<SettingsController>().profile.value.mobile;
    }
    clearErrorOnEdit(messageController, messageError);
    clearErrorOnEdit(contactController, contactError);
    _loadOptions();
    _loadVehicles();
  }

  Future<void> _loadOptions() async {
    try {
      await ensureApiToken();
      final data = apiData(await DioClient().get(ApiEndPoints.supportTicketOptions));
      final types = OptionItem.listFrom(data['types']);
      ticketTypes.assignAll(types.isEmpty ? fallbackTypes : types);
    } catch (_) {
      ticketTypes.assignAll(fallbackTypes);
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
      title: 'Select Ticket Type',
      options: ticketTypes,
      labelOf: (o) => o.label,
      selected: selectedType.value,
    );
    if (t != null) {
      selectedType.value = t;
      typeError.value = '';
    }
  }

  bool validate() {
    vehicleError.value = selectedVehicle.value.isEmpty ? 'Vehicle selection is required' : '';
    typeError.value = selectedType.value == null ? 'Ticket type is required' : '';
    messageError.value = messageController.text.trim().isEmpty ? 'Message is required' : '';
    final contact = contactController.text.trim();
    contactError.value = contact.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(contact)
        ? 'Enter a valid contact number'
        : '';
    return [vehicleError, typeError, messageError, contactError].every((e) => e.value.isEmpty);
  }

  Future<void> submitTicket() async {
    if (isSaving.value || !validate()) return;
    isSaving.value = true;
    try {
      await ensureApiToken();
      final form = FormData.fromMap({
        'vehicle_number': selectedVehicle.value,
        'type': selectedType.value!.key,
        'message': messageController.text.trim(),
        if (contactController.text.trim().isNotEmpty) 'contact_no': contactController.text.trim(),
      });
      await addImageField(form, image.value);
      final response = await DioClient().post(ApiEndPoints.addSupportTicket, body: form);
      final data = apiData(response, fallbackError: 'Could not raise ticket');
      final id = (data['ticket'] is Map) ? data['ticket']['id'] : null;
      Get.back(result: true);
      showRecordSuccess(id == null ? 'Ticket raised successfully' : 'Ticket #$id raised successfully');
    } catch (e) {
      showRecordError(e);
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    messageController.dispose();
    contactController.dispose();
    super.onClose();
  }
}
