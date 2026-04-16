import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();

  String? _issueType;
  String? _urgency;
  String _description = '';
  bool _isSubmitting = false;

  String _locationText = '';
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _issueTypes = ['Food', 'Medical', 'Shelter', 'Other'];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.amber;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ── MEDIA ────────────────────────────────────────────────────────────────

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take Photo',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'camera_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(
                'Record Video',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'camera_video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Photo from Gallery',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'gallery_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(
                'Video form Gallery',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'gallery_video'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    XFile? file;
    switch (choice) {
      case 'camera_photo':
        file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
        );
        break;
      case 'camera_video':
        file = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60),
        );
        break;
      case 'gallery_photo':
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
        break;
      case 'gallery_video':
        file = await _picker.pickVideo(source: ImageSource.gallery);
        break;
    }

    if (file != null) setState(() => _mediaFiles.add(file!));
  }

  void _removeMedia(int index) => setState(() => _mediaFiles.removeAt(index));

  bool _isVideo(XFile file) {
    final ext = p.extension(file.name).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
  }

  Future<List<String>> _uploadMedia(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final List<String> urls = [];

    for (final file in _mediaFiles) {
      final ext = p.extension(file.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final ref = FirebaseStorage.instance.ref().child(
        'reports/$uid/$docId/$fileName',
      );

      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  // ── SUBMIT ───────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // NEW: Check if media list is empty
    if (_mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one photo or video.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fetch location first')),
      );
      return;
    }

    _formKey.currentState!.save();

    // Capture before reset
    final submittedType = _issueType!;
    final submittedUrgency = _urgency!;
    final submittedDesc = _description;
    final submittedLat = _latitude!;
    final submittedLng = _longitude!;

    setState(() => _isSubmitting = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('reports').doc();
      final docId = docRef.id;

      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) {
        mediaUrls = await _uploadMedia(docId);
      }

      await docRef.set({
        'issueType': submittedType,
        'urgency': submittedUrgency,
        'description': submittedDesc,
        'lat': submittedLat,
        'lng': submittedLng,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unassigned',
        'assignedVolunteers': [],
        'submittedBy': FirebaseAuth.instance.currentUser!.uid,
        'mediaUrls': mediaUrls,
      });

      if (mounted) {
        _formKey.currentState!.reset();
        setState(() {
          _issueType = null;
          _urgency = null;
          _locationText = '';
          _latitude = null;
          _longitude = null;
          _mediaFiles.clear();
        });

        _showConfirmation(
          docId: docId,
          issueType: submittedType,
          urgency: submittedUrgency,
          description: submittedDesc,
          lat: submittedLat,
          lng: submittedLng,
          mediaCount: mediaUrls.length,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── CONFIRMATION DIALOG ──────────────────────────────────────────────────

  void _showConfirmation({
    required String docId,
    required String issueType,
    required String urgency,
    required String description,
    required double lat,
    required double lng,
    required int mediaCount,
  }) {
    final shareText =
        'ReliefNet Report\n'
        '─────────────────\n'
        'ID: $docId\n'
        'Issue: $issueType\n'
        'Urgency: $urgency\n'
        'Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}\n'
        'Description: $description';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 12),
              const Text(
                'Report Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Issue Type', issueType),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Urgency',
                      urgency,
                      valueColor: _getUrgencyColor(urgency),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Location',
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    ),
                    if (mediaCount > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow(
                        'Media',
                        '$mediaCount file${mediaCount > 1 ? 's' : ''} uploaded',
                      ),
                    ],
                    const SizedBox(height: 8),
                    _summaryRow('Description', description),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Report ID
              const Text(
                'Report ID',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              SelectableText(
                docId,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Copy + Share row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copy ID'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report ID copied')),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 15),
                    label: const Text('Share'),
                    onPressed: () =>
                        Share.share(shareText, subject: 'ReliefNet Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  // ── LOCATION ─────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() => _isFetchingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
      setState(() => _isFetchingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        setState(() => _isFetchingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied'),
          ),
        );
      setState(() => _isFetchingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationText =
          'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}';
      _isFetchingLocation = false;
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report an Issue',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            const Text('Issue Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _issueType,
              hint: const Text('Select issue type'),
              items: _issueTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _issueType = val),
              validator: (val) =>
                  val == null ? 'Please select an issue type' : null,
              onSaved: (val) => _issueType = val,
            ),
            const SizedBox(height: 16),

            const Text('Urgency'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _urgency,
              hint: const Text('Select urgency level'),
              items: _urgencyLevels.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _getUrgencyColor(e), size: 14),
                      const SizedBox(width: 10),
                      Text(e),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _urgency = val),
              validator: (val) => val == null ? 'Please select urgency' : null,
              onSaved: (val) => _urgency = val,
            ),
            const SizedBox(height: 16),

            const Text('Location'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'Fetch your location',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: _locationText),
                    validator: (val) =>
                        _latitude == null ? 'Please fetch location' : null,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isFetchingLocation ? null : _getLocation,
                  child: _isFetchingLocation
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── MEDIA SECTION ─────────────────────────────────────────────
            FormField<List<XFile>>(
              initialValue: _mediaFiles,
              validator: (files) {
                if (files == null || files.isEmpty) {
                  return 'Please add at least one photo or video';
                }
                return null;
              },
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Photos / Videos'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_mediaFiles.isNotEmpty) ...[
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _mediaFiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final isVid = _isVideo(_mediaFiles[i]);
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isVid
                                      ? Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.black12,
                                          child: const Icon(
                                            Icons.videocam,
                                            size: 40,
                                            color: Colors.black45,
                                          ),
                                        )
                                      : Image.file(
                                          File(_mediaFiles[i].path),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      _removeMedia(i);
                                      field.didChange(
                                        _mediaFiles,
                                      ); // Updates the validator
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    OutlinedButton.icon(
                      onPressed: _mediaFiles.length >= 5
                          ? null
                          : () async {
                              await _pickMedia();
                              field.didChange(
                                _mediaFiles,
                              ); // Tells the form to re-check the list
                            },
                      style: OutlinedButton.styleFrom(
                        side: field.hasError
                            ? const BorderSide(color: Colors.red, width: 2)
                            : null,
                      ),
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(
                        _mediaFiles.isEmpty
                            ? 'Add Photo / Video'
                            : 'Add More (${_mediaFiles.length}/5)',
                      ),
                    ),

                    // This displays the red error text if validation fails
                    if (field.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          field.errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // ─────────────────────────────────────────────────────────────
            const SizedBox(height: 16),

            const Text('Description'),
            const SizedBox(height: 8),
            TextFormField(
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the issue...',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty
                  ? 'Please enter a description'
                  : null,
              onSaved: (val) => _description = val!,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Report',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
