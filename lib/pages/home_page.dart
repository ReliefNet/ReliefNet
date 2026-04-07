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

  void _navigate(int index) {
    setState(() => selectedindex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBarComponent(
        appBarText: _pageTitles[selectedindex],
      ),

      body: _pages[selectedindex],

      drawer: Drawer(
        width: 240,
        child: Column(
          children: [
            /// 🔹 Header
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/logo.png", height: 80),
                  const SizedBox(height: 10),
                  Text(
                    "ReliefNet",
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            /// 🔹 Main Items
            _buildTile(Icons.home_outlined, "Home", 0, textTheme),
            _buildTile(Icons.report_outlined, "Report", 1, textTheme),
            _buildTile(Icons.dashboard_outlined, "Dashboard", 2, textTheme),
            _buildTile(Icons.help_outline, "Volunteer", 3, textTheme),


            /// 🔹 Secondary Items
            _buildTile(Icons.person_outline, "Profile", 4, textTheme),
            _buildTile(Icons.settings_outlined, "Settings", 5, textTheme),

            const Spacer(),

            /// 🔹 Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                "Logout",
                style: textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              onTap: () => _showLogoutDialog(context, textTheme),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 🔥 Reusable Tile (cleaner code)
  Widget _buildTile(
      IconData icon, String title, int index, TextTheme textTheme) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: textTheme.bodyMedium),
      selected: selectedindex == index,
      onTap: () => _navigate(index),
    );
  }

  /// 🔥 Logout Dialog (clean + themed)
  void _showLogoutDialog(BuildContext context, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout", style: textTheme.bodyLarge),
        content: Text(
          "Are you sure you want to logout?",
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: textTheme.bodySmall),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
            child: Text(
              "Logout",
              style: textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}