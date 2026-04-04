import 'package:flutter/material.dart';
import 'package:reliefnet/pages/dashboard_page.dart';
import 'package:reliefnet/pages/profile_page.dart';
import 'package:reliefnet/pages/report_page.dart';
import 'package:reliefnet/pages/settings_page.dart';
import 'package:reliefnet/pages/volunteer_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int selectedindex = 0;
  final List<Widget> _pages = const [
    Center(child: Text("Home")),
    ReportPage(),
    DashboardPage(),
    VolunteerPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[selectedindex],
      appBar: AppBar(
        title: Text("Relief Net", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.purple,
      ),
      drawer: Drawer(
        width: 220,
        child: Column(
          children: [
            // logo
            DrawerHeader(child: Image.asset("assets/images/logo.png")),
            // home
            ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text("Home"),
              onTap: () {
                setState(() {
                  selectedindex = 0;
                });
                Navigator.pop(context);
              },
            ),
            // report screen
            ListTile(
              leading: Icon(Icons.report_outlined),
              title: Text("Report"),
              onTap: () {
                setState(() {
                  selectedindex = 1;
                });
                Navigator.pop(context);
              },
            ),
            // dashboard
            ListTile(
              leading: Icon(Icons.dashboard_outlined),
              title: Text("Dashboard"),
              onTap: () {
                setState(() {
                  selectedindex = 2;
                });
                Navigator.pop(context);
              },
            ),
            // volunteer
            ListTile(
              leading: Icon(Icons.help_outline),
              title: Text("Volunteer"),
              onTap: () {
                setState(() {
                  selectedindex = 3;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            // profile
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text("Profile"),
              onTap: () {
                setState(() {
                  selectedindex = 4;
                });
                Navigator.pop(context);
              },
            ),
            // Settings
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text("Settings"),
              onTap: () {
                setState(() {
                  selectedindex = 5;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
