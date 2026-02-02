import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/general_settings_controller.dart';

class GeneralSettingsView extends GetView<GeneralSettingsController> {
  const GeneralSettingsView({Key? key}) : super(key: key);

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
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Bells.png',
                label: 'Notification',
                trailing: _buildToggle(true),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Live history.png',
                label: 'Show History on Live',
                trailing: _buildToggle(true),
              ),
              const SizedBox(height: 10),
              // Vehicle Icon Size Expandable
              Obx(
                () => Column(
                  children: [
                    GestureDetector(
                      onTap: () => controller.toggleVehicleIconSize(),
                      child: _buildSettingItem(
                        iconPath: 'lib/Asset/Icons/Vehicle size.png',
                        label: 'Vehicle Icon Size',
                        trailing: _buildDropdownArrow(
                          isExpanded:
                              controller.isVehicleIconSizeExpanded.value,
                        ),
                      ),
                    ),
                    if (controller.isVehicleIconSizeExpanded.value)
                      _buildVehicleIconSizeOptions(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Time Format.png',
                label: 'Time Format',
                trailing: _buildDropdownArrow(isExpanded: false),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Speedometer.png',
                label: 'Speedometer',
                trailing: _buildDropdownArrow(isExpanded: false),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Map type.png',
                label: 'Map Type',
                trailing: _buildDropdownArrow(isExpanded: false),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Top speed.png',
                label: 'Speed',
                trailing: _buildDropdownArrow(isExpanded: false),
              ),
              const SizedBox(height: 10),
              _buildSettingItem(
                iconPath: 'lib/Asset/Icons/Distance map.png',
                label: 'Distance',
                trailing: _buildDropdownArrow(isExpanded: false),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String iconPath,
    required String label,
    required Widget trailing,
  }) {
    return Container(
      width: 358,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(iconPath, width: 32, height: 32),
              const SizedBox(width: 15),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildToggle(bool initialValue) {
    return SwipeToggle(initialValue: initialValue);
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

  Widget _buildVehicleIconSizeOptions() {
    return Container(
      width: 358,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
          _buildSizeOption("Small"),
          const SizedBox(height: 12),
          _buildSizeOption("Medium"),
          const SizedBox(height: 12),
          _buildSizeOption("Large"),
        ],
      ),
    );
  }

  Widget _buildSizeOption(String label) {
    return Container(
      width: 250,
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Obx(() {
            bool isSelected = controller.selectedSize.value == label;
            return GestureDetector(
              onTap: () => controller.selectSize(label),
              child: Container(
                width: 38,
                height: 22,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isSelected
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SwipeToggle extends StatefulWidget {
  final bool initialValue;
  const SwipeToggle({Key? key, required this.initialValue}) : super(key: key);

  @override
  _SwipeToggleState createState() => _SwipeToggleState();
}

class _SwipeToggleState extends State<SwipeToggle> {
  late bool _isOn;

  @override
  void initState() {
    super.initState();
    _isOn = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isOn = !_isOn;
        });
      },
      child: Transform.scale(
        scaleX: _isOn ? 1.0 : -1.0,
        child: Image.asset(
          'lib/Asset/Icons/swipe button.png',
          width: 40,
          height: 30,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
