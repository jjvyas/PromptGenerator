import 'dart:convert';
import 'package:http/http.dart' as http;

class PromptService {
  final String backendUrl;

  PromptService({this.backendUrl = 'http://127.0.0.1:8000'});

  Future<Map<String, dynamic>> checkHealth() async {
    final url = Uri.parse('$backendUrl/api/health');
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Backend health check failed (${response.statusCode}): ${response.body}');
  }

  Future<String> generateMasterPrompt({
    required String rawInput,
    required String tone,
    required String detailLevel,
    required String lengthConstraint,
    String? token,
    bool isTrial = false,
  }) async {
    final url = Uri.parse('$backendUrl/api/generate-prompt');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (isTrial) {
      headers['X-Trial-Request'] = 'true';
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'raw_input': rawInput,
        'tone': tone,
        'detail_level': detailLevel,
        'length_constraint': lengthConstraint,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final masterPrompt = data['master_prompt'] as String;
      return masterPrompt.trim();
    } else {
      throw Exception('Failed to generate master prompt from backend: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> generateTemplateSpec({
    required String idea,
    String? token,
    bool isTrial = false,
  }) async {
    final url = Uri.parse('$backendUrl/api/generate-template-spec');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (isTrial) {
      headers['X-Trial-Request'] = 'true';
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'idea': idea,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data as Map<String, dynamic>;
    } else {
      throw Exception('Failed to generate template spec from backend: ${response.body}');
    }
  }
}
