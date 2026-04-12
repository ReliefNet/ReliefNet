import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reliefnet/themes/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  // ── Notification prefs (Firestore) ────────────────────────────────────────
  bool _notifyNewReports = true;
  bool _notifyTaskAssigned = true;
  bool _notifyTaskCompleted = true;
  bool _notifyUrgentOnly = false;

  // ── Language ──────────────────────────────────────────────────────────────
  String _selectedLanguage = 'English';
  final List<String> _languages = [
    'English',
    'Hindi',
    'Bengali',
    'Tamil',
    'Telugu',
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _savingNotifs = false;
  String _appVersion = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadNotifPrefs(),
      _loadLanguagePref(),
      _loadAppVersion(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadNotifPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
        if (prefs != null && mounted) {
          setState(() {
            _notifyNewReports = prefs['newReports'] ?? true;
            _notifyTaskAssigned = prefs['taskAssigned'] ?? true;
            _notifyTaskCompleted = prefs['taskCompleted'] ?? true;
            _notifyUrgentOnly = prefs['urgentOnly'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('loadNotifPrefs error: $e');
    }
  }

  Future<void> _loadLanguagePref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedLanguage = prefs.getString('language') ?? 'English';
      });
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  // ── Savers ────────────────────────────────────────────────────────────────

  Future<void> _saveNotifPref(String key, bool value) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  
  // Remove the _savingNotifs setState here to prevent the UI jump
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPrefs': {
        'newReports': _notifyNewReports,
        'taskAssigned': _notifyTaskAssigned,
        'taskCompleted': _notifyTaskCompleted,
        'urgentOnly': _notifyUrgentOnly,
      },
    }, SetOptions(merge: true));
  } catch (e) {
    _snack('Failed to save: $e');
  }
}

  Future<void> _saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    if (mounted) setState(() => _selectedLanguage = lang);
    _snack('Language set to $lang — restart to apply');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openFeedbackEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@reliefnet.app',
      query:
          'subject=ReliefNet%20Feedback&body=App%20version%3A%20$_appVersion',
    );

    try {
      // try launching directly without canLaunchUrl check
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('No email app found. Contact support@reliefnet.app');
    }
  }

  Future<void> _clearCache() async {
    final confirm = await _confirmDialog(
      title: 'Clear Cache',
      message:
          'This will clear locally cached data. Your account and reports are safe.',
      action: 'Clear',
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    // preserve theme + language
    final theme = prefs.getString('theme');
    final language = prefs.getString('language');
    await prefs.clear();
    if (theme != null) await prefs.setString('theme', theme);
    if (language != null) await prefs.setString('language', language);
    _snack('Cache cleared');
  }

  Future<void> _showPrivacyPolicy() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrivacyPolicySheet(),
    );
  }

  void _showProjectDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProjectDetailsSheet(),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await _confirmDialog(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all associated data. This cannot be undone.',
      action: 'Delete',
      isDanger: true,
    );
    if (confirm != true || !mounted) return;
    _snack('Contact support@reliefnet.app to complete account deletion');
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String action,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: isDanger
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Replace with your actual ThemeProvider consumer ───────────────────
    // final themeProvider = context.watch<ThemeProvider>();
    // final isDark = themeProvider.isDark;
    // final onThemeToggle = themeProvider.toggle;
    //
    // For now wired to a placeholder — swap these two lines:
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final onThemeToggle = themeProvider.toggleTheme;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Appearance ─────────────────────────────────────────────────
        _SectionLabel(label: 'Appearance'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _SwitchTile(
              icon: isDark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              iconColor: const Color(0xFF6366F1),
              label: 'Dark Mode',
              subtitle: isDark ? 'Currently dark' : 'Currently light',
              value: isDark,
              onChanged: (_) => onThemeToggle(),
            ),
          ],
        ),
    
        const SizedBox(height: 24),
    
        // ── Notifications ───────────────────────────────────────────────
        _SectionLabel(label: 'Notifications'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _SwitchTile(
              icon: Icons.fiber_new_outlined,
              iconColor: const Color(0xFF22C55E),
              label: 'New Reports',
              subtitle: 'Alert when a new report\nis filed',
              value: _notifyNewReports,
              loading: _savingNotifs,
              onChanged: (v) {
                setState(() => _notifyNewReports = v);
                _saveNotifPref('newReports', v);
              },
            ),
            // _Divider(),
            _SwitchTile(
              icon: Icons.handshake_outlined,
              iconColor: const Color(0xFFF59E0B),
              label: 'Task Assigned',
              subtitle: 'Alert when a task is\nassigned to you',
              value: _notifyTaskAssigned,
              loading: _savingNotifs,
              onChanged: (v) {
                setState(() => _notifyTaskAssigned = v);
                _saveNotifPref('taskAssigned', v);
              },
            ),
            // _Divider(),
            _SwitchTile(
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF22C55E),
              label: 'Task Completed',
              subtitle: 'Alert when a task you\nfiled is resolved',
              value: _notifyTaskCompleted,
              loading: _savingNotifs,
              onChanged: (v) {
                setState(() => _notifyTaskCompleted = v);
                _saveNotifPref('taskCompleted', v);
              },
            ),
            // _Divider(),
            _SwitchTile(
              icon: Icons.priority_high_rounded,
              iconColor: const Color(0xFFEF4444),
              label: 'Urgent Only',
              subtitle: 'Only notify for High\nurgency reports',
              value: _notifyUrgentOnly,
              loading: _savingNotifs,
              onChanged: (v) {
                setState(() => _notifyUrgentOnly = v);
                _saveNotifPref('urgentOnly', v);
              },
            ),
          ],
        ),
    
        const SizedBox(height: 24),
    
        // ── Language / Region ───────────────────────────────────────────
        _SectionLabel(label: 'Language & Region'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _TapTile(
              icon: Icons.language_outlined,
              iconColor: const Color(0xFF06B6D4),
              label: 'Language',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedLanguage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ],
              ),
              onTap: () => _showLanguagePicker(),
            ),
          ],
        ),
    
        const SizedBox(height: 24),
    
        // ── Privacy & Data ──────────────────────────────────────────────
        _SectionLabel(label: 'Privacy & Data'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _TapTile(
              icon: Icons.policy_outlined,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Privacy Policy',
              onTap: _showPrivacyPolicy,
            ),
            // _Divider(),
            _TapTile(
              icon: Icons.cleaning_services_outlined,
              iconColor: const Color(0xFF6366F1),
              label: 'Clear Cache',
              subtitle: 'Free up local storage',
              onTap: _clearCache,
            ),
            // _Divider(),
            _TapTile(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.red,
              label: 'Delete Account',
              subtitle: 'Permanently remove your data',
              labelColor: Colors.red,
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
    
        const SizedBox(height: 24),
    
        // ── Help & Feedback ─────────────────────────────────────────────
        _SectionLabel(label: 'Help & Feedback'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _TapTile(
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: 'Send Feedback',
              subtitle: 'support@reliefnet.app',
              onTap: _openFeedbackEmail,
            ),
          ],
        ),
    
        const SizedBox(height: 24),
    
        // ── About ───────────────────────────────────────────────────────
        _SectionLabel(label: 'About'),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _TapTile(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF06B6D4),
              label: 'App Version',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$_appVersion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              onTap: null,
            ),
            // _Divider(),
            _TapTile(
              icon: Icons.favorite_outline_rounded,
              iconColor: Colors.red,
              label: 'Built for Google Solution Challenge',
              onTap: () => _showProjectDetails(context),
            ),
          ],
        ),
    
        const SizedBox(height: 32),
    
        // ── Footer ──────────────────────────────────────────────────────
        Center(
          child: Text(
            'ReliefNet v$_appVersion · Made with ❤️ for communities',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── Language picker ───────────────────────────────────────────────────────

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Language',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._languages.map(
                (lang) => ListTile(
                  title: Text(lang, style: theme.textTheme.bodyMedium),
                  trailing: _selectedLanguage == lang
                      ? Icon(
                          Icons.check_rounded,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveLanguage(lang);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyPolicySheet extends StatelessWidget {
  const _PrivacyPolicySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Privacy Policy',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: const [
                  _PolicySection(
                    title: 'Data We Collect',
                    body:
                        'ReliefNet collects your name, username, profile picture, and volunteer ID for account management. '
                        'Location data is collected only when you submit a report, and is stored with the report in Firestore. '
                        'We do not sell your data to third parties.',
                  ),
                  _PolicySection(
                    title: 'How We Use Your Data',
                    body:
                        'Your data is used solely to power ReliefNet features: matching volunteers to reports, '
                        'displaying distances, and maintaining your activity history. '
                        'Notification preferences are synced across devices via Firestore.',
                  ),
                  _PolicySection(
                    title: 'Data Retention',
                    body:
                        'Your account data is retained as long as your account is active. '
                        'You may request deletion at any time via Settings → Delete Account.',
                  ),
                  _PolicySection(
                    title: 'Third-Party Services',
                    body:
                        'ReliefNet uses Firebase (Google) for authentication, database, and storage. '
                        'Google Maps is used for location display. Their respective privacy policies apply.',
                  ),
                  _PolicySection(
                    title: 'Contact',
                    body:
                        'For privacy concerns, contact us at support@reliefnet.app.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Project Details Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectDetailsSheet extends StatelessWidget {
  const _ProjectDetailsSheet();

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "ReliefNet Project",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "ReliefNet is a mobile app that connects people in need with nearby volunteers, enabling quick and reliable help during emergencies. It streamlines how requests are made and how volunteers respond, making relief efforts faster and more organized.",
            ),

            const SizedBox(height: 24),
            Text(
              "TEAM MEMBERS",
              style: textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            // Replace with your actual names
            _buildInfoRow(Icons.person_outline, "Ramandeep Singh"),
            _buildInfoRow(Icons.person_outline, "Japneet Singh"),
            _buildInfoRow(Icons.person_outline, "Member Name 3"),
            _buildInfoRow(Icons.person_outline, "Member Name 4"),

            const SizedBox(height: 24),
            Text(
              "PROJECT LINKS",
              style: textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildLinkTile(
              Icons.code,
              "GitHub Repository",
              "https://github.com/ramanexc/reliefnet",
              theme,
            ),
            _buildLinkTile(
              Icons.share,
              "LinkedIn Post",
              "https://linkedin.com/posts/your-post",
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    IconData icon,
    String label,
    String url,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _launchURL(url),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Use StatefulBuilder to keep the "flicker" contained to just this tile
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch.adaptive(
                      value: value,
                      onChanged: (newValue) {
                        // 1. Update the UI immediately and locally
                        setLocalState(() {}); 
                        // 2. Trigger the Firebase save logic
                        onChanged(newValue);
                      },
                    ),
            ],
          ),
        );
      }
    );
  }
}
class _TapTile extends StatelessWidget {
  const _TapTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color,
                )
              : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
