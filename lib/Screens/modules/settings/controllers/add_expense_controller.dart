import 'dart:io';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData;
import 'package:intl/intl.dart';

/// Add or edit an expense. Pass `{'expense': ExpenseModel}` to edit.
class AddExpenseController extends GetxController {
  static const fallbackTypes = [
    OptionItem(1, 'Food'),
    OptionItem(2, 'Service'),
    OptionItem(3, 'Fuel'),
    OptionItem(4, 'Other'),
  ];
  static const fallbackMethods = [
    OptionItem(1, 'Online'),
    OptionItem(2, 'Cash'),
    OptionItem(3, 'Card'),
  ];

  final vehicles = <String>[].obs;
  final expenseTypes = <OptionItem>[].obs;
  final paymentMethods = <OptionItem>[].obs;

  final selectedVehicle = ''.obs;
  final selectedExpenseType = Rxn<OptionItem>();
  final selectedPaymentMethod = Rxn<OptionItem>();
  final expenseDate = DateTime.now().obs;
  final image = Rxn<File>();
  final isSaving = false.obs;

  final quantityController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  final vehicleError = ''.obs;
  final typeError = ''.obs;
  final quantityError = ''.obs;
  final amountError = ''.obs;
  final methodError = ''.obs;

  ExpenseModel? editing;
  bool get isEdit => editing != null;
  String get existingImageUrl =>
      editing == null || editing!.image.isEmpty ? '' : storageFileUrl(editing!.image);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['expense'] is ExpenseModel) {
      final e = args['expense'] as ExpenseModel;
      editing = e;
      selectedVehicle.value = e.vehicleNumber;
      selectedExpenseType.value = OptionItem(e.expenseType, e.expenseTypeLabel);
      selectedPaymentMethod.value = OptionItem(e.paymentMethod, e.paymentMethodLabel);
      if (e.expenseDate != null) expenseDate.value = e.expenseDate!;
      quantityController.text = e.quantity == null ? '' : formatAmount(e.quantity!).replaceAll(',', '');
      amountController.text = formatAmount(e.amount).replaceAll(',', '');
      descriptionController.text = e.description;
    }
    clearErrorOnEdit(quantityController, quantityError);
    clearErrorOnEdit(amountController, amountError);
    _loadOptions();
    _loadVehicles();
  }

  Future<void> _loadOptions() async {
    try {
      await ensureApiToken();
      final data = apiData(await DioClient().get(ApiEndPoints.expenseOptions));
      final types = OptionItem.listFrom(data['types']);
      final methods = OptionItem.listFrom(data['payment_methods']);
      expenseTypes.assignAll(types.isEmpty ? fallbackTypes : types);
      paymentMethods.assignAll(methods.isEmpty ? fallbackMethods : methods);
    } catch (_) {
      expenseTypes.assignAll(fallbackTypes);
      paymentMethods.assignAll(fallbackMethods);
    }
    final t = selectedExpenseType.value;
    if (t != null) {
      selectedExpenseType.value = expenseTypes.firstWhereOrNull((o) => o.key == t.key) ?? t;
    }
    final m = selectedPaymentMethod.value;
    if (m != null) {
      selectedPaymentMethod.value = paymentMethods.firstWhereOrNull((o) => o.key == m.key) ?? m;
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
      title: 'Select Expense Type',
      options: expenseTypes,
      labelOf: (o) => o.label,
      selected: selectedExpenseType.value,
    );
    if (t != null) {
      selectedExpenseType.value = t;
      typeError.value = '';
    }
  }

  Future<void> pickPaymentMethod() async {
    final m = await showOptionSheet<OptionItem>(
      title: 'Select Payment Method',
      options: paymentMethods,
      labelOf: (o) => o.label,
      selected: selectedPaymentMethod.value,
    );
    if (m != null) {
      selectedPaymentMethod.value = m;
      methodError.value = '';
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final d = await pickRecordDate(context, expenseDate.value);
    if (d != null) expenseDate.value = d;
  }

  bool validate() {
    vehicleError.value = selectedVehicle.value.isEmpty ? 'Vehicle selection is required' : '';
    typeError.value = selectedExpenseType.value == null ? 'Expense type is required' : '';
    methodError.value = selectedPaymentMethod.value == null ? 'Payment method is required' : '';

    final qtyText = quantityController.text.trim();
    final qty = num.tryParse(qtyText);
    quantityError.value =
        qtyText.isNotEmpty && (qty == null || qty < 0) ? 'Enter a valid quantity' : '';

    final amountText = amountController.text.trim();
    final amount = num.tryParse(amountText);
    amountError.value = amountText.isEmpty
        ? 'Amount is required'
        : (amount == null || amount < 0 ? 'Enter a valid amount' : '');

    return [vehicleError, typeError, methodError, quantityError, amountError]
        .every((e) => e.value.isEmpty);
  }

  Future<void> submitExpense() async {
    if (isSaving.value || !validate()) return;
    isSaving.value = true;
    try {
      await ensureApiToken();
      // update_expense replaces every field (a missing date or description is
      // cleared), so always send the full record.
      final form = FormData.fromMap({
        if (isEdit) 'id': editing!.id,
        'vehicle_number': selectedVehicle.value,
        'expense_type': selectedExpenseType.value!.key,
        'amount': amountController.text.trim(),
        'quantity': quantityController.text.trim(),
        'payment_method': selectedPaymentMethod.value!.key,
        'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate.value),
        'description': descriptionController.text.trim(),
      });
      await addImageField(form, image.value);
      final response = await DioClient().post(
        isEdit ? ApiEndPoints.updateExpense : ApiEndPoints.addExpense,
        body: form,
      );
      apiData(response, fallbackError: 'Could not save expense');
      Get.back(result: true);
      showRecordSuccess(isEdit ? 'Expense updated' : 'Expense added successfully');
    } catch (e) {
      showRecordError(e);
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    quantityController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
