import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/reminders_controller.dart';

class RemindersView extends GetView<RemindersController> {
  const RemindersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reminders',
          style: TextStyle(
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                RecordsSearchField(
                  hint: 'Search Vehicle Number',
                  controller: controller.searchController,
                  onChanged: controller.onSearchChanged,
                  radius: 12,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RecordsListBody<ReminderModel>(
                    controller: controller,
                    emptyText: 'No reminders yet.\nTap + to add one.',
                    padding: const EdgeInsets.only(bottom: 90),
                    itemBuilder: (context, r) => ReminderTile(
                      reminder: r,
                      onEdit: () => controller.openEdit(r),
                      onDelete: () => controller.delete(r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 16,
            child: AddReminderButton(onTap: controller.openAdd),
          ),
        ],
      ),
    );
  }
}

/// The round blue + button shared by the Reminders page and tab.
class AddReminderButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddReminderButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: kRecordsBlue,
          borderRadius: BorderRadius.circular(22.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}

/// One reminder row. Shared by the Reminders page and the Reminders tab on
/// the Notifications screen so both look the same.
class ReminderTile extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReminderTile({
    super.key,
    required this.reminder,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final km = (num v) => '${formatAmount(v)} km';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Image.asset(
            'lib/Asset/Icons/Car.png',
            width: 24,
            height: 24,
            color: kRecordsBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.typeLabel.isEmpty ? 'Reminder' : r.typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vehicle: ${r.vehicleNumber}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  'Period: ${km(r.period)}  ·  Due at: ${km(r.dueAt)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                if (r.remarks.isNotEmpty)
                  Text(
                    r.remarks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'lib/Asset/Icons/Edit.png',
                    width: 15,
                    height: 15,
                    color: kRecordsBlue,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'lib/Asset/Icons/Delete.png',
                    width: 20,
                    height: 20,
                    color: const Color.fromARGB(255, 252, 90, 9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
