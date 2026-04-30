import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Base URL configuration
  static const String _baseUrl = 'https://generativelanguage.googleapis.com';
  
  // FIX: Gemini 2.0 Flash model name update
  static const String _modelId = 'gemini-2.5-flash'; 
  
  // v1beta version is standard for Flash 2.0
  static const String _apiVersion = 'v1beta';

  Future<String> sendNetworthDataToGemini({
    required String promptText,
    required Map<String, dynamic> networthData,
    String? userApiKey,
  }) async {
    // API Key handling with fallback
    final apiKey = userApiKey?.trim() ?? "YOUR_DEFAULT_API_KEY"; 
    
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please enter a key.');
    }

    // URL Construction: models path exactly as per Gemini 2.0 documentation
    final url = Uri.parse('$_baseUrl/$_apiVersion/models/$_modelId:generateContent?key=$apiKey');

    // System Prompt and Payload as per your React logic
    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': "You are a professional financial analyst assistant. Answer the user's query concisely and clearly using the portfolio data provided. Use short paragraphs or bullet points. Avoid unnecessary filler sentences.\n\nPortfolio data:\n${jsonEncode(networthData)}\n\nUser query:\n$promptText"
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
      },
    };

    // Retry Logic implementation from React code
    int maxAttempts = 4;
    int baseDelayMs = 800;
    String lastError = "";

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final candidates = json['candidates'] as List? ?? [];
          
          if (candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List? ?? [];
            return parts.map((p) => p['text']?.toString() ?? '').join('\n\n');
          }
          return "Response generated but content is empty.";
        }

        // Detailed Error Handling
        final errorBody = jsonDecode(response.body);
        final apiMessage = errorBody['error']?['message'] ?? "Unknown API Error";
        final apiStatus = errorBody['error']?['status'] ?? "";

        // Quota check logic
        bool isQuotaExceeded = response.statusCode == 429 && 
                              (apiStatus == 'RESOURCE_EXHAUSTED' || apiMessage.toString().contains('quota'));

        if (isQuotaExceeded) {
          throw Exception('Gemini quota exceeded. Please use a key with active quota.');
        }

        lastError = 'Attempt $attempt failed: $apiMessage';

        // Check if retriable (5xx or specific 429)
        bool isRetriable = response.statusCode >= 500 || response.statusCode == 429;
        
        if (!isRetriable || attempt == maxAttempts) {
          throw Exception(lastError);
        }

        // Exponential backoff
        await Future.delayed(Duration(milliseconds: baseDelayMs * attempt));

      } catch (e) {
        lastError = e.toString();
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: baseDelayMs * attempt));
      }
    }
    return "Analysis failed after all attempts: $lastError";
  }
}