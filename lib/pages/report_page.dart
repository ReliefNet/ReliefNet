import 'package:flutter/material.dart';

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
  String _location = '';

  final List<String> _issueTypes = ['Food', 'Medical', 'Shelter', 'Other'];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // will send to Firebase here later
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted!')));
    }
  }

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
              "Report an Issue",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Issue Type
            const Text("Issue Type"),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _issueType,
              hint: const Text("Select issue type"),
              items: _issueTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _issueType = val),
              validator: (val) =>
                  val == null ? 'Please select an issue type' : null,
              onSaved: (val) => _issueType = val,
            ),
            const SizedBox(height: 16),

            // Urgency
            const Text("Urgency"),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _urgency,
              hint: const Text("Select urgency level"),
              items: _urgencyLevels
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _urgency = val),
              validator: (val) => val == null ? 'Please select urgency' : null,
              onSaved: (val) => _urgency = val,
            ),
            const SizedBox(height: 16),

            // Location
            const Text("Location"),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: "Enter location",
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Please enter a location' : null,
              onSaved: (val) => _location = val!,
            ),
            const SizedBox(height: 16),

            // Description
            const Text("Description"),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Describe the issue...",
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty
                  ? 'Please enter a description'
                  : null,
              onSaved: (val) => _description = val!,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Submit Report",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
