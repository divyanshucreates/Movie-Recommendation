import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:movies/Screens/movie_detail_screen.dart';

class GenreScreen extends StatefulWidget {
  @override
  _GenreScreenState createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  final Map<String, int> genreMap = {
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Documentary': 99,
    'Drama': 18,
    'Family': 10751,
    'Fantasy': 14,
    'Historical': 36,
    'Horror': 27,
    'Music': 10402,
    'Mystery': 9648,
    'Mythology': 878, // Using Sci-Fi ID for now
    'Romance': 10749,
    'Sci-Fi': 878,
    'Thriller': 53,
  };

  final List<String> genreImages = [
    'action.webp', 'adventure.webp', 'animation.webp', 'comedy.webp',
    'crime.webp', 'documentary.webp', 'drama.webp', 'family.webp',
    'fantasy.webp', 'historical.webp', 'horror.webp', 'music.webp',
    'mystery.webp', 'mythlogy.webp', 'romance.webp', 'sci_fi.webp',
    'thriller.webp',
  ];

  final List<String> genreNames = [
    'Action', 'Adventure', 'Animation', 'Comedy',
    'Crime', 'Documentary', 'Drama', 'Family',
    'Fantasy', 'Historical', 'Horror', 'Music',
    'Mystery', 'Mythology', 'Romance', 'Sci-Fi',
    'Thriller',
  ];

  List _movies = [];
  bool _isLoading = false;
  bool _hasError = false;
  final String apiKey = '605177edc454a9d34b3d3f16d1cc8344';

  Future<List<dynamic>> fetchMoviesByGenre(int genreId) async {
    try {
      final movieResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=$genreId'),
      );

      if (movieResponse.statusCode == 200) {
        final movieData = json.decode(movieResponse.body);
        return movieData['results'];
      } else {
        throw Exception('Failed to load movies');
      }
    } catch (e) {
      throw Exception('Error fetching movies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Genres')),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        itemCount: genreNames.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          String genre = genreNames[index];
          int genreId = genreMap[genre] ?? 0;
          return GestureDetector(
            onTap: () async {
              try {
                List<dynamic> movies = await fetchMoviesByGenre(genreId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GenreMoviesScreen(genre: genre, movies: movies),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching movies: $e')),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/genres/${genreImages[index]}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class GenreMoviesScreen extends StatelessWidget {
  final String genre;
  final List<dynamic> movies;

  GenreMoviesScreen({required this.genre, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$genre Movies'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: movies.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final movie = movies[index];
            final title = movie['title'] ?? '';
            final posterUrl = movie['poster_path'] ?? 'https://www.juliedray.com/wp-content/uploads/2022/01/sans-affiche.png';

            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)));
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        child: posterUrl.isNotEmpty
                            ? Image.network(
                          'https://image.tmdb.org/t/p/w500$posterUrl', // Correct image URL
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 40),
                        )
                            : Image.network(
                          'https://www.juliedray.com/wp-content/uploads/2022/01/sans-affiche.png', // Default image when posterUrl is empty
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        alignment: Alignment.center,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


