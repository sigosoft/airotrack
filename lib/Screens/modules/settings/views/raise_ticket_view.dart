import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/raise_ticket_controller.dart';

class RaiseTicketView extends GetView<RaiseTicketController> {
  const RaiseTicketView({Key? key}) : super(key: key);

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
        title: const Text(
          'Raise Ticket',
          style: TextStyle(
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
              _label('Select Vehicle'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Vehicle',
                  value: controller.selectedVehicle.value,
                  onTap: controller.pickVehicle,
                ),
              ),
              FieldError(controller.vehicleError),
              const SizedBox(height: 10),
              _label('Type'),
              const SizedBox(height: 9),
              Obx(
                () => PickerField(
                  hint: 'Select Ticket Type',
                  value: controller.selectedType.value?.label ?? '',
                  onTap: controller.pickType,
                ),
              ),
              FieldError(controller.typeError),
              const SizedBox(height: 10),
              _label('Contact Number'),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: controller.contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Number we can call you on',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              FieldError(controller.contactError),
              const SizedBox(height: 10),
              _label('Message'),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                height: 94,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: controller.messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              FieldError(controller.messageError),
              const SizedBox(height: 10),
              _label('Upload Image'),
              const SizedBox(height: 9),
              ImageUploadBox(file: controller.image),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isSaving.value ? null : controller.submitTicket,
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
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              // Room for the call / WhatsApp buttons (2 x 40 + gap, the FAB
              // margin and the system nav inset), so Submit always ends above
              // them, scrolled or not.
              SizedBox(height: 130 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {},
            child: Image.asset(
              'lib/Asset/Icons/call chat.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: Image.asset(
              'lib/Asset/Icons/whatsapp chat.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      );
}
