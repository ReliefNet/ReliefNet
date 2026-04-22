import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyAad2mVDrKfYzv2tqv3KYqET0KuHrYpDMw';

  static final _model = GenerativeModel(
    // Following 2026 "Free & Fast" standard request
    model: 'gemini-3.1-flash-lite-preview',
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
      print('DEBUG: Sending prompt to Gemini: $prompt');
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      print('DEBUG: Gemini raw response: $text');
      
      // Attempt to extract JSON from the response
      final jsonStartIndex = text.indexOf('{');
      final jsonEndIndex = text.lastIndexOf('}');
      
      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        final jsonString = text.substring(jsonStartIndex, jsonEndIndex + 1);
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        print('DEBUG: Gemini decoded JSON: $decoded');
        return decoded;
      }
      
      print('DEBUG: Gemini response did not contain valid JSON block');
      return null;
    } catch (e) {
      print('GEMINI ERROR: $e');
      return null;
    }
  }
}