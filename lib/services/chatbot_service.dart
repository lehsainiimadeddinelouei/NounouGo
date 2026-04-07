import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role; // 'user' ou 'assistant'
  final String content;
  const ChatMessage({required this.role, required this.content});
}

class ChatbotService {
  // ⚠️ Remplacez par votre clé Gemini (aistudio.google.com → Get API Key)
  static const String _apiKey = 'AIzaSyC_4QBnLpk66OVFjCxP6Qk124HeHwbAWdY';

  static const String _systemPrompt =
      "Tu es l'assistant IA officiel de NounouGo, une application mobile française de mise en relation entre parents et nounous (babysitters). "
      "L'app est disponible sur iOS et Android. "
      "Fonctionnalités principales : recherche géolocalisée, profils 100% vérifiés, réservation en direct, messagerie intégrée, paiement sécurisé, système d'évaluations, historique des gardes, notifications en temps réel. "
      "3 rôles : Parent, Nounou (Babysitter), Admin. "
      "Inscription gratuite. Connexion par email/mot de passe ou OTP par téléphone. Interface en français. "
      "Réponds toujours en français, de façon chaleureuse, concise et utile. Utilise des emojis avec modération.";

  Future<String> sendMessage(List<ChatMessage> history) async {
    final contents = history.map((m) => {
      'role': m.role == 'assistant' ? 'model' : 'user',
      'parts': [{'text': m.content}],
    }).toList();

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$_apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [{'text': _systemPrompt}],
        },
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': 1000,
          'temperature': 0.7,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else {
      throw Exception('Erreur API (${response.statusCode}): ${response.body}');
    }
  }
}
