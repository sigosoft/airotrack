import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Screens/modules/history/views/Widgets/history_bottom_nav_bar.dart';
import '../Screens/routes/app_routes.dart';

enum AppNavTab { track, history, alerts, statistics }

/// Bottom navigation with the same look as the History screen's bar, shared by
/// Track and Statistics. Every tab carries the current vehicle, so Track never
/// opens without its car.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selected,
    required this.imei,
    required this.plate,
    this.onSelectedTap,
  });

  final AppNavTab selected;
  final String imei;
  final String plate;

  /// Runs when the tab for the current screen is tapped (History does nothing).
  final VoidCallback? onSelectedTap;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final hasVehicle = imei.trim().isNotEmpty;

    VoidCallback tap(AppNavTab tab, VoidCallback go) {
      return () {
        if (tab == selected) {
          onSelectedTap?.call();
          return;
        }
        go();
      };
    }

    return Container(
      height: height * 0.1,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/Location.png',
            label: 'Track',
            isSelected: selected == AppNavTab.track,
            onTap: tap(
              AppNavTab.track,
              () => Get.offNamed(
                Routes.TRACK,
                parameters: hasVehicle
                    ? {'imei': imei, 'vehicleId': plate}
                    : null,
              ),
            ),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/history.png',
            label: 'History',
            isSelected: selected == AppNavTab.history,
            onTap: tap(
              AppNavTab.history,
              () => Get.offNamed(
                Routes.HISTORY,
                parameters: hasVehicle
                    ? {'imei': imei, 'vehicleId': plate}
                    : null,
              ),
            ),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/notification.png',
            label: 'Alerts',
            isSelected: selected == AppNavTab.alerts,
            onTap: tap(
              AppNavTab.alerts,
              // Named differently from 'imei' so the alerts list is not
              // filtered; Alerts uses these only to return to this vehicle.
              () => Get.offNamed(
                Routes.ALERTS,
                parameters: hasVehicle
                    ? {
                        'trackImei': imei,
                        'trackPlate': plate,
                        'from': selected.name,
                      }
                    : null,
              ),
            ),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/statistics.png',
            label: 'Statistics',
            isSelected: selected == AppNavTab.statistics,
            onTap: tap(
              AppNavTab.statistics,
              () => Get.toNamed(
                Routes.STATISTICS,
                parameters: hasVehicle ? {'imei': imei, 'plate': plate} : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
