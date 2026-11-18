import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_expense_controller.dart';

class AddExpenseView extends GetView<AddExpenseController> {
  const AddExpenseView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          controller.isEdit ? 'Edit Expense' : 'Add Expense',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildLabel('Select Vehicle'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Vehicle',
                  value: controller.selectedVehicle.value,
                  onTap: controller.pickVehicle,
                ),
              ),
              FieldError(controller.vehicleError),

              const SizedBox(height: 15),
              _buildLabel('Date'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Date',
                  value: recordDateFmt.format(controller.expenseDate.value),
                  onTap: () => controller.pickDate(context),
                  trailing: Image.asset('lib/Asset/Icons/Calender.png', width: 20, height: 20),
                ),
              ),

              const SizedBox(height: 15),
              _buildLabel('Expense Type'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Expense Type',
                  value: controller.selectedExpenseType.value?.label ?? '',
                  onTap: controller.pickType,
                ),
              ),
              FieldError(controller.typeError),

              const SizedBox(height: 15),
              _buildLabel('Quantity'),
              const SizedBox(height: 9),
              _buildTextField('Enter Quantity (optional)', controller.quantityController),
              FieldError(controller.quantityError),

              const SizedBox(height: 15),
              _buildLabel('Amount'),
              const SizedBox(height: 9),
              _buildTextField('Enter Amount', controller.amountController),
              FieldError(controller.amountError),

              const SizedBox(height: 15),
              _buildLabel('Payment Method'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Payment Method',
                  value: controller.selectedPaymentMethod.value?.label ?? '',
                  onTap: controller.pickPaymentMethod,
                ),
              ),
              FieldError(controller.methodError),

              const SizedBox(height: 15),
              _buildLabel('Expense Description'),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                height: 94,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: controller.descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter Description',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              const SizedBox(height: 15),
              _buildLabel('Upload Image'),
              const SizedBox(height: 9),
              ImageUploadBox(
                file: controller.image,
                existingUrl: controller.existingImageUrl,
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isSaving.value ? null : controller.submitExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRecordsBlue,
                      disabledBackgroundColor: kRecordsBlue.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: controller.isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            controller.isEdit ? 'Update' : 'Submit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: 20 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController fieldController) {
    return Container(
      width: double.infinity,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: fieldController,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(bottom: 12),
        ),
        style: const TextStyle(fontSize: 14),
        inputFormatters: decimalInputFormatters,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
