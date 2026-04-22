import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shown when a non-volunteer taps a volunteer-only stat.
/// Lets them enter a Volunteer ID to apply.
class ApplyVolunteerPage extends StatefulWidget {
  const ApplyVolunteerPage({super.key});

  @override
  State<ApplyVolunteerPage> createState() => _ApplyVolunteerPageState();
}

class _ApplyVolunteerPageState extends State<ApplyVolunteerPage> {
  final _idController = TextEditingController();
  bool _isSaving = false;
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final id = _idController.text.trim();

    if (id.isEmpty) {
      _snack('Please enter a Volunteer ID.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('Not signed in.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 🔹 Fetch application
      final doc = await FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(uid)
          .get();

      if (!doc.exists) {
        _snack('No volunteer application found');
        setState(() => _isSaving = false);
        return;
      }

      final data = doc.data()!;

      final approved = data['status'] == 'approved';
      final correctId = data['volunteerId'] == id;

      if (!approved) {
        _snack('Your application is not approved yet');
        setState(() => _isSaving = false);
        return;
      }

      if (!correctId) {
        _snack('Invalid Volunteer ID');
        setState(() => _isSaving = false);
        return;
      }

      // ✅ Only now allow access
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'volunteerId': id,
        'isVolunteer': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _snack('You\'re now registered as a volunteer! 🎉');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Become a Volunteer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration / header
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Volunteer Access Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This section is only available to registered volunteers. '
              'If you have a Volunteer ID, enter it below to unlock volunteer features.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),

            const SizedBox(height: 32),

            // What volunteers can do
            _BenefitRow(
              icon: Icons.handshake_outlined,
              color: const Color(0xFF6366F1),
              title: 'Accept Tasks',
              subtitle: 'Pick up community requests from the feed.',
            ),
            const SizedBox(height: 14),
            _BenefitRow(
              icon: Icons.check_circle_outline,
              color: const Color(0xFF22C55E),
              title: 'Complete Tasks',
              subtitle: 'Submit proof of completion and track your impact.',
            ),
            const SizedBox(height: 14),
            _BenefitRow(
              icon: Icons.trending_up_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Track Your Progress',
              subtitle: 'See acceptance rate, completions, and more.',
            ),

            const SizedBox(height: 36),

            Text(
              'Enter Volunteer ID',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                hintText: 'e.g. VOL-2024-XXXX',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _apply,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Apply as Volunteer',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                'Don\'t have a Volunteer ID? Contact your NGO coordinator.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
