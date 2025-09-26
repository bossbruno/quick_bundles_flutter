import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _isAdmin = userData['role'] == 'admin';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isAdmin = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateReportStatus(String reportId, String status, String adminNotes) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
        'adminNotes': adminNotes,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': _auth.currentUser?.uid,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update report: $e')),
        );
      }
    }
  }

  Future<void> _showReportDetails(Map<String, dynamic> report) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report: ${report['reason']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${report['status']}'),
              const SizedBox(height: 8),
              Text('Reporter: ${report['reporterType']}'),
              const SizedBox(height: 8),
              Text('Description: ${report['description']}'),
              const SizedBox(height: 8),
              Text('Bundle: ${report['bundleDetails']['dataAmount']}GB ${report['bundleDetails']['provider']} - GHS${report['bundleDetails']['price']}'),
              const SizedBox(height: 8),
              Text('Chat Status: ${report['chatStatus']}'),
              const SizedBox(height: 16),
              const Text('Recent Messages:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(report['recentMessages'] as List).map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${msg['senderId'] == 'system' ? 'System' : msg['senderId']}: ${msg['text']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: msg['senderId'] == 'system' ? Colors.grey : Colors.black,
                  ),
                ),
              )).toList(),
              if (report['adminNotes']?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(report['adminNotes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (report['status'] == 'pending') ...[
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _showResolveDialog(report['id']);
              },
              child: const Text('Resolve'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showResolveDialog(String reportId) async {
    final statusController = TextEditingController();
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: 'resolved',
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              ],
              onChanged: (value) => statusController.text = value ?? 'resolved',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes',
                hintText: 'Add notes about resolution...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateReportStatus(
                reportId,
                statusController.text.isEmpty ? 'resolved' : statusController.text,
                notesController.text.trim(),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Access')),
        body: const Center(
          child: Text('Access denied. Admin privileges required.'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.report_problem), text: 'Reports'),
              Tab(icon: Icon(Icons.verified_user), text: 'User Verifications'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
      body: TabBarView(
        children: [
          // Reports Tab
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('reports')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data!.docs;

              if (reports.isEmpty) {
                return const Center(
                  child: Text('No reports found. All clear! 🎉'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index].data() as Map<String, dynamic>;
                  final reportId = reports[index].id;
                  final createdAt = report['createdAt'] as Timestamp?;
                  final status = report['status'] ?? 'pending';
                  
                  Color statusColor;
                  switch (status) {
                    case 'pending':
                      statusColor = Colors.orange;
                      break;
                    case 'resolved':
                      statusColor = Colors.green;
                      break;
                    case 'investigating':
                      statusColor = Colors.blue;
                      break;
                    case 'dismissed':
                      statusColor = Colors.grey;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        report['reason'] ?? 'Unknown Reason',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report['description'] ?? 'No description'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${report['reporterType'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (createdAt != null)
                            Text(
                              'Reported: ${createdAt.toDate().toString().substring(0, 16)}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showReportDetails({...report, 'id': reportId}),
                        tooltip: 'View Details',
                      ),
                      onTap: () => _showReportDetails({...report, 'id': reportId}),
                    ),
                  );
                },
              );
            },
          ),
          
          // User Verifications Tab
          const UserVerificationScreen(),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          if (DefaultTabController.of(context)?.index == 0) {
            // Only show FAB on the Reports tab
            return FloatingActionButton.extended(
              onPressed: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'kwakye105@gmail.com',
                  query: 'subject=Quick Bundles Admin Report Summary',
                );
                
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.email),
              label: const Text('Email Admin'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            );
          }
          return const SizedBox.shrink();
        },
      ),
      ),
    );
  }
}
