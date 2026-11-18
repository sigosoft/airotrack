import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/support_tickets_controller.dart';

/// Status chip colours by API status key (1 Pending, 2 Processing, 3 Solved, 4 Closed).
Color ticketStatusColor(int status) {
  switch (status) {
    case 1:
      return const Color(0xFFF5A623);
    case 3:
      return const Color(0xFF2EB872);
    case 4:
      return Colors.grey;
    case 2:
    default:
      return kRecordsBlue;
  }
}

class SupportTicketView extends GetView<SupportTicketsController> {
  const SupportTicketView({Key? key}) : super(key: key);

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
          'Support Tickets',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),
                RecordsSearchField(
                  hint: 'Search Device or Ticket Id',
                  controller: controller.searchController,
                  onChanged: controller.onSearchChanged,
                  radius: 25,
                ),
                const SizedBox(height: 20),
                PeriodFilterRow(controller: controller),
                const SizedBox(height: 25),
                Expanded(
                  child: RecordsListBody<SupportTicketModel>(
                    controller: controller,
                    emptyText: 'No tickets found.\nTap + to raise one.',
                    padding: const EdgeInsets.only(bottom: 160),
                    spacing: 10,
                    itemBuilder: (context, t) => _TicketTile(
                      ticket: t,
                      onTap: () => _showDetails(t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
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
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'raise_ticket_fab',
                  onPressed: controller.openRaise,
                  backgroundColor: kRecordsBlue,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(SupportTicketModel t) {
    dismissKeyboard();
    Get.bottomSheet(
      _TicketDetailsSheet(controller: controller, initial: t),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;
  const _TicketTile({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.vehicleNumber,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      children: [
                        const TextSpan(text: 'Ticket Type: '),
                        TextSpan(
                          text: t.typeLabel,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    t.createdAt == null ? '' : recordDateTimeFmt.format(t.createdAt!),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kRecordsBlue, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Text('Ticket', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('Id:${t.id}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                _StatusChip(status: t.status, label: t.statusLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int status;
  final String label;
  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ticketStatusColor(status),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final SupportTicketsController controller;
  final SupportTicketModel initial;
  const _TicketDetailsSheet({required this.controller, required this.initial});

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  late SupportTicketModel t = widget.initial;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.fetchTicket(t.id).then((fresh) {
      if (!mounted) return;
      setState(() {
        if (fresh != null) t = fresh;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = t.image.isEmpty ? '' : storageFileUrl(t.image);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Ticket #${t.id}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  _StatusChip(status: t.status, label: t.statusLabel),
                ],
              ),
              const SizedBox(height: 12),
              _row('Vehicle', t.vehicleNumber),
              _row('Type', t.typeLabel),
              if (t.contactNo.isNotEmpty) _row('Contact', t.contactNo),
              _row('Raised on', t.createdAt == null ? '-' : recordDateTimeFmt.format(t.createdAt!)),
              _row('Message', t.message),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => openImageViewer(imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl,
                        width: 160,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Status History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: kRecordsBlue),
                  ),
                )
              else if (t.statusLogs.isEmpty)
                const Text('No updates yet', style: TextStyle(color: Colors.grey, fontSize: 13))
              else
                for (final log in t.statusLogs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle, size: 10, color: ticketStatusColor(log.toStatus)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.toStatusLabel,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (log.remarks.isNotEmpty)
                                Text(log.remarks,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              if (log.createdAt != null)
                                Text(recordDateTimeFmt.format(log.createdAt!),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
