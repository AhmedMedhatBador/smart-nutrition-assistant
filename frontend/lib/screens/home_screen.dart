import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_widget.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'categories_screen.dart';
import 'training_plots_screen.dart';
import 'add_patient_screen.dart';
import '../utils/string_extensions.dart';
import 'update_patient_screen.dart';
import '../utils/export_helper.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _patients = [];
  List<dynamic> _filteredPatients = [];
  List<Map<String, String>> _savedAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadSavedAccounts();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────
  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _patients
          .where((p) => p['name'].toString().toLowerCase().contains(query))
          .toList();
    });
  }

  // ── Load patients ────────────────────────────────────────
  Future<void> _loadPatients() async {
    try {
      setState(() => _isLoading = true);
      final response = await _api.getPatients();
      setState(() {
        _patients = response.data;
        _filteredPatients = response.data;
        _isLoading = false;
      });
    } catch (e) {
  if (!mounted) return;
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not load patients. Check your connection.')),
  );
}
  }

 // ── Saved accounts ───────────────────────────────────────
Future<void> _loadSavedAccounts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('saved_accounts') ?? [];
    setState(() {
      _savedAccounts = accounts.map((a) {
        final parts = a.split('|');
        if (parts.length >= 2) {
          return {'name': parts[0], 'email': parts[1],
                  'password': parts.length > 2 ? parts[2] : ''};
        }
        return {'name': '', 'email': '', 'password': ''};
      }).where((a) => a['email']!.isNotEmpty).toList();
    });
  } catch (e) {
    setState(() => _savedAccounts = []);
  }
}

Future<void> _saveCurrentAccount() async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  if (auth.userEmail.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final accounts = prefs.getStringList('saved_accounts') ?? [];
  final entry = '${auth.userName}|${auth.userEmail}';

  // Check if already saved (ignore password part)
  final alreadyExists = accounts.any((a) {
    final parts = a.split('|');
    return parts.length >= 2 && parts[1] == auth.userEmail;
  });

  if (!alreadyExists) {
    accounts.add(entry);
    await prefs.setStringList('saved_accounts', accounts);
    await _loadSavedAccounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account saved for quick access!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account already saved')),
      );
    }
  }
}

Future<void> _removeSavedAccount(int index) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('saved_accounts') ?? [];
    if (index < accounts.length) {
      accounts.removeAt(index);
      await prefs.setStringList('saved_accounts', accounts);
      await _loadSavedAccounts();
    }
  } catch (e) {
    // ignore
  }
}

