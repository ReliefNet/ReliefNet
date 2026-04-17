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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          // title: const Text("My Tasks"),
          title: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Completed"),
              Tab(text: "Rejected"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('assignedVolunteers', arrayContains: user.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("Firestore Stream Error: ${snapshot.error}");
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText(
                    "Error: ${snapshot.error}\n\nIf this is an index error, check your console for a link to create it.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
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

            return TabBarView(
              children: [
                _buildTaskList(context, currentTasks, emptyMessage: "No active tasks right now.", emptyIcon: Icons.assignment_turned_in_outlined, isCurrent: true),
                _buildTaskList(context, completedTasks, emptyMessage: "You haven't completed any tasks yet.", emptyIcon: Icons.check_circle_outline, isCompleted: true),
                _buildTaskList(context, rejectedTasks, emptyMessage: "No rejected tasks.", emptyIcon: Icons.cancel_outlined, isRejected: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<QueryDocumentSnapshot> tasks, {required String emptyMessage, required IconData emptyIcon, bool isCurrent = false, bool isCompleted = false, bool isRejected = false}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final doc = tasks[index];
        if (isCurrent) return ActiveTaskCard(doc: doc);
        if (isCompleted) return CompletedTaskCard(doc: doc);
        if (isRejected) return RejectedTaskCard(doc: doc);
        return const SizedBox();
      },
    );
  }
}

// Helpers for UI
IconData getIconForIssueType(String type) {
  switch (type.toLowerCase()) {
    case 'medical': return Icons.medical_services;
    case 'food': return Icons.fastfood;
    case 'shelter': return Icons.house;
    case 'fire': return Icons.local_fire_department;
    case 'water': return Icons.water_drop;
    default: return Icons.report_problem;
  }
}

Color getColorForIssueType(String type) {
  switch (type.toLowerCase()) {
    case 'medical': return Colors.red;
    case 'food': return Colors.orange;
    case 'shelter': return Colors.indigo;
    case 'fire': return Colors.deepOrange;
    case 'water': return Colors.blue;
    default: return Colors.blueGrey;
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor = Colors.white;
    String displayStatus = status.replaceAll('_', ' ').toUpperCase();

    switch (status) {
      case 'assigned':
        bgColor = Colors.blue.shade600;
        break;
      case 'in_progress':
        bgColor = Colors.orange.shade600;
        break;
      case 'reached':
        bgColor = Colors.purple.shade600;
        break;
      case 'completed':
        bgColor = Colors.green.shade600;
        break;
      case 'rejected':
        bgColor = Colors.red.shade600;
        break;
      default:
        bgColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
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
            child: const Text("Decline", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              elevation: 0,
            ),
            onPressed: () => updateStatus('in_progress'),
            child: const Text("Accept & Go"),
          ),
        ],
      );
    }

    if (status == 'in_progress') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          elevation: 0,
        ),
        onPressed: () => updateStatus('reached'),
        icon: const Icon(Icons.location_on),
        label: const Text("I have reached"),
      );
    }

    if (status == 'reached') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade600,
          elevation: 0,
        ),
        onPressed: () => updateStatus('completed'),
        icon: const Icon(Icons.check_circle),
        label: const Text("Mark Resolved"),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? 'No description provided.';
    final status = data['status'] ?? 'assigned';
    final lat = data['lat'];
    final lng = data['lng'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: getColorForIssueType(issue).withOpacity(0.1),
                  child: Icon(getIconForIssueType(issue), color: getColorForIssueType(issue)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (lat != null && lng != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 18),
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

    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? 'No description provided.';
    final proofImage = data['proofImage'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const StatusBadge(status: 'completed'),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            if (proofImage != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  proofImage,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
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

    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? 'No description provided.';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Theme.of(context).brightness == Brightness.light ? Colors.red.shade50 : Colors.red.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: const Icon(Icons.cancel, color: Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const StatusBadge(status: 'rejected'),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}