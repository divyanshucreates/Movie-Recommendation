import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // To get country code
import 'package:shimmer/shimmer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:movies/Screens/platform.dart';
import 'package:movies/Screens/Cast.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences



class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  MovieDetailsScreen({required this.movie});

  @override
  _MovieDetailsScreenState createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late Future<List<String>> _genresFuture;
  late Future<List<String>> _spokenFuture;
  List<Map<String, dynamic>> castList = [];
  List<Map<String, dynamic>> director = [];
  String? trailerUrl;
  String? formattedRuntime;
  String productionCompany = "N/A";
  YoutubePlayerController? _controller;
  List<dynamic> crewMembers = [];
  List<String> availableCountries = [];
  List<String> spokenLanguages = [];
  Map<String, List<String>> availablePlatforms = {};
  String? userCountryCode;
  String? userCountry;

  bool isLoading = true;
  List<String> userPlatforms = [];

  final String apiKey = "605177edc454a9d34b3d3f16d1cc8344"; // API Key yahaan daalein
  final String baseUrl = "http://api.themoviedb.org/3";

  @override
  void initState() {
    super.initState();
    _genresFuture = fetchMovieGenres(widget.movie['id']);
    _spokenFuture = getSpokenLanguages(widget.movie['id']);
    fetchCast(widget.movie['id']);
    fetchCrewMembers(widget.movie['id']);
    fetchMovieDetails();
    fetchDirector(widget.movie['id']);
    getMovieTrailer(widget.movie['id']);
    print('movie 🥲🥲🥲🥲😁❤️➡️❤️👋👋${castList}');
  }
  Future<String?> getUserCountry() async {
    final response = await http.get(Uri.parse('http://ip-api.com/json/?fields=countryCode'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['countryCode']; // Returns country code like 'IN', 'US', 'UK'
    }

    return null;
  }


  Future<List<Map<String, dynamic>>> getSimilarMovies(int movieId) async {
    final response = await http.get(Uri.parse("$baseUrl/movie/$movieId/similar?api_key=$apiKey"));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    }
    return [];
  }

  // ✅ Fetch Trending Movies
  Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    // ✅ Get the user's country code
    String? userCountry = await getUserCountry();

    final response = await http.get(Uri.parse("$baseUrl/trending/movie/week?api_key=$apiKey"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Map<String, dynamic>> movies = List<Map<String, dynamic>>.from(data['results']);

      // ✅ Sort movies to show user's country movies first
      movies.sort((a, b) {
        String countryA = a['origin_country'] != null && a['origin_country'].isNotEmpty
            ? a['origin_country'][0]
            : "ZZ"; // Default if no country
        String countryB = b['origin_country'] != null && b['origin_country'].isNotEmpty
            ? b['origin_country'][0]
            : "ZZ";

        // ✅ Move user's country movies to the top
        if (userCountry != null) {
          if (countryA == userCountry && countryB != userCountry) return -1;
          if (countryB == userCountry && countryA != userCountry) return 1;
        }

        return countryA.compareTo(countryB);
      });

      return movies;
    }
    return [];
  }

  // ✅ Fetch Franchise Movies (Belongs to Collection)
  Future<List<Map<String, dynamic>>> getFranchiseMovies(int movieId) async {
    final response = await http.get(Uri.parse("$baseUrl/movie/$movieId?api_key=$apiKey&append_to_response=belongs_to_collection"));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['belongs_to_collection'] != null) {
        int collectionId = data['belongs_to_collection']['id'];
        return fetchCollectionMovies(collectionId);
      }
    }
    return [];
  }
  Future<List<Map<String, dynamic>>> getGenreMovies(List<int> genreIds) async {
    if (genreIds.isEmpty) return [];

    int genreId = genreIds[0];  // First genre pick karenge
    final response = await http.get(Uri.parse(
        "http://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=$genreId"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchCollectionMovies(int collectionId) async {
    final response = await http.get(Uri.parse("$baseUrl/collection/$collectionId?api_key=$apiKey"));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['parts']);
    }
    return [];
  }

  // ✅ Smart AI-Based Movie Recommendation
  Future<List<Map<String, dynamic>>> getRecommendedMovies(int movieId) async {
    List<Map<String, dynamic>> recommendedMovies = [];

    // ✅ Step 1: Fetch Franchise Movies (High Priority)
    List<Map<String, dynamic>> franchiseMovies = await getFranchiseMovies(movieId);
    recommendedMovies.addAll(franchiseMovies);

    // ✅ Step 2: Get Movies from the Same Production House
    if (franchiseMovies.isNotEmpty) {
      int firstMovieId = franchiseMovies[0]['id']; // Take first franchise movie
      List<Map<String, dynamic>> productionHouseMovies = await getMoviesFromSameProduction(firstMovieId);
      recommendedMovies.addAll(productionHouseMovies);
    }

    // ✅ Step 3: Fetch Similar Movies
    recommendedMovies.addAll(await getSimilarMovies(movieId));

    // ✅ Step 4: Fetch Trending Movies (Fallback)
    recommendedMovies.addAll(await getTrendingMovies());

    // ✅ Step 5: Remove Duplicates and Exclude Current Movie
    return recommendedMovies.toSet().where((movie) => movie['id'] != movieId).toList();
  }

// ✅ Function to Fetch Movies from the Same Production House
  Future<List<Map<String, dynamic>>> getMoviesFromSameProduction(int movieId) async {
    final response = await http.get(Uri.parse("$baseUrl/movie/$movieId?api_key=$apiKey"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['production_companies'] != null && data['production_companies'].isNotEmpty) {
        int productionCompanyId = data['production_companies'][0]['id'];

        final prodResponse = await http.get(Uri.parse(
            "$baseUrl/discover/movie?api_key=$apiKey&with_companies=$productionCompanyId"));

        if (prodResponse.statusCode == 200) {
          final prodData = jsonDecode(prodResponse.body);
          return List<Map<String, dynamic>>.from(prodData['results']);
        }
      }
    }
    return [];
  }


  Future<void> fetchCast(int movieId) async {
    // Corrected the URL to use the movieId dynamically
    final String url =
        "https://api.themoviedb.org/3/movie/$movieId/credits?api_key=$apiKey";

    print("Fetching cast from: $url"); // Check API URL

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print("API Response: $data"); // Debugging Response

      if (data.containsKey('cast')) {
        List<dynamic> cast = data['cast'];

        setState(() {
          castList = cast.take(10).map((actor) {
            return {
              "id": actor['id'] ?? 0, // Default to 0 if null
              "name": actor['name'] ?? "Unknown",
              "character": actor['character'] ?? "Unknown",
              "gender": (actor['gender'] ?? 0).toString(), // Default to "0"
              "image": actor['profile_path'] != null
                  ? "https://image.tmdb.org/t/p/w200${actor['profile_path']}"
                  : "" // Default to empty string
            };
          }).toList();
        });

        print("Cast List Loaded: $castList"); // Check Processed Cast List
      } else {
        print("Error: 'cast' key not found in response");
      }
    } else {
      print("Failed to load cast data. Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}"); // Check error message
    }
  }

  Future<void> fetchDirector(int movieId) async {
    final String url =
        "http://api.themoviedb.org/3/movie/${movieId}/credits?api_key=$apiKey";

    print("Fetching director from: $url"); // Debugging API URL

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print("API Response: $data"); // Debugging API Response

      if (data.containsKey('crew')) {
        List<dynamic> crew = data['crew'];

        // Extract all directors
        List<Map<String, dynamic>> directorsList = crew
            .where((person) => person['job'] == "Director") // Filter all directors
            .map((directorData) => {
          "name": directorData['name'] ?? "Unknown",
          "id" : directorData['id']??0,
          "gender":directorData['gender'].toString()??"0",
          "image": directorData['profile_path'] != null
              ? "http://image.tmdb.org/t/p/w200${directorData['profile_path']}"
              : ""
        })
            .toList();

        setState(() {
          director = directorsList;
        });

        print("Directors Loaded: $director"); // Debugging Directors List
      } else {
        print("Error: 'crew' key not found in response");
      }
    } else {
      print("Failed to load director data. Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}"); // Debugging Error Message
    }
  }

  Future<void> getMovieTrailer(int movieId) async {
    String url = "http://api.themoviedb.org/3/movie/$movieId/videos?api_key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List videos = data['results'];

      if (videos.isNotEmpty) {
        final trailer = videos.firstWhere(
              (video) => video['type'] == "Trailer" && video['site'] == "YouTube",
          orElse: () => null,
        );

        if (trailer != null) {
          setState(() {
            trailerUrl = "https://www.youtube.com/watch?v=${trailer['key']}";
          });
          _initializePlayer();
          return;
        }
      }
    }

    setState(() {
      trailerUrl = null;
    });
  }

  void _initializePlayer() {
    if (trailerUrl == null) return;

    String? videoId = YoutubePlayer.convertUrlToId(trailerUrl!);
    if (videoId == null) return;

    setState(() {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: true,
        ),
      );
    });
  }

  @override
  void deactivate() {
    _controller?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  Future<void> fetchMovieDetails() async {
    final url = Uri.parse("http://api.themoviedb.org/3/movie/${widget.movie['id']}?api_key=${apiKey}");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          int runtime = data['runtime'];
          formattedRuntime = formatRuntime(runtime);
          productionCompany = (data['production_companies'] != null && data['production_companies'].isNotEmpty)
              ? data['production_companies'][0]['name']
              : "N/A";
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }
  String formatRuntime(int minutes) {
    if (minutes == 0) return "N/A";
    int hours = minutes ~/ 60;
    int mins = minutes % 60;
    return hours > 0 ? "$hours hour${hours > 1 ? 's' : ''} $mins min" : "$mins min";
  }

  Future<void> fetchCrewMembers(int movieId) async {
    final url = Uri.parse("http://api.themoviedb.org/3/movie/$movieId/credits?api_key=$apiKey");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          crewMembers = data['crew']
              .where((crew) => crew['job'] != "Director") // Exclude Directors
              .toList();
          isLoading = false;
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }


  Future<List<String>> getSpokenLanguages(int movieId) async {
    try {
      final url = "http://api.themoviedb.org/3/movie/$movieId?api_key=605177edc454a9d34b3d3f16d1cc8344";
      print("Fetching: $url"); // Debugging ke liye

      final response = await http.get(Uri.parse(url));

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List languages = data["spoken_languages"] ?? [];

        List<String> languageNames = languages.map((lang) => lang["name"].toString()).toList();

        print("Spoken Languages: $languageNames"); // Debugging ke liye
        return languageNames;
      } else {
        throw Exception("Failed to load movie detail: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");  // Console me error print hoga
      throw Exception("Failed to fetch spoken languages");
    }
  }

  Future<List<String>> fetchMovieGenres(int movieId) async {
    final String url =
        "http://api.themoviedb.org/3/movie/$movieId?api_key=$apiKey&language=en-US";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Ensure 'genres' exists and is a list
        if (data.containsKey('genres') && data['genres'] is List) {
          List<dynamic> genres = data['genres'];

          // Take only first 3 genres and map them to a List<String>
          return genres.take(3).map((genre) => genre['name'] as String).toList();
        }
        return []; // Return empty list if 'genres' is missing
      } else {
        throw Exception("Failed to load movie genres. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching movie genres: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster with Overlay
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.4,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5), // Shadow color
                        blurRadius: 10, // Softness of the shadow
                        spreadRadius: 2, // Spread of the shadow
                        offset: Offset(4, 4), // Shadow position
                      ),
                    ],
                    image: DecorationImage(
                      image: NetworkImage(
                        (widget.movie['backdrop_path'] != null && widget.movie['backdrop_path'].toString().isNotEmpty)
                            ? "http://image.tmdb.org/t/p/original/${widget.movie['backdrop_path']}"
                            : "http://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQHFfZsqDCHSjzfnxn6eaTRqiMCN8jLzak7Lg&s",
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),

                // Movie Title
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: EdgeInsets.symmetric(horizontal: 20), // Adds horizontal padding
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(Icons.add, "My List", Colors.white,widget.movie,context),
                            SizedBox(width: 15),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "${widget.movie['title']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        formattedRuntime != null ? "Duration : ($formattedRuntime)" : "Loading...",
                        style: TextStyle(fontSize: 19, color: Colors.white),
                      ),

                    ],
                  ),
                ),

                // Gradient Neon Border Icon


              ],
            ),

            // Movie Genres Section
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.movie['release_date'].substring(0, 4)
                      , style: TextStyle(color: Colors.grey.shade200, fontSize: 17),
                    ),
                    FutureBuilder<List<String>>(
                      future: _genresFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text("Error loading genres", style: TextStyle(color: Colors.red));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text("No genres found", style: TextStyle(color: Colors.white));
                        }

                        return Text(
                          " : ${snapshot.data!.join(", ")}",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 5,),
                Text("IMDB :⭐ ${widget.movie['vote_average']}",style: TextStyle(color: Colors.white,fontSize: 17,fontWeight: FontWeight.bold),),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, // Ensures proper alignment
                  children: [
                    Text(
                      "Production House: ",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(width: 5), // Use width instead of height for Row spacing
                    Flexible( // Ensures scrolling text doesn't overflow
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, // Allows horizontal scrolling
                        child: Text(
                          productionCompany,
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),

                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7), // Slightly transparent background
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpandableOverview(overview: widget.movie['overview'] ?? "No overview available."),

                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    children: [
                      Text(
                        "Spoken Lang:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Allow scrolling if needed
                          child: FutureBuilder<List<String>>(
                            future: _spokenFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: Shimmer.fromColors(
                                    baseColor: Colors.grey[800]!,
                                    highlightColor: Colors.grey[600]!,
                                    child: Container(
                                      width: 150,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    "Error: ${snapshot.error}",
                                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                                  ),
                                );
                              } else if (snapshot.hasData) {
                                return Wrap(
                                  children: snapshot.data!.map((lang) {
                                    return Container(
                                      margin: EdgeInsets.only(right: 8),
                                      child: Chip(
                                        label: Text(
                                          lang,
                                          style: TextStyle(fontSize: 16, color: Colors.white),
                                        ),
                                        backgroundColor: Colors.blueAccent,
                                      ),
                                    );
                                  }).toList(),
                                );
                              } else {
                                return Center(
                                  child: Text(
                                    "No Data Available",
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Divider(height: 2,color: Colors.white,),
                ),


              ],
            ),
            //casts details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10),
              child: Text('Casts',style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                fontWeight: FontWeight.bold
              ),),
            ),
            castSection(castList),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10),
              child: Text('Directer',style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold
              ),),
            ),
            Container(
              height: 170,
              child: director.isNotEmpty // Ensure director is not empty before building
                  ? ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: director.length, // Corrected
                itemBuilder: (context, index) {
                  return actorCard(
                    director[index]['image'].toString(),  // Ensure it's a string
                    director[index]['name'].toString(),director[index]['id'],"",director[index]['gender'].toString()
                  );
                },
              )
                  : Center(
                child: Text(
                  "No director found",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            buildCrewList(),
            AnimatedContainer(
              duration: Duration(microseconds: 300),
              height: 240, // Adjust height as per need
              child: MovieDetailPage(movieId: widget.movie['id']),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10),
              child: Text('Trailer',style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold
              ),),
            ),
            Column(
              children: [
                trailerUrl == null || _controller == null
                    ? Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[600]!,
                  child: Container(
                    margin: EdgeInsets.all(10),
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black,
                    ),
                  ),
                )
                    : YoutubePlayerBuilder(
                  player: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                  ),
                  builder: (context, player) {
                    return Container(
                      margin: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: player,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10,),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10),
              child: Text("What People Are Saying",style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold
              ),),
            ),
            MovieReviews(movieId: widget.movie['id'],),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10),
              child: Text('You also like this movie',style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold
              ),),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: getRecommendedMovies(widget.movie['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: SizedBox(
                      height: 250, // Match the movie list height
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: 5, // Show 5 shimmer placeholders
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey[800]!,
                              highlightColor: Colors.grey[600]!,
                              child: Container(
                                width: 150, // Placeholder size for movie cards
                                height: 250,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: Text(
                        "⚠️ Error loading movies",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: Text(
                        "No franchise movies found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                } else {
                  final movies = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: MovieCard(movie: movie,onTap: () {
                                _controller?.pause(); // ✅ Pause YouTube player
                              },),
                            );
                          },
                        ),
                      ),

                    ],
                  );
                }
              },
            ),
      ],
        ),
      ),
    );

  }
  Widget buildCrewList() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Crew Members",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          crewMembers.isEmpty
              ? Text("No Crew Members Available", style: TextStyle(color: Colors.grey))
              : SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: crewMembers.length,
              itemBuilder: (context, index) {
                final crew = crewMembers[index];
                return buildCrewCard(crew);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCrewCard(dynamic crew) {
    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            child: CachedNetworkImage(
              placeholder: (context, url) => Image.network(
                crew['gender'] == 1
                    ? "http://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Placeholder
                    : "http://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Placeholder
                width: 120,
                height: 100,
                fit: BoxFit.cover,
              ),
              imageUrl: crew['profile_path'] != null
                  ? "http://image.tmdb.org/t/p/w185${crew['profile_path']}"
                  : "http://via.placeholder.com/185", // Default placeholder if no image
              width: 120,
              height: 100,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Image.network(
                crew['gender'] == 1
                    ? "http://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Placeholder
                    : "http://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Placeholder
                width: 120,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),


          Padding(
            padding: EdgeInsets.all(6),
            child: Column(
              children: [
                Text(
                  crew['name'],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                  crew['job'],
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget castSection(List<Map<String, dynamic>> castList) {
    return Container(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: castList.length ?? 0,
        itemBuilder: (context, index) {
          return actorCard(castList[index]['image'],castList[index]['name'],castList[index]['id'],castList[index]['character'],castList[index]['gender']);
        },
      ),
    );
  }



  Widget actorCard(String actor, String name,int? id, [String character = "",String gender ='0']) {

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          if (id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CastDetailScreen(personId: id)),
            );
          }
        },
        child: Container(
          width: 100, // Set a fixed width to prevent overflow
          constraints: BoxConstraints(maxHeight: 180), // Prevent overflow
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.withOpacity(0.4), Colors.black.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                spreadRadius: 2,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevents overflow
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onTap: () {
                    print("Tapped on $name");
                  },
                  child: InkWell(
                    onTap: (){
                      if (id != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CastDetailScreen(personId: id)),
                        );
                      }
                    },
                    child: FadeInImage(
                      placeholder: NetworkImage(
                        gender == '1'
                            ? "http://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Error Image
                            : "http://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Error Image
                      ),
                      image: NetworkImage(
                        actor.isNotEmpty
                            ? actor
                            : "http://thumbs.dreamstime.com/b/person-gray-photo-placeholder-man-shirt-white-background-person-gray-photo-placeholder-man-136701243.jpg",
                      ),
                      height: 100, // Reduced height
                      width: 100,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        return Image.network(
                          gender == '1'
                              ? "http://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Error Image
                              : "http://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Error Image
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Flexible( // Ensures no text overflow
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis, // Prevents overflow
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              if (character.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2),
                  child: Text(
                    'as $character',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }


  Widget _buildActionButton(
      IconData icon,
      String label,
      Color iconColor,
      Map<String, dynamic> movie,
      BuildContext context) {
    return InkWell(
      onTap: () async {
        await _saveMovie(movie);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "$label clicked! '${movie['title']}' saved.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              spreadRadius: 2,
              offset: Offset(2, 3),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Function to save movie ID in SharedPreferences
  Future<void> _saveMovie(Map<String, dynamic> movie) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('saved_movies') ?? [];

    // Convert movie to JSON string
    String movieJson = jsonEncode(movie);

    // Check if movie already exists (based on 'id')
    bool alreadyExists = savedList.any((item) {
      final existingMovie = jsonDecode(item);
      return existingMovie['id'] == movie['id'];
    });

    if (!alreadyExists) {
      savedList.add(movieJson);
      await prefs.setStringList('saved_movies', savedList);
    }
  }


}
class ExpandableOverview extends StatefulWidget {
  final String overview;

  ExpandableOverview({required this.overview});

  @override
  _ExpandableOverviewState createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<ExpandableOverview> {
  bool isExpanded = false; // Track if text is expanded

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onDoubleTap: (){
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExpanded ? widget.overview : _getShortOverview(widget.overview),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? "View Less" : "View More",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to get first 3 lines of text
  String _getShortOverview(String text) {
    List<String> words = text.split(" ");
    if (words.length > 25) {
      return words.take(25).join(" ") + "..."; // Show first 25 words
    }
    return text; // If text is short, show full
  }
}


class StreamingPlatformsWidget extends StatefulWidget {
  final Map<String, List<Map<String, String>>> availablePlatforms;

  const StreamingPlatformsWidget({Key? key, required this.availablePlatforms}) : super(key: key);

  @override
  _StreamingPlatformsWidgetState createState() => _StreamingPlatformsWidgetState();
}

class _StreamingPlatformsWidgetState extends State<StreamingPlatformsWidget> {
  String? userCountryCode;
  List<Map<String, String>> userPlatforms = [];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("Location permission denied");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    String countryCode = await _getCountryCode(position);

    setState(() {
      userCountryCode = countryCode;
      userPlatforms = widget.availablePlatforms[countryCode] ?? [];
    });
  }

  Future<String> _getCountryCode(Position position) async {
    var locale = Intl.getCurrentLocale();
    return locale.split('_').last; // Extract country code (e.g., "IN" from "en_IN")
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text("📺 Available in ${userCountryCode ?? 'Unknown'}:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: userPlatforms.map((platform) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(platform['logo']!),
                    ),
                    const SizedBox(height: 4),
                    Text(platform['name']!, style: TextStyle(color: Colors.white)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class MovieCard extends StatelessWidget {
  final Map<String, dynamic> movie;
  final VoidCallback onTap; // ✅ Callback function for pausing video

  MovieCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap(); // ✅ Pause video when navigating
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: (movie['poster_path'] != null && movie['poster_path'].toString().isNotEmpty)
                    ? "http://image.tmdb.org/t/p/w200${movie['poster_path']}"
                    : "http://industrialbid.com/images/lot/0/0_xl.jpg?ts=1728057906",
                height: 180,
                width: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.network(
                  "http://industrialbid.com/images/lot/0/0_xl.jpg?ts=1728057906",
                  height: 180,
                  width: 150,
                  fit: BoxFit.cover,
                ),
                errorWidget: (context, url, error) => Image.network(
                  "http://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQYA8-qGTLi1IgFbY7XZHm0Fjd2qYUFBrvlZw&s",
                  height: 180,
                  width: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 5),
            Text(
              movie['title'] ?? "No Title",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              movie['release_date'] ?? "Unknown",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


class MovieReviews extends StatefulWidget {
  final int movieId;

  const MovieReviews({Key? key, required this.movieId}) : super(key: key);

  @override
  _MovieReviewsState createState() => _MovieReviewsState();
}

class _MovieReviewsState extends State<MovieReviews> {
  List<dynamic> reviews = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
    final String apiKey = '605177edc454a9d34b3d3f16d1cc8344';
    final String url = 'http://api.themoviedb.org/3/movie/${widget.movieId}/reviews?api_key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          reviews = data['results'];
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load reviews");
      }
    } catch (error) {
      print("Error fetching reviews: $error");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180, // Fixed height for horizontal scrolling
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : reviews.isEmpty
          ? Center(child: Text("No reviews found", style: TextStyle(color: Colors.white)))
          : ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          final review = reviews[index];
          return _buildReviewCard(context, review);
        },
      ),
    );

  }

  Widget _buildReviewCard(BuildContext context, dynamic review) {
    Color avatarColor = _getRandomColor(); // Assign a random color to the avatar

    return GestureDetector(
      onDoubleTap: () => _showFullReview(context, review), // Show full review on long press
      child: Container(
        width: 280,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), // Glassmorphism effect
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)), // Soft border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor,
                  child: Text(
                    review['author'][0].toUpperCase(), // First letter of name
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review['author'],
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Expanded(
              child: Text(
                review['content'],
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to get a random color for the avatar
  Color _getRandomColor() {
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.red, Colors.purple, Colors.orange, Colors.teal, Colors.amber
    ];
    return colors[Random().nextInt(colors.length)];
  }

  // Function to show full review in bottom sheet
  void _showFullReview(BuildContext context, dynamic review) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // Semi-transparent background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getRandomColor(),
                      child: Text(
                        review['author'][0].toUpperCase(),
                        style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        review['author'],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.white24),
                SizedBox(height: 10),
                Text(
                  review['content'],
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


