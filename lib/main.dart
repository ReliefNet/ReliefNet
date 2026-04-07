import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:reliefnet/pages/dashboard_page.dart';
import 'package:reliefnet/pages/home_page.dart';
import 'package:reliefnet/pages/report_page.dart';
import 'package:reliefnet/pages/volunteer_page.dart';
import 'package:reliefnet/themes/theme_dark.dart';
import 'package:reliefnet/themes/theme_light.dart';
import 'package:reliefnet/themes/theme_provider.dart';

void main() async {
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

      theme: lightmode,
      darkTheme: darkmode,
      themeMode:
          themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      home: Homepage(),
      routes: {
        '/report': (context) => const ReportPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/volunteer': (context) => const VolunteerPage(),
      },
    );
  }
}