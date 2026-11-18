import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/add_reminder_controller.dart';

class AddReminderView extends GetView<AddReminderController> {
  const AddReminderView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          controller.isEdit ? 'Edit Reminder' : 'Add Reminder',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _label('Select Vehicle'),
                    Obx(
                      () => PickerField(
                        hint: 'Select Vehicle',
                        value: controller.selectedVehicle.value,
                        onTap: controller.vehicleLocked.value
                            ? null
                            : controller.pickVehicle,
                        trailing: controller.vehicleLocked.value
                            ? const SizedBox.shrink()
                            : null,
                      ),
                    ),
                    FieldError(controller.vehicleError),
                    const SizedBox(height: 16),
                    _label('Select Type'),
                    Obx(
                      () => PickerField(
                        hint: 'Select Reminder Type',
                        value: controller.selectedType.value?.label ?? '',
                        onTap: controller.pickType,
                      ),
                    ),
                    FieldError(controller.typeError),
                    const SizedBox(height: 16),
                    _label('Start'),
                    _input(
                      controller.odometerController,
                      'Enter Starting Odometer',
                      number: true,
                    ),
                    FieldError(controller.odometerError),
                    const SizedBox(height: 16),
                    _label('Period'),
                    _input(
                      controller.periodController,
                      'Enter the Odometer Period for Alerts',
                      number: true,
                    ),
                    FieldError(controller.periodError),
                    const SizedBox(height: 16),
                    _label('Remarks'),
                    _input(controller.remarksController, 'Optional note'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Obx(
                () => GestureDetector(
                  onTap: controller.submit,
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: controller.isSaving.value
                          ? kRecordsBlue.withOpacity(0.6)
                          : kRecordsBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: controller.isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            controller.isEdit ? 'Update' : 'Submit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      );

  Widget _input(TextEditingController c, String hint, {bool number = false}) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        style: const TextStyle(fontSize: 13),
        inputFormatters: number ? decimalInputFormatters : null,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
    );
  }
}
