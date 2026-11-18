import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/routes/app_routes.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:get/get.dart';

/// Support tickets list (`support_tickets`) with search, period filter,
/// paging and ticket details. The API has no edit or delete for tickets.
class SupportTicketsController extends PagedRecordsController<SupportTicketModel> {
  @override
  Future<(List<SupportTicketModel>, PageInfo, Map<String, dynamic>)> fetchPage(
    Map<String, dynamic> query,
  ) async {
    final response = await DioClient().get(ApiEndPoints.supportTickets, query: query);
    final data = apiData(response, fallbackError: 'Could not load tickets');
    final list = data['tickets'];
    final rows = list is List
        ? list.whereType<Map>().map(SupportTicketModel.fromJson).toList()
        : <SupportTicketModel>[];
    return (rows, PageInfo.fromJson(data['pagination']), data);
  }

  /// Full ticket with status history from `view_support_ticket`.
  Future<SupportTicketModel?> fetchTicket(int id) async {
    try {
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.viewSupportTicket, query: {'id': id});
      final t = apiData(response, fallbackError: 'Could not load ticket')['ticket'];
      return t is Map ? SupportTicketModel.fromJson(t) : null;
    } catch (e) {
      showRecordError(e);
      return null;
    }
  }

  Future<void> openRaise() async {
    dismissKeyboard();
    final saved = await Get.toNamed(Routes.RAISE_TICKET);
    if (saved == true) refreshList();
  }
}
