import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddExpenseController extends GetxController {
  final RxString selectedVehicle = ''.obs;
  final RxString selectedExpenseType = ''.obs;
  final RxString selectedPaymentMethod = ''.obs;
  final quantityController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  final vehicleError = ''.obs;
  final typeError = ''.obs;
  final quantityError = ''.obs;
  final amountError = ''.obs;
  final methodError = ''.obs;

  bool validate() {
    bool isValid = true;
    if (selectedVehicle.value.isEmpty) {
      vehicleError.value = 'Vehicle selection is required';
      isValid = false;
    } else {
      vehicleError.value = '';
    }

    if (selectedExpenseType.value.isEmpty) {
      typeError.value = 'Expense type is required';
      isValid = false;
    } else {
      typeError.value = '';
    }

    if (quantityController.text.trim().isEmpty) {
      quantityError.value = 'Quantity is required';
      isValid = false;
    } else {
      quantityError.value = '';
    }

    if (amountController.text.trim().isEmpty) {
      amountError.value = 'Amount is required';
      isValid = false;
    } else {
      amountError.value = '';
    }

    if (selectedPaymentMethod.value.isEmpty) {
      methodError.value = 'Payment method is required';
      isValid = false;
    } else {
      methodError.value = '';
    }

    return isValid;
  }

  void submitExpense() {
    if (validate()) {
      Get.back();
      Get.snackbar(
        'Success',
        'Expense added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
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
