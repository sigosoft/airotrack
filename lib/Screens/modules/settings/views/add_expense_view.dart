import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class AddExpenseView extends StatelessWidget {
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
        title: const Text(
          'Add Expense',
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
              _buildLabel('Select Vehicle'),
              const SizedBox(height: 9),
              _buildDropdownField('Select Vehicle'),

              const SizedBox(height: 15),
              _buildLabel('Date'),
              const SizedBox(height: 9),
              _buildDateField('13 Oct 2025 10:40 AM'),

              const SizedBox(height: 15),
              _buildLabel('Expense Type'),
              const SizedBox(height: 9),
              _buildDropdownField('Select Expense Type'),

              const SizedBox(height: 15),
              _buildLabel('Quantity'),
              const SizedBox(height: 9),
              _buildTextField('Enter Quantity'),

              const SizedBox(height: 15),
              _buildLabel('Amount'),
              const SizedBox(height: 9),
              _buildTextField('Enter Amount'),

              const SizedBox(height: 15),
              _buildLabel('Payment Method'),
              const SizedBox(height: 9),
              _buildDropdownField('Select Payment Method'),

              const SizedBox(height: 15),
              _buildLabel('Expense Description'),
              const SizedBox(height: 9),
              Container(
                width: 358,
                height: 94,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
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
              Container(
                width: 107.25,
                height: 111.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 30,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload Image',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: 360,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Get.offAllNamed(
                      Routes.HOME,
                    ); // Navigating to home/settings as requested
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009FE3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

  Widget _buildDropdownField(String hint) {
    return Container(
      width: 358,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Image.asset(
            'lib/Asset/Icons/Down arrow.png',
            width: 15,
            height: 10,
            color: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String date) {
    return Container(
      width: 358,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Image.asset('lib/Asset/Icons/Calender.png', width: 20, height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return Container(
      width: 358,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(bottom: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
