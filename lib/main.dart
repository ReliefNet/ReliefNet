import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:reliefnet/main-pages/apply_volunteer_page.dart';
import 'package:reliefnet/main-pages/dashboard_page.dart';
import 'package:reliefnet/main-pages/home_page.dart';
import 'package:reliefnet/main-pages/report_page.dart';
import 'package:reliefnet/main-pages/volunteer_page.dart';
import 'package:reliefnet/login-signup/login_page.dart';
import 'package:reliefnet/themes/theme_light.dart';
import 'package:reliefnet/themes/theme_dark.dart';
import 'package:reliefnet/themes/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      /// THEMES
      theme: lightmode,
      darkTheme: darkmode,
      themeMode:
          themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      /// ROUTES
      routes: {
        '/report': (context) => const ReportPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/volunteer': (context) => const VolunteerPage(),
        '/apply_volunteer': (context) => const ApplyVolunteerPage(),
      },

      /// AUTH HANDLER
      home: const AuthWrapper(),
    );
  }
}

/// 🔥 Separate widget (VERY IMPORTANT)
/// Prevents full app rebuild issues
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        /// Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    "Checking authentication...",
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        /// Logged in
        if (snapshot.hasData) {
          return const Homepage();
        }

        /// Not logged in
        return const LoginPage();
      },
    );
  }
}
