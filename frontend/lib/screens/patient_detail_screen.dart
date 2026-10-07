import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_widget.dart';
import '../utils/string_extensions.dart';
import '../utils/export_helper.dart';

class PatientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Map<String, dynamic>? _calculations;
  Map<String, dynamic>? _risk;
  Map<String, dynamic>? _recommendations;
  Map<String, dynamic>? _compareData;
  Map<String, dynamic>? _explanation;
  bool _isLoading = true;
  bool _showRecommendations = false;
  bool _showCalcLogic = false;
  bool _showHowItWorks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final id = widget.patient['id'];
      final results = await Future.wait([
        _api.getCalculations(id),
        _api.getRisk(id),
        _api.getRecommendations(id),
        _api.compareModels(id),
        _api.explainRisk(id),
      ]);
      setState(() {
        _calculations = results[0].data;
        _risk = results[1].data;
        _recommendations = results[2].data;
        _compareData = results[3].data;
        _explanation = results[4].data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
  try {
    final response = await _api.exportCsvBytes();
    final bytes = Uint8List.fromList(response.data);
    await ExportHelper.exportCsv(context, bytes);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export CSV')),
      );
    }
  }
}
  
  Future<void> _exportPdf() async {
  try {
    final response = await _api
        .exportPatientPdf(widget.patient['id']);
    final bytes = Uint8List.fromList(response.data);
    await ExportHelper.exportPdf(
        context, bytes, widget.patient['name']);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export PDF')),
      );
    }
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

  Color _getRiskBgColor(String risk) {
    switch (risk) {
      case 'Low': return AppColors.riskLowLight;
      case 'Moderate': return AppColors.riskModerateLight;
      case 'High': return AppColors.riskHighLight;
      case 'Critical': return AppColors.riskCriticalLight;
      default: return AppDynamicColors.surfaceVariant(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        showShapes: false,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              Container(
                color: AppDynamicColors.surface(context),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios,
                                color: AppDynamicColors.textPrimary(context), size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.patient['name'],
                                    style: AppTextStyles.heading3Dynamic(context)),
                                Text(
                                  'Age ${widget.patient['age']} • ${widget.patient['gender'].toString().capitalize()}',
                                  style: AppTextStyles.captionDynamic(context),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
  icon: const Icon(Icons.picture_as_pdf_outlined,
      color: AppColors.riskHigh),
  tooltip: 'Export PDF',
  onPressed: _exportPdf,
),
IconButton(
  icon: const Icon(Icons.download_outlined,
      color: AppColors.primary),
  tooltip: 'Export CSV',
  onPressed: _exportCsv,
),
                        ],
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Health Risk'),
                        Tab(text: 'Nutrition Plan'),
                        Tab(text: 'Analysis'),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Content ──────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildRiskTab(),
                          _buildNutritionTab(),
                          _buildAnalysisTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Overview Tab ────────────────────────────────────────
  Widget _buildOverviewTab() {
    if (_calculations == null) return _errorWidget();
    final macros = _calculations!['macronutrients'];
    final bmi = _calculations!['bmi'];
    final bmiCategory = _calculations!['bmi_category'];

    Color bmiColor;
    switch (bmiCategory) {
      case 'Underweight': bmiColor = AppColors.bmiUnderweight; break;
      case 'Normal': bmiColor = AppColors.bmiNormal; break;
      case 'Overweight': bmiColor = AppColors.bmiOverweight; break;
      default: bmiColor = AppColors.bmiObese;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // BMI Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bmiColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bmiColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: bmiColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      bmi.toString(),
                      style: TextStyle(
                        color: bmiColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BMI',
                          style: AppTextStyles.captionDynamic(context)),
                      Text(bmiCategory,
                          style: TextStyle(
                            color: bmiColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )),
                      Text('Normal range: 18.5 - 24.9',
                          style: AppTextStyles.captionDynamic(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metrics row
          Row(
            children: [
              Expanded(
                child: _metricCard('BMR',
                    '${_calculations!['bmr']}',
                    '', 'Base metabolic rate',
                    Icons.local_fire_department_outlined,
                    AppColors.riskHigh),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard('TDEE',
                    '${_calculations!['tdee']}',
                    '', 'Daily energy expenditure',
                    Icons.bolt_outlined,
                    AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Patient details
          _sectionCard('Patient Details', [
            _detailRow(Icons.person_outline, 'Name',
                widget.patient['name']),
            _detailRow(Icons.cake_outlined, 'Age',
                '${widget.patient['age']} years'),
            _detailRow(Icons.wc, 'Gender',
                widget.patient['gender'].toString().capitalize()),
            _detailRow(Icons.monitor_weight_outlined, 'Weight',
                '${widget.patient['weight']} kg'),
            _detailRow(Icons.straighten, 'Height',
                '${widget.patient['height']} cm'),
            _detailRow(Icons.directions_run, 'Activity',
                widget.patient['activity_level']
                    .toString()
                    .replaceAll('_', ' ')
                    .capitalize()),
          ]),
          const SizedBox(height: 16),

          // Macros chart
          _sectionCard('Daily Macronutrient Targets', [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: macros['protein_g'].toDouble(),
                      title: '${macros['protein_g']}g\nProtein',
                      color: AppColors.chartProtein,
                      radius: 65,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                    PieChartSectionData(
                      value: macros['carbs_g'].toDouble(),
                      title: '${macros['carbs_g']}g\nCarbs',
                      color: AppColors.chartCarbs,
                      radius: 65,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                    PieChartSectionData(
                      value: macros['fats_g'].toDouble(),
                      title: '${macros['fats_g']}g\nFats',
                      color: AppColors.chartFats,
                      radius: 65,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendDot('Protein', AppColors.chartProtein),
                _legendDot('Carbohydrates', AppColors.chartCarbs),
                _legendDot('Fats', AppColors.chartFats),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  // ── Risk Tab ─────────────────────────────────────────────
  Widget _buildRiskTab() {
    if (_risk == null) return _errorWidget();
    final riskLevel = _risk!['risk_level'];
    final riskColor = _getRiskColor(riskLevel);
    final riskBg = _getRiskBgColor(riskLevel);

    // Filter out non-risk messages
    final risks = (_risk!['risks'] as List)
        .where((r) => !r.toString().contains('No significant'))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Risk level hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: riskBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: riskColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(_getRiskIcon(riskLevel),
                    color: riskColor, size: 48),
                const SizedBox(height: 12),
                Text(riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    )),
                Text('Health Risk Level',
                    style: AppTextStyles.captionDynamic(context)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Confidence: ${_risk!['confidence']}',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Risk probability bars
          _sectionCard('Risk Level Breakdown', [
            _probabilityBar('Low', _risk!['risk_probabilities']['Low'].toDouble(), AppColors.riskLow),
            _probabilityBar('Moderate', _risk!['risk_probabilities']['Moderate'].toDouble(), AppColors.riskModerate),
            _probabilityBar('High', _risk!['risk_probabilities']['High'].toDouble(), AppColors.riskHigh),
            _probabilityBar('Critical', _risk!['risk_probabilities']['Critical'].toDouble(), AppColors.riskCritical),
          ]),
          const SizedBox(height: 16),

          // Risk factors  Eonly show if there are actual risks
          if (risks.isNotEmpty) ...[
            _sectionCard('Contributing Factors', [
              ...risks.map((risk) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: riskColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(risk,
                              style: AppTextStyles.bodyDynamic(context)),
                        ),
                      ],
                    ),
                  )),
            ]),
            const SizedBox(height: 16),
          ] else ...[
            _sectionCard('Health Status', [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.riskLow, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No significant health risks detected for this patient.',
                      style: AppTextStyles.bodyDynamic(context),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
          ],

          // Detailed breakdown (LIME)
          if (_explanation != null) _buildDetailedBreakdown(),
          const SizedBox(height: 16),

          // Recommendations
          _sectionCard('Clinical Recommendations', [
            ...(_risk!['recommendations'] as List).map((rec) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(rec, style: AppTextStyles.bodyDynamic(context))),
                    ],
                  ),
                )),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailedBreakdown() {
    final explanations = _explanation!['explanation'] as List;

    return _sectionCard('Detailed Risk Breakdown', [
      Text(
        'Factors influencing this patient\'s risk assessment:',
        style: AppTextStyles.captionDynamic(context),
      ),
      const SizedBox(height: 12),
      ...explanations.map((e) {
        final isRisk = e['direction'] == 'increases_risk';
        final color =
            isRisk ? AppColors.riskHigh : AppColors.riskLow;
        final impact = (e['impact'] as num).toDouble();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isRisk ? 'ↁEIncreases Risk' : 'ↁEReduces Risk',
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e['feature'],
                        style: AppTextStyles.captionDynamic(context)),
                  ),
                  Text('${impact.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: impact / 50,
                  backgroundColor:
                      AppDynamicColors.surfaceVariant(context),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }),
    ]);
  }

  // ── Nutrition Plan Tab ───────────────────────────────────
  Widget _buildNutritionTab() {
    if (_recommendations == null) return _errorWidget();
    final targetCals =
        (_recommendations!['target_calories_per_day'] as double)
            .toStringAsFixed(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Target calories hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppColors.primary, size: 40),
                const SizedBox(height: 8),
                Text('$targetCals kcal/day',
                    style: AppTextStyles.heading1Dynamic(context)
                        .copyWith(color: AppColors.primary)),
                Text('Recommended Daily Caloric Intake',
                    style: AppTextStyles.captionDynamic(context)),
                const SizedBox(height: 12),

                // Show/hide calc logic
                GestureDetector(
                  onTap: () => setState(
                      () => _showCalcLogic = !_showCalcLogic),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showCalcLogic
                            ? 'Hide calculation'
                            : 'How is this calculated?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showCalcLogic
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),

                if (_showCalcLogic) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calculation Method',
                            style: AppTextStyles.bodyMediumDynamic(context)),
                        const SizedBox(height: 8),
                        Text(
                          '1. BMR (Base Metabolic Rate): ${_calculations!['bmr']} kcal\n'
                          '   Using Mifflin-St Jeor equation\n\n'
                          '2. TDEE (Total Daily Energy): ${_calculations!['tdee']} kcal\n'
                          '   BMR ÁEActivity Factor (${widget.patient['activity_level']})\n\n'
                          '3. Target = TDEE adjusted for goal\n'
                          '   Based on current BMI category',
                          style: AppTextStyles.captionDynamic(context)
                              .copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recommendations button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(
                  () => _showRecommendations = !_showRecommendations),
              icon: Icon(
                _showRecommendations
                    ? Icons.expand_less
                    : Icons.restaurant_menu,
                size: 18,
              ),
              label: Text(_showRecommendations
                  ? 'Hide Recommendations'
                  : 'View Dietary Recommendations'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_showRecommendations) ...[
            const SizedBox(height: 16),
            _buildListCard(
              'Meal Plan',
              Icons.restaurant_menu,
              _recommendations!['meal_plan'],
              AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildListCard(
              'Dietary Focus',
              Icons.fact_check_outlined,
              _recommendations!['dietary_focus'],
              AppColors.riskModerate,
            ),
            const SizedBox(height: 12),
            _buildListCard(
              'Lifestyle Tips',
              Icons.self_improvement,
              _recommendations!['lifestyle_tips'],
              AppColors.riskLow,
            ),
          ],
        ],
      ),
    );
  }

  // ── Analysis Tab ─────────────────────────────────────────
  Widget _buildAnalysisTab() {
    if (_compareData == null) return _errorWidget();

    final rf = _compareData!['random_forest'];
    final nn = _compareData!['neural_network'];
    final agree = _compareData!['models_agree'] as bool;
    final verdict = _compareData!['final_verdict'];
    final verdictColor =
        agree ? AppColors.riskLow : AppColors.riskModerate;

    // Get actual risk factors
    final factors = (_compareData!['top_risk_factors'] as List)
        .where((f) =>
            !f.toString().contains('No major') &&
            !f.toString().contains('acceptable range'))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Verdict card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: verdictColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: verdictColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(
                  agree
                      ? Icons.verified_outlined
                      : Icons.pending_outlined,
                  color: verdictColor,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(verdict,
                    style: TextStyle(
                      color: verdictColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                  agree
                      ? 'Confirmed by multiple analyses'
                      : 'Further review recommended',
                  style: AppTextStyles.captionDynamic(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two analysis results
          _sectionCard('Prediction Confidence', [
            _analysisBar('Primary Analysis',
                rf['risk_level'], rf['confidence']),
            const SizedBox(height: 12),
            _analysisBar('Secondary Analysis',
                nn['risk_level'], nn['confidence']),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: agree
                    ? AppColors.riskLowLight
                    : AppColors.riskModerateLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    agree ? Icons.check_circle : Icons.info_outline,
                    color: agree
                        ? AppColors.riskLow
                        : AppColors.riskModerate,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agree
                          ? 'Both analyses agree  Ehigh confidence result'
                          : 'Analyses differ  Emanual review recommended',
                      style: TextStyle(
                        color: agree
                            ? AppColors.riskLow
                            : AppColors.riskModerate,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Risk factors  Eonly real ones
          if (factors.isNotEmpty)
            _sectionCard('Key Risk Factors', [
              ...factors.map((factor) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.riskModerate, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(factor,
                              style: AppTextStyles.bodyDynamic(context)),
                        ),
                      ],
                    ),
                  )),
            ])
          else
            _sectionCard('Key Risk Factors', [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.riskLow, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No significant risk factors identified for this patient.',
                      style: AppTextStyles.bodyDynamic(context),
                    ),
                  ),
                ],
              ),
            ]),
          const SizedBox(height: 16),

          // How it works  Ecollapsible
          GestureDetector(
            onTap: () =>
                setState(() => _showHowItWorks = !_showHowItWorks),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDynamicColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDynamicColors.border(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('How does this analysis work?',
                        style: AppTextStyles.bodyMediumDynamic(context)
                            .copyWith(color: AppColors.primary)),
                  ),
                  Icon(
                    _showHowItWorks
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          if (_showHowItWorks) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDynamicColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDynamicColors.border(context)),
              ),
              child: Text(
                'This patient\'s data was analyzed using two independent methods trained on over 2,000 real patient records. '
                'When both methods agree, the result is considered highly reliable. '
                'When they differ, a manual review by the nutritionist is recommended before making clinical decisions.',
                style: AppTextStyles.bodyDynamic(context)
                    .copyWith(color: AppDynamicColors.textSecondary(context), height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helper Widgets ───────────────────────────────────────
  Widget _metricCard(String title, String value, String unit,
      String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDynamicColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDynamicColors.cardShadow(context),
        border: Border.all(color: AppDynamicColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          Text(unit, style: AppTextStyles.captionDynamic(context)),
          const SizedBox(height: 4),
          Text(title,
              style: AppTextStyles.bodyMediumDynamic(context)),
          Text(subtitle, style: AppTextStyles.captionDynamic(context)),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDynamicColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDynamicColors.cardShadow(context),
        border: Border.all(color: AppDynamicColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading4Dynamic(context)),
          const SizedBox(height: 4),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: AppTextStyles.captionDynamic(context)),
          Expanded(
              child: Text(value, style: AppTextStyles.bodyMediumDynamic(context))),
        ],
      ),
    );
  }

  Widget _probabilityBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodyDynamic(context)),
              Text('${value.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppDynamicColors.surfaceVariant(context),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisBar(
      String label, String risk, String confidence) {
    final color = _getRiskColor(risk);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDynamicColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.captionDynamic(context)),
                Text(risk,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(confidence,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
      String title, IconData icon, List items, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDynamicColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDynamicColors.cardShadow(context),
        border: Border.all(color: AppDynamicColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.heading4Dynamic(context)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item,
                          style: AppTextStyles.bodyDynamic(context)
                              .copyWith(height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.captionDynamic(context)),
      ],
    );
  }

  IconData _getRiskIcon(String risk) {
    switch (risk) {
      case 'Low': return Icons.check_circle_outline;
      case 'Moderate': return Icons.warning_amber_outlined;
      case 'High': return Icons.error_outline;
      case 'Critical': return Icons.dangerous_outlined;
      default: return Icons.help_outline;
    }
  }

  Widget _errorWidget() {
    return const Center(
      child: Text('Failed to load data',
          style: TextStyle(color: Colors.red)),
    );
  }
}

