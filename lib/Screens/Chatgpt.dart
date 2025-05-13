import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGPTService {
  final String apiKey = "sk-abcdef1234567890abcdef1234567890abcdef12";

  Future<List<String>> getMovieSuggestions(String query) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "text-davinci-003",
        "prompt": "Suggest 5 movies similar to: $query",
        "max_tokens": 100
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> movies = data["choices"][0]["text"].split("\n").where((m) => m.isNotEmpty).toList();
      return movies;
    } else {
      throw Exception("Failed to fetch recommendations");
    }
  }
}
