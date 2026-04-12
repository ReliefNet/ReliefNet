import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerPage extends StatelessWidget {
  const VolunteerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Tasks")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('assignedTo', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final currentTasks = docs.where((d) {
            final status = d['status'];
            return status == 'assigned' || status == 'in_progress' || status == 'reached';
          }).toList();

          final completedTasks = docs.where((d) {
            return d['status'] == 'completed';
          }).toList();

          final rejectedTasks = docs.where((d) {
            return d['status'] == 'rejected';
          }).toList();

          final textTheme = Theme.of(context).textTheme;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔹 Completed Tasks
                Text(
                  "Completed Tasks",
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),

                if (completedTasks.isEmpty)
                  const Text("No completed tasks"),

                ...completedTasks.map((doc) =>
                    CompletedTaskCard(doc: doc)).toList(),

                const SizedBox(height: 30),

                /// 🔹 Tasks in Progress
                Text(
                  "Tasks in Progress",
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),

                if (currentTasks.isEmpty)
                  const Text("No tasks in progress"),

                ...currentTasks.map((doc) =>
                    ActiveTaskCard(doc: doc)).toList(),

                const SizedBox(height: 30),

                /// 🔹 Rejected Tasks
                Text(
                  "Rejected Tasks",
                  style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 10),

                if (rejectedTasks.isEmpty)
                  const Text("No rejected tasks"),

                ...rejectedTasks.map((doc) =>
                    RejectedTaskCard(doc: doc)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
class ActiveTaskCard extends StatelessWidget {
  const ActiveTaskCard({super.key, required this.doc});

  final QueryDocumentSnapshot doc;

  Future<void> updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(doc.id)
        .update({'status': status});
  }

  Widget buildActionButton(String status) {
    if (status == 'assigned') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => updateStatus('rejected'),
            child: const Text("Reject", style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => updateStatus('in_progress'),
            child: const Text("On the way"),
          ),
        ],
      );
    }

    if (status == 'in_progress') {
      return ElevatedButton(
        onPressed: () => updateStatus('reached'),
        child: const Text("Reached"),
      );
    }

    if (status == 'reached') {
      return ElevatedButton(
        onPressed: () => updateStatus('completed'),
        child: const Text("Resolved"),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'assigned';
    final lat = data['lat'];
    final lng = data['lng'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),

            Text(description),

            const SizedBox(height: 10),

            Text("Status: $status"),

            const SizedBox(height: 10),

            Row(
              children: [
                if (lat != null && lng != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                      );
                      await launchUrl(uri);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text("Navigate"),
                  ),

                const Spacer(),

                buildActionButton(status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class CompletedTaskCard extends StatelessWidget {
  const CompletedTaskCard({super.key, required this.doc});

  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final proofImage = data['proofImage'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),

            Text(description),

            const SizedBox(height: 10),

            const Text("Status: Completed"),

            if (proofImage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(proofImage, height: 120),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RejectedTaskCard extends StatelessWidget {
  const RejectedTaskCard({super.key, required this.doc});

  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 10),
            const Text("Status: Rejected", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}