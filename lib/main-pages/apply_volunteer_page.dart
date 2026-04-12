import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ApplyVolunteerPage extends StatefulWidget {
  const ApplyVolunteerPage({super.key});

  @override
  State<ApplyVolunteerPage> createState() => _ApplyVolunteerPageState();
}

class _ApplyVolunteerPageState extends State<ApplyVolunteerPage> {
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
  final _skillsController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _isLoading = false;
  DocumentSnapshot? _existingApplication;

  @override
  void initState() {
    super.initState();
    _checkExistingApplication();
    // Pre-fill email from current user if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _checkExistingApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() => _existingApplication = doc);
      }
    } catch (e) {
      debugPrint("Error checking application: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_emailController.text.isEmpty ||
        _reasonController.text.isEmpty ||
        _skillsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in the required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'email': _emailController.text.trim(),
            'reason': _reasonController.text.trim(),
            'skills': _skillsController.text.trim(),
            'experience': _experienceController.text.trim(),
            'status': 'pending',
            'appliedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application submitted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _existingApplication == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'];
          final volunteerId = data['volunteerId'];

          print("DEBUG: Application Data found for UID: ${user.uid}");
          print("DEBUG: Status: $status");
          print("DEBUG: VolunteerID: $volunteerId");

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      status == 'approved'
                          ? Icons.check_circle_outline
                          : Icons.hourglass_empty,
                      size: 80,
                      color: status == 'approved'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      status == 'approved'
                          ? "Congratulations! Your application is approved."
                          : "Your application is currently being reviewed.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    if (status == 'approved' && volunteerId != null) ...[
                      const Text(
                        "Your Unique Volunteer UID:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          // This is the core logic
                          Clipboard.setData(
                            ClipboardData(text: "Text to copy"),
                          );

                          // Optional: Show a SnackBar to let the user know it worked
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Copied to clipboard!")),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Text(
                            volunteerId.toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              fontFamily: 'monospace',
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Copy this 12-digit UID and enter it in your Profile section to unlock all volunteer features.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (status == 'pending') ...[
                      const Text(
                        "Our team is performing a thorough check. You will receive your unique 12-digit UID once approved.",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Divider(),
                      const SizedBox(height: 10),
                      SelectableText(
                        "Firestore Document ID: ${user.uid}",
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const Text(
                        "(Use this ID to find your application in the Firebase Console)",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const Text("Back to Home"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Apply as Volunteer")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Join our team of volunteers and help make a difference!",
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 25),
                Text(
                  "Email Address for Updates *",
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Enter your email address...",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  "Why do you want to volunteer? *",
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Tell us about your motivation...",
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text("Your Skills *", style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    hintText: "e.g., First Aid, Driving, Cooking, etc.",
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  "Previous Experience (Optional)",
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _experienceController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: "Tell us about any relevant work you've done...",
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 30),
                SelectableText(
                  "Your UID: ${user.uid}",
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Submit Application"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
