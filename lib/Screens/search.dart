import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movies/Screens/movie_detail_screen.dart';
import 'package:movies/Screens/Cast.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  List _movies = [];
  List _actors = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _noResults = false;
  String _errorMessage = "";
  final String apiKey = '605177edc454a9d34b3d3f16d1cc8344'; // Add your TMDB API Key

  // Function to search movies and actors based on the search query
  Future<void> searchMoviesAndActors(String query) async {
    if (query.isEmpty) {
      setState(() {
        _movies = [];
        _actors = [];
        _hasError = false;
        _noResults = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _noResults = false;
    });

    try {
      final movieResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/search/movie?api_key=$apiKey&query=$query'),
      );
      final actorResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/search/person?api_key=$apiKey&query=$query'),
      );

      if (movieResponse.statusCode == 200 && actorResponse.statusCode == 200) {
        final movieData = json.decode(movieResponse.body);
        final actorData = json.decode(actorResponse.body);

        List movieList = movieData['results'];
        List actorList = actorData['results'];

        // If actor is found, extract their known movies
        if (actorList.isNotEmpty) {
          final firstActor = actorList[0];
          if (firstActor['known_for'] != null) {
            final knownMovies = firstActor['known_for'].where((item) => item['media_type'] == 'movie').toList();
            movieList = [...knownMovies, ...movieList];
          }
        }

        // If movie is found, get its cast
        List castList = [];
        if (movieList.isNotEmpty) {
          final movieId = movieList[0]['id'];
          final creditsResponse = await http.get(
            Uri.parse('https://api.themoviedb.org/3/movie/$movieId/credits?api_key=$apiKey'),
          );
          if (creditsResponse.statusCode == 200) {
            final creditsData = json.decode(creditsResponse.body);
            castList = creditsData['cast'];
          }
        }

        setState(() {
          _movies = movieList;
          _actors = [...actorList, ...castList];
          _isLoading = false;
          if (_movies.isEmpty && _actors.isEmpty) {
            _noResults = true;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load data. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Search'),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_hasError)
              _buildErrorWidget()
            else if (_noResults)
                _buildNoResultsWidget()
              else
                _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (query) {
          searchMoviesAndActors(query);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Search Movies or Actors...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _movies = [];
                _actors = [];
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Text(
        _errorMessage,
        style: TextStyle(color: Colors.red, fontSize: 16),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Text(
        'No results found.',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  Widget _buildResults() {
    return Expanded(
      child: ListView(
        children: [
          // === ACTORS ===
          if (_actors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actors/Directors:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 140, // enough height for big CircleAvatar + name
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _actors.length,
                      itemBuilder: (context, index) {
                        final actor = _actors[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () =>{
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CastDetailScreen(personId: actor['id'])))
                          },
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundImage: actor['profile_path'] != null && actor['profile_path'].toString().isNotEmpty
                                      ? NetworkImage("http://image.tmdb.org/t/p/original/${actor['profile_path']}")
                                      : NetworkImage("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQHFfZsqDCHSjzfnxn6eaTRqiMCN8jLzak7Lg&s"),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    actor['name'] ?? 'No Name',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    actor['known_for_department'] ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // === MOVIES ===
          if (_movies.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Movies:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _movies.length,
                  itemBuilder: (context, index) {
                    final movie = _movies[index];
                    return GestureDetector(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)));
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: movie['poster_path'] != null
                                ? Image.network(
                              'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                              width: 60,
                              height: 90,
                              fit: BoxFit.cover,
                            )
                                : Icon(Icons.movie, size: 40),
                          ),
                          title: Text(
                            movie['title'] ?? 'No Title',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            movie['release_date'] ?? 'Release Date Unavailable',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }



  void _showActorDetails(actor) {
    // Implement actor details view
  }
}
