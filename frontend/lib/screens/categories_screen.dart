import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_widget.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Map<String, dynamic>? _categories;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.getCategories();
      setState(() {
        _categories = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'Low': return AppColors.riskLow;
      case 'Moderate': return AppColors.riskModerate;
      case 'High': return AppColors.riskHigh;
      case 'Critical': return AppColors.riskCritical;
      default: return AppDynamicColors.textSecondary(context);
    }
  }

  Color _getBmiColor(String category) {
    switch (category) {
      case 'Underweight': return AppColors.bmiUnderweight;
      case 'Normal': return AppColors.bmiNormal;
      case 'Overweight': return AppColors.bmiOverweight;
      case 'Obese': return AppColors.bmiObese;
      default: return AppDynamicColors.textSecondary(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: AppDynamicColors.textPrimary(context), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Patient Groups', style: AppTextStyles.heading3Dynamic(context)),
                  ],
                ),
              ),

              // ── Tab bar ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppDynamicColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppDynamicColors.textSecondary(context),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    tabs: const [
                      Tab(text: 'By BMI'),
                      Tab(text: 'By Age'),
                      Tab(text: 'By Risk'),
                    ],
                  ),
                ),
              ),

              // ── Content ────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _categories == null
                        ? const Center(child: Text('Failed to load'))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCategoryView(
                                  _categories!['by_bmi'], _getBmiColor),
                              _buildCategoryView(
                                  _categories!['by_age_group'],
                                  (_) => AppColors.primary),
                              _buildCategoryView(
                                  _categories!['by_risk_level'],
                                  _getRiskColor),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView(
      Map<String, dynamic> data, Color Function(String) colorFn) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: data.entries.map((entry) {
        final label = entry.key;
        final patients = entry.value as List;
        final color = colorFn(label);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppDynamicColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppDynamicColors.cardShadow(context),
            border: Border.all(color: AppDynamicColors.border(context)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${patients.length}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: AppTextStyles.bodyMediumDynamic(context)
                              .copyWith(color: color)),
                    ),
                    Text(
                      '${patients.length} patient${patients.length != 1 ? 's' : ''}',
                      style: AppTextStyles.captionDynamic(context),
                    ),
                  ],
                ),
              ),

              // Patients
              if (patients.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No patients in this category',
                      style: AppTextStyles.captionDynamic(context)),
                )
              else
                ...patients.map((p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                p['name'][0].toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'],
                                    style: AppTextStyles.bodyMediumDynamic(context)),
                                Text(
                                    'Age ${p['age']} • BMI ${p['bmi']}',
                                    style: AppTextStyles.captionDynamic(context)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRiskColor(p['risk_level'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p['risk_level'],
                              style: TextStyle(
                                color: _getRiskColor(p['risk_level']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

