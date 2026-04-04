import 'package:flutter/material.dart';
import 'package:reliefnet/pages/dashboard_page.dart';
import 'package:reliefnet/pages/home_page.dart';
import 'package:reliefnet/pages/report_page.dart';
import 'package:reliefnet/pages/volunteer_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Homepage(),
      // maybe of help later
      routes: {
        '/report': (context) => ReportPage(),
        '/dashboard': (context) => DashboardPage(),
        '/volunteer': (context) => VolunteerPage(),
      },
    );
  }
}
