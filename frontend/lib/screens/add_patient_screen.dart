import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_widget.dart';
import '../utils/string_extensions.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final ApiService _api = ApiService();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = 'male';
  String _activityLevel = 'moderate';
  bool _isLoading = false;

  final List<Map<String, String>> _activityLevels = [
    {'value': 'sedentary', 'label': 'Sedentary (little or no exercise)'},
    {'value': 'light', 'label': 'Light (1-3 days/week)'},
    {'value': 'moderate', 'label': 'Moderate (3-5 days/week)'},
    {'value': 'active', 'label': 'Active (6-7 days/week)'},
    {'value': 'very_active', 'label': 'Very Active (twice/day)'},
  ];

  Future<void> _addPatient() async {
    if (_nameController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.addPatient({
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text),
        'gender': _gender,
        'weight': double.parse(_weightController.text),
        'height': double.parse(_heightController.text),
        'activity_level': _activityLevel,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add patient'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Widget _buildTextField(String label, TextEditingController controller,
      IconData icon, TextInputType keyboardType, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyDynamic(context),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title, style: AppTextStyles.captionMediumDynamic(context).copyWith(
        letterSpacing: 0.5,
        color: AppDynamicColors.textSecondary(context),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: AppDynamicColors.textPrimary(context), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('New Patient', style: AppTextStyles.heading3Dynamic(context)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Personal Info ──────────────────
                      _buildSectionTitle('PERSONAL INFORMATION'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDynamicColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppDynamicColors.cardShadow(context),
                          border: Border.all(color: AppDynamicColors.border(context)),
                        ),
                        child: Column(
                          children: [
                            _buildTextField('Full Name', _nameController,
                                Icons.badge_outlined, TextInputType.name,
                                hint: 'Enter patient full name'),
                            const SizedBox(height: 12),
                            _buildTextField('Age', _ageController,
                                Icons.cake_outlined, TextInputType.number,
                                hint: 'Years'),
                            const SizedBox(height: 12),

                            // Gender
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppDynamicColors.surfaceVariant(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppDynamicColors.border(context)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _gender,
                                  isExpanded: true,
                                  icon: Icon(Icons.expand_more,
                                      color: AppDynamicColors.textSecondary(context)),
                                  style: AppTextStyles.bodyDynamic(context),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Row(children: [
                                        const Icon(Icons.male,
                                            color: AppColors.primary,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        const Text('Male'),
                                      ]),
                                    ),
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Row(children: [
                                        const Icon(Icons.female,
                                            color: AppColors.primary,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        const Text('Female'),
                                      ]),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _gender = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Body Measurements ──────────────
                      _buildSectionTitle('BODY MEASUREMENTS'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDynamicColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppDynamicColors.cardShadow(context),
                          border: Border.all(color: AppDynamicColors.border(context)),
                        ),
                        child: Column(
                          children: [
                            _buildTextField('Weight', _weightController,
                                Icons.monitor_weight_outlined,
                                TextInputType.number, hint: 'Kilograms (kg)'),
                            const SizedBox(height: 12),
                            _buildTextField('Height', _heightController,
                                Icons.straighten, TextInputType.number,
                                hint: 'Centimeters (cm)'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Activity Level ─────────────────
                      _buildSectionTitle('ACTIVITY LEVEL'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDynamicColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppDynamicColors.cardShadow(context),
                          border: Border.all(color: AppDynamicColors.border(context)),
                        ),
                        child: Column(
                          children: _activityLevels.map((level) {
                            final isSelected =
                                _activityLevel == level['value'];
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _activityLevel = level['value']!),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : AppDynamicColors.surfaceVariant(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppDynamicColors.border(context),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_run,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppDynamicColors.textSecondary(context),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        level['label']!,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppDynamicColors.textPrimary(context),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.primary, size: 18),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Submit ─────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addPatient,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Add Patient'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


