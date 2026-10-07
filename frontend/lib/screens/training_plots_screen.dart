import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_widget.dart';

class TrainingPlotsScreen extends StatefulWidget {
  const TrainingPlotsScreen({super.key});

  @override
  State<TrainingPlotsScreen> createState() => _TrainingPlotsScreenState();
}

class _TrainingPlotsScreenState extends State<TrainingPlotsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Map<String, dynamic>? _history;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await _api.getTrainingHistory();
      setState(() {
        _history = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<FlSpot> _toSpots(List data) {
    return data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble()))
        .toList();
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
                    Text('Model Training Results',
                        style: AppTextStyles.heading3Dynamic(context)),
                  ],
                ),
              ),

              // ── Tab bar ──────────────────────────────────
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
                    tabs: const [
                      Tab(text: 'Accuracy'),
                      Tab(text: 'Loss'),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _history == null
                        ? const Center(
                            child: Text('Failed to load training data'))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAccuracyTab(),
                              _buildLossTab(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccuracyTab() {
    final accuracy = _history!['accuracy'] as List;
    final valAccuracy = _history!['val_accuracy'] as List;
    final finalAcc = (accuracy.last as num) * 100;
    final finalValAcc = (valAccuracy.last as num) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _statCard('Training Accuracy',
                      '${finalAcc.toStringAsFixed(1)}%',
                      AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard('Validation Accuracy',
                      '${finalValAcc.toStringAsFixed(1)}%',
                      AppColors.riskLow)),
            ],
          ),
          const SizedBox(height: 16),
          _buildChart(
            title: 'Accuracy Over Training Epochs',
            spots1: _toSpots(accuracy),
            spots2: _toSpots(valAccuracy),
            label1: 'Training',
            label2: 'Validation',
            color1: AppColors.primary,
            color2: AppColors.riskLow,
            minY: 0,
            maxY: 1,
            isAccuracy: true,
          ),
          const SizedBox(height: 16),
          _infoCard(
            'Both training and validation accuracy converge at ~98%, '
            'indicating the model learned effectively without overfitting to the training data.',
          ),
        ],
      ),
    );
  }

  Widget _buildLossTab() {
    final loss = _history!['loss'] as List;
    final valLoss = _history!['val_loss'] as List;
    final finalLoss = (loss.last as num).toDouble();
    final finalValLoss = (valLoss.last as num).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _statCard('Training Loss',
                      finalLoss.toStringAsFixed(3),
                      AppColors.riskModerate)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard('Validation Loss',
                      finalValLoss.toStringAsFixed(3),
                      AppColors.riskHigh)),
            ],
          ),
          const SizedBox(height: 16),
          _buildChart(
            title: 'Loss Over Training Epochs',
            spots1: _toSpots(loss),
            spots2: _toSpots(valLoss),
            label1: 'Training',
            label2: 'Validation',
            color1: AppColors.riskModerate,
            color2: AppColors.riskHigh,
            minY: 0,
            maxY: 1.5,
            isAccuracy: false,
          ),
          const SizedBox(height: 16),
          _infoCard(
            'Loss decreased steadily from 1.38 to 0.13 across both training '
            'and validation sets, confirming stable and consistent learning.',
          ),
        ],
      ),
    );
  }

  Widget _buildChart({
    required String title,
    required List<FlSpot> spots1,
    required List<FlSpot> spots2,
    required String label1,
    required String label2,
    required Color color1,
    required Color color2,
    required double minY,
    required double maxY,
    required bool isAccuracy,
  }) {
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
          Text(title, style: AppTextStyles.heading4Dynamic(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendItem(label1, color1),
              const SizedBox(width: 16),
              _legendItem(label2, color2),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        isAccuracy
                            ? '${(value * 100).toInt()}%'
                            : value.toStringAsFixed(1),
                        style: AppTextStyles.captionDynamic(context),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        'E${value.toInt() + 1}',
                        style: AppTextStyles.captionDynamic(context),
                      ),
                      interval: 10,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppDynamicColors.border(context)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots1,
                    isCurved: true,
                    color: color1,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color1.withOpacity(0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: spots2,
                    isCurved: true,
                    color: color2,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color2.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.captionDynamic(context)),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.captionDynamic(context),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _infoCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(content,
                style: AppTextStyles.bodyDynamic(context)
                    .copyWith(color: AppColors.primary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

