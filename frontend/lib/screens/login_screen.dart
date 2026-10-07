import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/background_widget.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showSavedAccounts = false;


List<Map<String, String>> _savedAccounts = [];

@override
void initState() {
  super.initState();
  _loadSavedAccounts();
}

Future<void> _loadSavedAccounts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('saved_accounts') ?? [];
    setState(() {
      _savedAccounts = accounts.map((a) {
        final parts = a.split('|');
        if (parts.length >= 2) {
          return {'name': parts[0], 'email': parts[1]};
        }
        return {'name': '', 'email': ''};
      }).where((a) => a['email']!.isNotEmpty).toList();
    });
  } catch (e) {
    setState(() => _savedAccounts = []);
  }
}

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await Provider.of<AuthProvider>(context, listen: false)
        .login(_emailController.text.trim(), _passwordController.text.trim());

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email or password'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
  width: 90,
  height: 90,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    boxShadow: AppColors.elevatedShadow,
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.asset(
      'assets/icon/app_icon.png',
      fit: BoxFit.cover,
    ),
  ),
),
                  const SizedBox(height: 24),
                  Text(
                    'Smart Nutrition',
                    style: AppTextStyles.heading1Dynamic(context),
                  ),
                  Text(
                    'Assistant',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppDynamicColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: AppDynamicColors.textSecondary(context)),
                      prefixIcon: Icon(Icons.email, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: AppDynamicColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: AppDynamicColors.textSecondary(context)),
                      prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppDynamicColors.textSecondary(context),
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

// ── Saved accounts quick login ──────────────────────────
if (_savedAccounts.isNotEmpty) ...[
  const SizedBox(height: 16),
  GestureDetector(
    onTap: () => setState(() => _showSavedAccounts = !_showSavedAccounts),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            _showSavedAccounts
                ? 'Hide saved accounts'
                : 'Saved accounts (${_savedAccounts.length})',
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(width: 4),
          Icon(
            _showSavedAccounts ? Icons.expand_less : Icons.expand_more,
            color: AppColors.primary, size: 16),
        ],
      ),
    ),
  ),
  if (_showSavedAccounts) ...[
    const SizedBox(height: 8),
    ..._savedAccounts.map((account) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _emailController.text = account['email']!;
          setState(() => _showSavedAccounts = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email filled for ${account['name']}  Eenter your password')),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppDynamicColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDynamicColors.border(context)),
            boxShadow: AppDynamicColors.cardShadow(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  account['name']![0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account['name']!, style: AppTextStyles.bodyMediumDynamic(context)),
                    Text(account['email']!, style: AppTextStyles.captionDynamic(context)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    )),
  ],
],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppDynamicColors.textSecondary(context)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

