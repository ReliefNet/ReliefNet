import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

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

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final TextEditingController _locationController = TextEditingController();

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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fetch location first')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'issueType': _issueType,
        'urgency': _urgency,
        'description': _description,
        'lat': _latitude,
        'lng': _longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully!')),
        );

        _formKey.currentState!.reset();
        _locationController.clear();

        setState(() {
          _issueType = null;
          _urgency = null;
          _latitude = null;
          _longitude = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isFetchingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _isFetchingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permanently denied')),
      );
      setState(() => _isFetchingLocation = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationController.text =
          "Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}";
      _isFetchingLocation = false;
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report an Issue",
              style: textTheme.bodyLarge?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 20),

            /// Issue Type
            Text("Issue Type", style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _issueType,
              hint: Text("Select issue type", style: textTheme.bodySmall),
              items: _issueTypes.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e, style: textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: (val) => setState(() => _issueType = val),
              validator: (val) =>
                  val == null ? 'Please select an issue type' : null,
              onSaved: (val) => _issueType = val,
            ),
            const SizedBox(height: 16),

            /// Urgency
            Text("Urgency", style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _urgency,
              hint: Text("Select urgency level", style: textTheme.bodySmall),
              items: _urgencyLevels.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _getUrgencyColor(e), size: 14),
                      const SizedBox(width: 10),
                      Text(e, style: textTheme.bodyMedium),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _urgency = val),
              validator: (val) => val == null ? 'Please select urgency' : null,
              onSaved: (val) => _urgency = val,
            ),
            const SizedBox(height: 16),

            /// Location
            Text("Location", style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    readOnly: true,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: "Fetch your location",
                      hintStyle: textTheme.bodySmall,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (_) =>
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

            /// Description
            Text("Description", style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 4,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Describe the issue...",
                hintStyle: textTheme.bodySmall,
                border: const OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty
                  ? 'Please enter a description'
                  : null,
              onSaved: (val) => _description = val!,
            ),

            const SizedBox(height: 24),

            /// Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Submit Report",
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
