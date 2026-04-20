import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const _apiKey = 'Not-working';

  static final _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: _apiKey,
  );

  static Future<Map<String, dynamic>?> analyzeReport({
    required String issueType,
    required String urgency,
    required String description,
  }) async {
    final prompt = '''
You are an AI assistant for ReliefNet, an NGO field reporting platform.
Analyze the following field report and respond ONLY with a valid JSON object. No explanation, no markdown, no backticks.

Report:
- Issue Type: $issueType
- Urgency: $urgency
- Description: $description

Respond with exactly this JSON structure:
{
  "summary": "One clear sentence summarizing the situation",
  "solutions": ["Actionable solution 1", "Actionable solution 2", "Actionable solution 3"],
  "skillset_required": ["Skill 1", "Skill 2", "Skill 3"],
  "estimated_people_affected": "e.g. 10-20 people",
  "action_priority": "Immediate / Within 24 hours / Within a week"
}

Keep solutions practical and specific to the issue type. Keep each skillset item short (1-3 words each, e.g. "First Aid", "Logistics", "Counseling").
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final clean = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      print('GEMINI ERROR: $e');
      return null;
    }
  }
}