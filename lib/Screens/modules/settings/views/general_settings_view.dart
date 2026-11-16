import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Services/AppSettings.dart';
import '../controllers/general_settings_controller.dart';

class GeneralSettingsView extends GetView<GeneralSettingsController> {
  const GeneralSettingsView({Key? key}) : super(key: key);

  AppSettings get s => controller.settings;

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
          'General Settings',
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
          child: Obx(
            () => Column(
              children: [
                const SizedBox(height: 10),
                _buildSettingItem(
                  iconPath: 'lib/Asset/Icons/Bells.png',
                  label: 'Notification',
                  trailing: _buildToggle(
                    s.notifications.value,
                    controller.setNotifications,
                  ),
                ),
                // "Show History on Live" is hidden for now; Live Track keeps
                // the saved choice (on by default).
                const SizedBox(height: 10),
                _buildChoiceSection<VehicleIconSize>(
                  key: 'icon',
                  iconPath: 'lib/Asset/Icons/Vehicle size.png',
                  label: 'Vehicle Icon Size',
                  current: s.iconSize.value,
                  options: const {
                    VehicleIconSize.small: 'Small',
                    VehicleIconSize.medium: 'Medium',
                    VehicleIconSize.large: 'Large',
                  },
                  onSelect: s.setIconSize,
                ),
                const SizedBox(height: 10),
                _buildChoiceSection<bool>(
                  key: 'time',
                  iconPath: 'lib/Asset/Icons/Time Format.png',
                  label: 'Time Format',
                  current: s.use24HourTime.value,
                  options: const {true: '24 hour', false: '12 hour (AM/PM)'},
                  onSelect: s.setUse24HourTime,
                ),
                const SizedBox(height: 10),
                _buildChoiceSection<bool>(
                  key: 'gauge',
                  iconPath: 'lib/Asset/Icons/Speedometer.png',
                  label: 'Speedometer',
                  current: s.showSpeedometer.value,
                  options: const {true: 'Show on Track', false: 'Hide'},
                  onSelect: s.setShowSpeedometer,
                ),
                const SizedBox(height: 10),
                _buildChoiceSection<AppMapType>(
                  key: 'map',
                  iconPath: 'lib/Asset/Icons/Map type.png',
                  label: 'Map Type',
                  current: s.mapType.value,
                  options: const {
                    AppMapType.normal: 'Default',
                    AppMapType.satellite: 'Satellite',
                    AppMapType.terrain: 'Terrain',
                  },
                  onSelect: s.setMapType,
                ),
                const SizedBox(height: 10),
                _buildChoiceSection<SpeedUnit>(
                  key: 'speed',
                  iconPath: 'lib/Asset/Icons/Top speed.png',
                  label: 'Speed',
                  current: s.speedUnit.value,
                  options: const {
                    SpeedUnit.kmh: 'km/h',
                    SpeedUnit.mph: 'mph',
                  },
                  onSelect: s.setSpeedUnit,
                ),
                const SizedBox(height: 10),
                _buildChoiceSection<DistanceUnit>(
                  key: 'distance',
                  iconPath: 'lib/Asset/Icons/Distance map.png',
                  label: 'Distance',
                  current: s.distanceUnit.value,
                  options: const {
                    DistanceUnit.km: 'Kilometres (km)',
                    DistanceUnit.miles: 'Miles (mi)',
                  },
                  onSelect: s.setDistanceUnit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A row that opens to a list of choices; the current one is shown on the
  /// row and marked in the list.
  Widget _buildChoiceSection<T>({
    required String key,
    required String iconPath,
    required String label,
    required T current,
    required Map<T, String> options,
    required void Function(T) onSelect,
  }) {
    final open = controller.expanded.value == key;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.toggleSection(key),
          child: _buildSettingItem(
            iconPath: iconPath,
            label: label,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  options[current] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF009FE3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                _buildDropdownArrow(isExpanded: open),
              ],
            ),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final entry in options.entries) ...[
                  _buildOption(
                    entry.value,
                    selected: entry.key == current,
                    onTap: () => onSelect(entry.key),
                  ),
                  if (entry.key != options.keys.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSettingItem({
    required String iconPath,
    required String label,
    required Widget trailing,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      padding: const EdgeInsets.only(top: 9, right: 11, bottom: 9, left: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(iconPath, width: 32, height: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  /// Same artwork as before; flipped means off.
  Widget _buildToggle(bool isOn, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!isOn),
      child: Transform.scale(
        scaleX: isOn ? 1.0 : -1.0,
        child: Opacity(
          opacity: isOn ? 1 : 0.45,
          child: Image.asset(
            'lib/Asset/Icons/swipe button.png',
            width: 40,
            height: 30,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownArrow({required bool isExpanded}) {
    return Transform.rotate(
      angle: isExpanded ? 3.14159 : 0,
      child: Image.asset(
        'lib/Asset/Icons/Down arrow.png',
        width: 19,
        height: 13,
        color: Colors.blue.shade700,
      ),
    );
  }

  /// Option row with the existing pill switch on the right.
  Widget _buildOption(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 38,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF009FE3)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    selected ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
