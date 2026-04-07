import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/pages/dashboard_page.dart';
import 'package:reliefnet/pages/profile_page.dart';
import 'package:reliefnet/pages/report_page.dart';
import 'package:reliefnet/pages/settings_page.dart';
import 'package:reliefnet/pages/volunteer_page.dart';
import 'package:reliefnet/components/appBar.dart';

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
  final List<String> _pageTitles = [
    'Relief Net',
    'Report Issue',
    'Dashboard',
    'Volunteer',
    'Profile',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[selectedindex],
      appBar: AppBarComponent(appBarText: _pageTitles[selectedindex]),
      drawer: Drawer(
        width: 220,
        child: Column(
          children: [
            // logo
            DrawerHeader(child: Image.asset("assets/images/logo.png")),
            // home
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text("Home"),
              onTap: () {
                setState(() {
                  selectedindex = 0;
                });
                Navigator.pop(context);
              },
            ),
            // report screen
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text("Report"),
              onTap: () {
                setState(() {
                  selectedindex = 1;
                });
                Navigator.pop(context);
              },
            ),
            // dashboard
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text("Dashboard"),
              onTap: () {
                setState(() {
                  selectedindex = 2;
                });
                Navigator.pop(context);
              },
            ),
            // volunteer
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text("Volunteer"),
              onTap: () {
                setState(() {
                  selectedindex = 3;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // profile
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("Profile"),
              onTap: () {
                setState(() {
                  selectedindex = 4;
                });
                Navigator.pop(context);
              },
            ),
            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text("Settings"),
              onTap: () {
                setState(() {
                  selectedindex = 5;
                });
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            // Logout with confirmation
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog
                          await FirebaseAuth.instance.signOut();
                        },
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
