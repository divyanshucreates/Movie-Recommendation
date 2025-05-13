import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:movies/Screens/movie_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchlistScreen extends StatefulWidget {
  @override
  _WatchlistScreenState createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<Map<String, dynamic>> _movieList = [];

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedMovieJson = prefs.getStringList('saved_movies') ?? [];

    List<Map<String, dynamic>> movies = savedMovieJson
        .map((movieJson) => jsonDecode(movieJson) as Map<String, dynamic>)
        .toList();

    setState(() {
      _movieList = movies;
    });
  }

  Future<void> _removeFromWatchlist(String movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedMovieJson = prefs.getStringList('saved_movies') ?? [];

    savedMovieJson.removeWhere((movieJson) {
      final movie = jsonDecode(movieJson);
      return movie['id'].toString() == movieId;
    });

    await prefs.setStringList('saved_movies', savedMovieJson);
    _loadWatchlist();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Removed from Watchlist")),
    );
  }


  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;

    // Determine if dark mode is enabled
    bool isDarkMode = brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text("My Watchlist", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
      body: _movieList.isEmpty
          ? Center(
        child: Text(
          "Your watchlist is empty.",
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: _movieList.length,
        itemBuilder: (context, index) {
          final movie = _movieList[index];
          return GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)));
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Poster Image
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: movie['poster_path'] != null
                        ? Image.network(
                      'https://image.tmdb.org/t/p/w154${movie['poster_path']}',
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 100,
                      height: 150,
                      color: Colors.grey[800],
                      child: Icon(Icons.movie,
                          color: Colors.white60, size: 40),
                    ),
                  ),
                  // Movie Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie['title'] ?? 'Unknown Title',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          if (movie['release_date'] != null)
                            Text(
                              "Release: ${movie['release_date']}",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          SizedBox(height: 6),
                          if (movie['overview'] != null)
                            Text(
                              movie['overview'],
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 13),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _removeFromWatchlist(
                        movie['id'].toString()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
