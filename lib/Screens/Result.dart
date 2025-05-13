import 'package:flutter/material.dart';
import 'package:movies/Screens/movie_detail_screen.dart';

class ResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> movies; // ✅ Multiple movies

  ResultScreen({required this.movies});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Search Results"),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: movies.isNotEmpty
          ? GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // ✅ Show movies in a grid
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.6, // Adjust for posters
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: movie),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                "https://image.tmdb.org/t/p/w500${movie['poster_path']}",
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      )
          : Center(
        child: Text(
          "No movies found!",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