void _showSavedAccountsDialog() {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Accounts'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_savedAccounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text('No saved accounts yet',
                          style: AppTextStyles.bodyDynamic(context)
                              .copyWith(color: AppDynamicColors.textSecondary(context))),
                      const SizedBox(height: 4),
                      Text('Save your current account below',
                          style: AppTextStyles.captionDynamic(context)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _savedAccounts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppDynamicColors.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppDynamicColors.border(context)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            account['name']!.isNotEmpty
                                ? account['name']![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(account['name']!,
                            style: AppTextStyles.bodyMediumDynamic(context)),
                        subtitle: Text(account['email']!,
                            style: AppTextStyles.captionDynamic(context)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () async {
                            await _removeSavedAccount(index);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _saveCurrentAccount();
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save Current Account'),
          ),
        ],
      ),
    ),
  );
}

  // ── Delete patient ───────────────────────────────────────
  Future<void> _deletePatient(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient'),
        content: const Text('Are you sure you want to delete this patient?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deletePatient(id);
        _loadPatients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete patient')),
          );
        }
      }
    }
  }

  // ── Export CSV ───────────────────────────────────────────
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

  // ── BMI helpers ──────────────────────────────────────────
  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.bmiUnderweight;
    if (bmi < 25) return AppColors.bmiNormal;
    if (bmi < 30) return AppColors.bmiOverweight;
    return AppColors.bmiObese;
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
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

  double _calculateBmi(double weight, double height) {
    return weight / ((height / 100) * (height / 100));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/icon/app_icon.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NutriAssist',
                              style: AppTextStyles.heading4Dynamic(context).copyWith(
                                  color: AppColors.primary)),
                          Text('Welcome, ${auth.userName}',
                              style: AppTextStyles.captionDynamic(context)),
                        ],
                      ),
                    ),
                    // Action buttons
                    IconButton(
                      icon: Icon(Icons.people_outline,
                          color: AppDynamicColors.textSecondary(context)),
                      tooltip: 'Saved Accounts',
                      onPressed: _showSavedAccountsDialog,
                    ),
                    IconButton(
                      icon: Icon(Icons.category_outlined,
                          color: AppDynamicColors.textSecondary(context)),
                      tooltip: 'Categories',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CategoriesScreen()),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.download_outlined,
                          color: AppDynamicColors.textSecondary(context)),
                      tooltip: 'Export CSV',
                      onPressed: _exportCsv,
                    ),
                    IconButton(
  icon: Icon(
    MyApp.of(context)?.isDark == true ? Icons.light_mode : Icons.dark_mode,
    color: AppDynamicColors.textSecondary(context),
  ),
  onPressed: () => MyApp.of(context)?.toggleTheme(),
),
                    IconButton(
                      icon: Icon(Icons.logout,
                          color: AppDynamicColors.textSecondary(context)),
                      tooltip: 'Logout',
                      onPressed: () async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Logout',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm == true && mounted) {
    await auth.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }
},

                    ),
                  ],
                ),
              ),

              // ── Search bar ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyDynamic(context),
                  decoration: InputDecoration(
                    hintText: 'Search patients...',
                    prefixIcon: Icon(Icons.search,
                        color: AppDynamicColors.textSecondary(context)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppDynamicColors.textSecondary(context)),
                            onPressed: () {
                              _searchController.clear();
                              _filterPatients();
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // ── Stats summary ───────────────────────────
              if (_patients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      _statChip('${_patients.length}', 'Total'),
                      const SizedBox(width: 8),
                      _statChip(
                        '${_patients.where((p) {
                          final bmi = _calculateBmi(
                              p['weight'].toDouble(), p['height'].toDouble());
                          return bmi >= 25;
                        }).length}',
                        'Need Attention',
                        color: AppColors.riskModerate,
                      ),
                    ],
                  ),
                ),

              // ── Patient list ────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _filteredPatients.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadPatients,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 8, 20, 100),
                              itemCount: _filteredPatients.length,
                              itemBuilder: (context, index) =>
                                  _buildPatientCard(
                                      _filteredPatients[index]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),

      // ── FAB ─────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPatientScreen()),
        ).then((_) => _loadPatients()),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Patient card ─────────────────────────────────────────
  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final bmi = _calculateBmi(
      patient['weight'].toDouble(),
      patient['height'].toDouble(),
    );
    final bmiColor = _getBmiColor(bmi);
    final bmiCategory = _getBmiCategory(bmi);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppDynamicColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDynamicColors.cardShadow(context),
        border: Border.all(color: AppDynamicColors.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patient: patient),
          ),
        ).then((_) => _loadPatients()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bmiColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    patient['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: bmiColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient['name'],
                        style: AppTextStyles.bodyMediumDynamic(context).copyWith(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      'Age ${patient['age']} • ${patient['gender'].toString().capitalize()} • ${patient['activity_level'].toString().replaceAll('_', ' ').capitalize()}',
                      style: AppTextStyles.captionDynamic(context),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bmiColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'BMI ${bmi.toStringAsFixed(1)} · $bmiCategory',
                            style: TextStyle(
                              color: bmiColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.edit_outlined,
          color: AppColors.primary, size: 20),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UpdatePatientScreen(patient: patient),
        ),
      ).then((_) => _loadPatients()),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
    const SizedBox(height: 8),
    IconButton(
      icon: const Icon(Icons.delete_outline,
          color: Colors.red, size: 20),
      onPressed: () => _deletePatient(patient['id']),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
    const SizedBox(height: 8),
    const Icon(Icons.chevron_right,
        color: AppColors.textHint, size: 20),
  ],
),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────
  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No patients found',
                style: AppTextStyles.heading4Dynamic(context)
                    .copyWith(color: AppDynamicColors.textSecondary(context))),
            Text('Try a different name',
                style: AppTextStyles.captionDynamic(context)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.people_outline,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No patients yet',
              style: AppTextStyles.heading4Dynamic(context)
                  .copyWith(color: AppDynamicColors.textSecondary(context))),
          const SizedBox(height: 4),
          Text('Tap "Add Patient" to get started',
              style: AppTextStyles.captionDynamic(context)),
        ],
      ),
    );
  }

  // ── Stat chip ────────────────────────────────────────────
  Widget _statChip(String value, String label,
      {Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}


