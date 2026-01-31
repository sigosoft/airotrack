import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LockCommandView extends StatelessWidget {
  const LockCommandView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            margin: const EdgeInsets.all(12),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        title: const Text(
          "Send Command",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Main Container
          Positioned(
            top:
                20, // Strictly following user spec (assuming relative to body/stack)
            left: 16,
            width: 358,
            height: 252,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: 16,
                    left: 16,
                    child: Text(
                      "KL 07 D 0518",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  // Stop Engine Button
                  Positioned(
                    top: 54.04,
                    left: 40,
                    child: _buildLockOption(
                      label: "Stop Engine",
                      color: const Color(0xFFFF5252), // Red
                      iconPath: 'lib/Asset/Icons/Lock.png',
                      width: 85.75,
                      height: 85.75,
                      onTap: () => _showStopEngineDialog(context),
                    ),
                  ),

                  // Resume Engine Button
                  // Placing it symmetrically as per design implied
                  Positioned(
                    top: 54.04,
                    right: 40,
                    child: _buildLockOption(
                      label: "Resume Engine",
                      color: const Color(0xFF00C853), // Green
                      iconPath: 'lib/Asset/Icons/Lock.png',
                      width: 85.75,
                      height: 85.75,
                      onTap: () => _showResumeEngineDialog(context),
                    ),
                  ),

                  const Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Text(
                      "Note: For emergency use only. Please do not use in areas where\nGSM network connectivity is poor.",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Command History Title
          // Placed between the container and the list (approx top 390)
          const Positioned(
            top: 300,
            left: 16,
            child: Text(
              "Command History",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          // Tile 1 (Stop Engine History)
          Positioned(
            top: 340,
            left: 16,
            width: 357.96,
            height: 85.56,
            child: _buildHistoryTile(
              title: "Stop Engine",
              time: "Sent on Oct 17, 2025 5:38:08 PM",
              status: "Engine Stoped successfully",
              color: const Color(0xFFFF5252),
              iconPath: 'lib/Asset/Icons/Lock.png',
            ),
          ),

          // Tile 2 (Resume Engine History) - Placed below with gap 10px
          Positioned(
            top: 430,
            left: 16,
            width: 357.96,
            height: 85.56,
            child: _buildHistoryTile(
              title: "Resume Engine",
              time: "Sent on Oct 17, 2025 5:38:08 PM",
              status: "Engine Resumed successfully",
              color: const Color(0xFF00C853),
              iconPath: 'lib/Asset/Icons/Lock.png',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockOption({
    required String label,
    required Color color,
    required String iconPath,
    required double width,
    required double height,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 3),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Image.asset(iconPath, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile({
    required String title,
    required String time,
    required String status,
    required Color color,
    required String iconPath,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 14, right: 21, bottom: 14, left: 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            padding: const EdgeInsets.all(10),
            child: Image.asset(iconPath, color: color),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
                Text(
                  status,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResumeEngineDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 357,
            height: 170,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Resume Engine",
                  style: TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Are you sure you want to resume the engine?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // No Button
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width:
                            120, // Adjusted to fit within 357 width with spacing
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "No",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Yes Button
                    GestureDetector(
                      onTap: () {
                        // Add logic here if needed
                        Get.back();
                        _showSuccessDialog(
                          context,
                          "Engine Resumed Successfully",
                          "The vehicle engine has been successfully resumed.",
                        );
                      },
                      child: Container(
                        width: 120, // Adjusted to fit
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009FE3),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Yes",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStopEngineDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 357,
            height: 170,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Stop Engine",
                  style: TextStyle(
                    color: Color(0xFFFF5252), // Red color
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Are you sure you want to stop the engine?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // No Button
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 120,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "No",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Yes Button
                    GestureDetector(
                      onTap: () {
                        // Add logic here if needed
                        Get.back();
                        _showSuccessDialog(
                          context,
                          "Engine Stopped Successfully",
                          "The vehicle engine has been turned off.",
                        );
                      },
                      child: Container(
                        width: 120,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009FE3),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Yes",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 357,
            height: 203,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Success Image/Icon
                Positioned(
                  top: 7.78,
                  left: 120,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Image.asset('lib/Asset/Icons/Success.png'),
                  ),
                ),

                // Text Content
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // OK Button
                Positioned(
                  top: 146,
                  left: 35,
                  child: GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 230,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF009FE3),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Ok",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
