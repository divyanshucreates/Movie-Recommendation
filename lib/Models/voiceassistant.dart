import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:movies/Models/tmdb_service.dart'; // Ensure TMDB service is imported

class VoiceHelper extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _spokenText = "";
  List<Map<String, dynamic>> _movies = [];

  List<Map<String, dynamic>> get movies => _movies; // ✅ Add this getter

  Future<void> startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(onResult: (result) {
        _spokenText = result.recognizedWords;
        notifyListeners();
        fetchMovies(_spokenText); // Fetch movies based on voice
      });
    }
  }

  Future<void> fetchMovies(String query) async {
    try {
      TMDBService tmdb = TMDBService();
      List<Map<String, dynamic>> fetchedMovies = await tmdb.searchMovies(query);
      _movies = fetchedMovies;
      notifyListeners();
    } catch (e) {
      print("Error fetching movies: $e");
      _movies = [];
      notifyListeners();
    }
  }
}
