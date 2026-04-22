import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_profile_widgets.dart';

class SubmittedReportsPage extends StatefulWidget {
  const SubmittedReportsPage({super.key});

  @override
  State<SubmittedReportsPage> createState() => _SubmittedReportsPageState();
}

class _SubmittedReportsPageState extends State<SubmittedReportsPage> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'Not signed in.';
        _isLoading = false;
      });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reports')
          .where('submittedBy', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_docId'] = d.id;
        return data;
      }).toList();

      setState(() {
        _reports = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case 'High':
        return const Color(0xFFEF4444);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'Low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  IconData _issueIcon(String type) {
    switch (type) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Medical':
        return Icons.local_hospital_outlined;
      case 'Shelter':
        return Icons.home_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF22C55E);
      case 'assigned':
        return const Color(0xFF6366F1);
      case 'unassigned':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Submitted Reports'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!)
              : _reports.isEmpty
          ? const EmptyState(
              icon: Icons.description_outlined,
              title: 'No Reports Yet',
              subtitle: 'Reports you submit will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, i) {
                  final r = _reports[i];
                  final issueType = r['issueType'] as String? ?? 'Other';
                  final description = r['description'] as String? ?? '';
                  final status = r['status'] as String? ?? 'unassigned';
                  final urgency = r['urgency'] as String? ?? 'Low';
                  final location = r['location'] as String? ?? '';
                  final ts = r['timestamp'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _issueIcon(issueType),
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issueType,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (location.isNotEmpty)
                                      Text(
                                        location,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              // Urgency badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _urgencyColor(urgency).withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _urgencyColor(urgency).withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  urgency,
                                  style: TextStyle(
                                    color: _urgencyColor(urgency),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                                height: 1.4,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Footer row
                          Row(
                            children: [
                              // Status chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _statusColor(status),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      status[0].toUpperCase() +
                                          status.substring(1),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _timeAgo(ts),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}