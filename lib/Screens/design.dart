import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_detail_screen.dart';
import 'dart:math';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MovieSlider extends StatefulWidget {
  final List movies;

  const MovieSlider({super.key, required this.movies});

  @override
  State<MovieSlider> createState() => MovieSliderState();
}

class MovieSliderState extends State<MovieSlider>
    with TickerProviderStateMixin {
  // 🔥 Adjust viewport fraction for side visibility
  late PageController _pageController;
  double _currentPage = 0.0;
  int? currentindex;
  YoutubePlayerController? _controller;
  final String apiKey = "605177edc454a9d34b3d3f16d1cc8344";
  final String baseUrl = "https://api.themoviedb.org/3";
  String? trailerUrl;
  bool _isExpanded = false;
  List<Map<String, dynamic>> castList = [];
  List<Map<String, dynamic>> director = [];
  late Future<List<String>> _genresFuture;
  late AnimationController _controller1;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      _controller!.play();
    });

    if (widget.movies.isNotEmpty) {
      currentindex = 0;
      _pageController = PageController(viewportFraction: 0.8);
      _genresFuture = fetchMovieGenres(widget.movies[currentindex!]['id']);
      fetchDirector(widget.movies[currentindex!]['id']);
      fetchCast(widget.movies[currentindex!]['id']);
      getMovieTrailer(widget.movies[currentindex!]['id']);

      // ✅ Initialize Animation Controller
      _controller1 = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );

      // ✅ Slide Animation (From Bottom)
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), // Start from bottom
        end: Offset.zero, // End at original position
      ).animate(CurvedAnimation(
        parent: _controller1,
        curve: Curves.easeOutCubic,
      ));

      // ✅ Opacity Animation
      _opacityAnimation = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(
        parent: _controller1,
        curve: Curves.easeIn,
      ));
    }
  }


  void showBottomSheet(movie) {


    // ✅ Start Animation
    _controller1.forward();

    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            _controller1.reverse(); // ✅ Reverse animation on close
            await Future.delayed(const Duration(milliseconds: 300));
            return true;
          },
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
              parent: _controller1,
              curve: Curves.easeOut,
            )),
            child: SlideTransition(
              position: _slideAnimation, // ✅ Slide Animation
              child: FadeTransition(
                opacity: _opacityAnimation, // ✅ Fade Animation
                child: DraggableScrollableSheet(
                  initialChildSize: 0.45,
                  maxChildSize: 0.9,
                  minChildSize: 0.3,
                  expand: false,
                  builder: (_, controller) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: controller,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 158.0),
                              child: Divider(
                                color: Colors.grey,
                                thickness: 7,
                              ),
                            ),
                            const SizedBox(height: 10,),
                            if (_controller != null)
                              YoutubePlayer(
                                controller: _controller!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: Colors.red,
                                onReady: () {
                                  _controller!
                                      .play(); // ✅ Start Playing Automatically
                                },
                              ),
                            // ✅ Title
                            Center(
                              child: Text(
                                movie['title'] ?? "No Title",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ✅ Genres
                            Center(
                              child: FutureBuilder<List<String>>(
                                future: _genresFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    return const Text(
                                      "Error loading genres",
                                      style: TextStyle(color: Colors.red),
                                    );
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Text(
                                      "No genres found",
                                      style: TextStyle(color: Colors.grey),
                                    );
                                  }

                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: snapshot.data!.map((genre) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blueGrey.withOpacity(0.8),
                                              Colors.black.withOpacity(0.9),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                              offset: const Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          genre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ✅ Rating + Votes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.yellow, size: 22),
                                Text(
                                  "${(movie['vote_average'] ?? 0).toStringAsFixed(1)}/10",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${movie['vote_count'] ?? 0} votes",
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Director:",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  director.isNotEmpty
                                      ? director[0]['name']
                                      : "Unknown",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Text(
                              'Cast',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            castList.isNotEmpty
                                ? SizedBox(
                                    height: 150,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: castList.length,
                                      itemBuilder: (context, index) {
                                        var cast = castList[index];
                                        return Container(
                                          width: 100,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blueGrey
                                                    .withOpacity(0.4),
                                                Colors.black.withOpacity(0.7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: FadeInImage(
                                                  placeholder: NetworkImage(
                                                    cast['gender'] == '1'
                                                        ? "https://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Error Image
                                                        : "https://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Error Image
                                                  ),
                                                  image: NetworkImage(
                                                    cast['image'].isNotEmpty
                                                        ? cast['image']
                                                        : "https://thumbs.dreamstime.com/b/person-gray-photo-placeholder-man-shirt-white-background-person-gray-photo-placeholder-man-136701243.jpg",
                                                  ),
                                                  height: 100, // Reduced height
                                                  width: 100,
                                                  fit: BoxFit.cover,
                                                  imageErrorBuilder: (context,
                                                      error, stackTrace) {
                                                    return Image.network(
                                                      cast['gender'] == '1'
                                                          ? "https://st4.depositphotos.com/9998432/23754/v/1600/depositphotos_237542156-stock-illustration-person-gray-photo-placeholder-woman.jpg" // Female Error Image
                                                          : "https://media.istockphoto.com/id/986668942/vector/default-placeholder-businessman-half-length-portr.jpg?s=612x612&w=0&k=20&c=YMiEy6-gHQ9Pxn2y3jqxkoyzMyaLqzf9s-eYCIi8kMI=", // Male/Unknown Error Image
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                cast['name'] ?? "Unknown",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : const Text(
                                    "No cast available",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              'Introduction',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // ✅ Overview
                            Text(
                              movie['overview'] ?? "No overview available.",
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.8),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ✅ Trailer
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _controller1.reverse(); // ✅ Reverse animation on close
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
    _pageController.dispose();
    super.dispose();
  }

  Future<List<String>> fetchMovieGenres(int movieId) async {
    final String url =
        "https://api.themoviedb.org/3/movie/$movieId?api_key=$apiKey&language=en-US";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Ensure 'genres' exists and is a list
        if (data.containsKey('genres') && data['genres'] is List) {
          List<dynamic> genres = data['genres'];

          // Take only first 3 genres and map them to a List<String>
          return genres
              .take(3)
              .map((genre) => genre['name'] as String)
              .toList();
        }
        return []; // Return empty list if 'genres' is missing
      } else {
        throw Exception(
            "Failed to load movie genres. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching movie genres: $e");
    }
  }

  Future<void> fetchCast(int movieId) async {
    final String url =
        "https://api.themoviedb.org/3/movie/${movieId}/credits?api_key=$apiKey";

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
        "https://api.themoviedb.org/3/movie/${movieId}/credits?api_key=$apiKey";

    print("Fetching director from: $url"); // Debugging API URL

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print("API Response: $data"); // Debugging API Response

      if (data.containsKey('crew')) {
        List<dynamic> crew = data['crew'];

        // Extract all directors
        List<Map<String, dynamic>> directorsList = crew
            .where(
                (person) => person['job'] == "Director") // Filter all directors
            .map((directorData) => {
                  "name": directorData['name'] ?? "Unknown",
                  "id": directorData['id'] ?? 0,
                  "gender": directorData['gender'].toString() ?? "0",
                  "image": directorData['profile_path'] != null
                      ? "https://image.tmdb.org/t/p/w200${directorData['profile_path']}"
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
      print(
          "Failed to load director data. Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}"); // Debugging Error Message
    }
  }

  Future<void> _initializePlayer() async {
    if (trailerUrl == null) return;

    String? videoId = YoutubePlayer.convertUrlToId(trailerUrl!);
    if (videoId == null) return;

    if (mounted) {
      setState(() {
        _controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            showLiveFullscreenButton: false,
            hideControls: true, // ✅ Controls ko remove karta hai
            controlsVisibleAtStart: false, // ✅ Start pe controls na dikhaye
            disableDragSeek: true, // ✅ Seek ko disable karne ke liye
          ),
        );
      });
    }
  }

  Future<void> getMovieTrailer(int movieId) async {
    String url = "$baseUrl/movie/$movieId/videos?api_key=$apiKey";
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List videos = data['results'];

        if (videos.isNotEmpty) {
          final trailer = videos.firstWhere(
            (video) => video['type'] == "Trailer" && video['site'] == "YouTube",
            orElse: () => null, // ✅ Return null instead of empty map
          );

          if (trailer != null && mounted) {
            setState(() {
              trailerUrl = "https://www.youtube.com/watch?v=${trailer['key']}";
            });
            await _initializePlayer(); // ✅ Player ko initialize karo
          }
        }
      }
    } catch (e) {
      print("Error fetching trailer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.movies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ✅ Background Image
                Positioned.fill(
                  child: Image.network(
                    "https://image.tmdb.org/t/p/original/${widget.movies[currentindex!]['backdrop_path'] ?? widget.movies[currentindex!]['poster_path']}",
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.red, size: 50),
                      );
                    },
                  ),
                ),


                // ✅ Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ✅ Movie Details
                if (!_isExpanded)
                  Positioned(
                    top: 60,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Title
                        Text(
                          widget.movies[currentindex!]['title'] ?? "No Title",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ✅ Genres + Language
                        Row(
                          children: [
                            if (widget.movies[currentindex!]['release_date'] !=
                                null)
                              _buildTag(widget.movies[currentindex!]
                                      ['release_date']!
                                  .substring(0, 4)),
                            _buildTag(widget.movies[currentindex!]
                                    ['original_language'] ??
                                'N/A'),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ✅ Rating + Votes
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.yellow, size: 22),
                            Text(
                              "${(widget.movies[currentindex!]['vote_average'] ?? 0).toStringAsFixed(1)}/10",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "  ${widget.movies[currentindex!]['vote_count'] ?? 0} votes",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showTrailer(),
                              child: Row(
                                children: [
                                  const Icon(Icons.play_circle_outline,
                                      color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Watch Trailer",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                // ✅ PageView for Movie Scrolling
                Positioned(
                  top: _isExpanded ? -130 : 150,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.movies.length,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            currentindex = index;
                            _currentPage = index.toDouble();

                            // ✅ Reset data when changing movie
                            castList = [];
                            director = [];
                            trailerUrl = null;

                            // ✅ Fetch new data
                            getMovieTrailer(widget.movies[index]['id']);
                            fetchDirector(widget.movies[index]['id']);
                            fetchMovieGenres(widget.movies[index]['id']);
                            fetchCast(widget.movies[index]['id']);
                            _genresFuture =
                                fetchMovieGenres(widget.movies[index]['id']);
                          });
                        },
                        itemBuilder: (context, index) {
                          String imageUrl = widget.movies[index]
                                      ['poster_path'] !=
                                  null
                              ? "https://image.tmdb.org/t/p/w500/${widget.movies[index]['poster_path']}"
                              : "https://via.placeholder.com/800x450?text=No+Image";

                          // ✅ Direct calculation of value and yOffset
                          double value =
                              (index.toDouble() - _currentPage).clamp(-3, 2);
                          double yOffset = (_currentPage - index).abs() * 70;

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Transform.translate(
                              offset: Offset(0, yOffset),
                              child: Transform.rotate(
                                angle: value * pi * 0.04,
                                child: InkWell(
                                  onTap: () {
                                    showBottomSheet(widget.movies[index]);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 15),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.55,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.55,
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: Icon(Icons.broken_image,
                                                  color: Colors.white,
                                                  size: 50),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -40), // ✅ Yaha value adjust karke height change karo
                    child: InkWell(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: widget.movies[currentindex!],)));
                      },
                      child: Container(
                        width: 150,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.blue,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8.0,horizontal: 30),
                        child:  Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.info,color: Colors.white,),
                            Text('Detail',style: TextStyle(fontSize: 21,color: Colors.white),),
                          ],
                        ),
                      ),
                    ),
                  ),
                )



              ],
            ),
    );
  }

  // ✅ Helper to build tag
  Widget _buildTag(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }

  // ✅ Fetch Trailer from TMDB API

  // ✅ Show Trailer in Dialog
  void _showTrailer() {
    if (_controller == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // ✅ Rounded Corners
          ),
          title: const Text(
            'No Trailer Available',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.7),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // ✅ Rounded Corners
          ),
          contentPadding: EdgeInsets.zero, // ✅ Remove default padding
          content: Stack(
            alignment: Alignment.topRight,
            children: [
              // ✅ Increased Width and Height
              SizedBox(
                width: MediaQuery.of(context).size.width, // 90% of screen width
                height: MediaQuery.of(context).size.height *
                    0.2, // 50% of screen height
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.red,
                    onReady: () {
                      _controller!.play(); // ✅ Start Playing Automatically
                    },
                  ),
                ),
              ),

              // ✅ Close Button (Top Right Corner)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
