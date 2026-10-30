import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../../../routes/app_routes.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'edit') {
                Get.toNamed(Routes.EDIT_PROFILE);
              } else if (value == 'delete') {
                Get.toNamed(Routes.DELETE_ACCOUNT);
              }
            },
            color: Colors.white,
            elevation: 2,
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'edit',
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'delete',
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 5),
            Obx(() {
              final p = controller.profile.value;
              final name = p.name.isEmpty ? '—' : p.name;
              final mobile = p.mobile.isEmpty ? '—' : p.mobile;
              return Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: controller.isLoadingProfile.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                p.avatarInitial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'lib/Asset/Icons/Phone.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mobile,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 30),
            _buildSettingTile(
              iconPath: 'lib/Asset/Icons/General settings.png',
              label: 'General Settings',
              onTap: () => Get.toNamed(Routes.GENERAL_SETTINGS),
            ),
            _buildSettingTile(
              iconPath: 'lib/Asset/Images/geofence_icon.png',
              label: 'Geofence',
              onTap: () => Get.toNamed(Routes.GEOFENCE),
            ),
            _buildSettingTile(
              iconPath: 'lib/Asset/Icons/Raise ticket.png',
              label: 'Raise Ticket',
              onTap: () => Get.toNamed(Routes.RAISE_TICKET),
            ),
            _buildSettingTile(
              iconPath: 'lib/Asset/Icons/Change password.png',
              label: 'Change Password',
              onTap: () => Get.toNamed(Routes.CHANGE_PASSWORD),
            ),
            _buildSettingTile(
              iconPath: 'lib/Asset/Icons/Configure alerts.png',
              label: 'Configure Alerts',
              onTap: () => Get.toNamed(Routes.CONFIGURE_ALERTS),
            ),
            _buildSettingTile(
              iconPath: 'lib/Asset/Icons/Expense.png',
              label: 'Expense',
              onTap: () => Get.toNamed(Routes.EXPENSES),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 53),
              child: SizedBox(
                width: 284,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _confirmLogout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009FE3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'lib/Asset/Icons/Logout.png',
                        width: 23,
                        height: 23,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  /// Asks before signing out. Only a "Logout" tap calls [SettingsController.signOut].
  Future<void> _confirmLogout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFF009FE3)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.signOut();
    }
  }

  Widget _buildSettingTile({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 358,
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              Image.asset(iconPath, width: 24, height: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Image.asset('lib/Asset/Icons/Arrows.png', width: 24, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
