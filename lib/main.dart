import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:smart_civic_assistant/models/app_user.dart';
import 'package:smart_civic_assistant/services/auth_service.dart';
import 'package:smart_civic_assistant/services/database_service.dart';
import 'package:smart_civic_assistant/screens/login_screen.dart';
import 'package:smart_civic_assistant/screens/user/dashboard_screen.dart';
import 'package:smart_civic_assistant/screens/admin/admin_dashboard_screen.dart';
import 'package:smart_civic_assistant/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase not configured. Run flutterfire configure or add options.');
  }
  await DatabaseService.init();
  runApp(const SmartCivicApp());
}

class SmartCivicApp extends StatelessWidget {
  const SmartCivicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        StreamProvider<AppUser?>(
          create: (context) => context.read<AuthService>().userStream,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Smart Civic Assistant',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  width: 430,
                  height: 932,
                  constraints: const BoxConstraints(maxWidth: 430),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(37),
                    child: Stack(
                      children: [
                        child!,
                        // Simulated Notch
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 160,
                            height: 35,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle)),
                                Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(2))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasVisitedBefore = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVisited = prefs.getBool('has_visited_before') ?? false;
    
    if (mounted) {
      setState(() {
        _hasVisitedBefore = hasVisited;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = Provider.of<AppUser?>(context);

    if (appUser == null) {
      return LoginScreen(isFirstTimeUser: !_hasVisitedBefore);
    } else {
      return Provider<AppUser>.value(
        value: appUser,
        child: appUser.isAdmin 
            ? AdminDashboardScreen()
            : DashboardScreen(),
      );
    }
  }
}
