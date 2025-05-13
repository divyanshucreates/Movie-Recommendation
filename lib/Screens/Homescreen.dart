import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movies/Screens/movie_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:movies/Models/tmdb_service.dart';
import 'package:movies/Screens/design.dart';
import 'package:movies/Screens/search.dart';
import 'package:movies/Screens/genres.dart';
import 'package:movies/Screens/watchlist.dart';

const String apiKey = '605177edc454a9d34b3d3f16d1cc8344';
const String baseUrl = 'https://api.themoviedb.org/3';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system, // Use system theme
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        // Define other light mode settings here
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        // Define other dark mode settings here
      ),
      home: const Homescreen(),
    );
  }
}
class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();

}

class _HomescreenState extends State<Homescreen> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;

  List popularMovies = [];
  List trendingMovies = [];
  List topRatedMovies = [];
  List upcomingMovies = [];
  List kidsMovies = [];
  List animeMovies = [];
  List teenMovies = [];
  List adultMovies = [];
  bool isLoading = true;
  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
    _fetchAllData();
  }

  void _startAutoSlide() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && popularMovies.isNotEmpty) {
        _currentPage = (_currentPage + 1) % popularMovies.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);

    final List<Future<void>> fetchTasks = [
      _fetchCategory('popular'),
      _fetchCategory('trending'),
      _fetchCategory('topRated'),
      _fetchCategory('upcoming'),
      _fetchCategory('kids'),
      _fetchCategory('anime'),
      _fetchCategory('teen'),
      _fetchCategory('adult'),
    ];

    await Future.wait(fetchTasks);
    setState(() => isLoading = false);
  }

  Future<void> _fetchCategory(String category) async {
    try {
      final service = TMDBService();

      switch (category) {
        case 'popular':
          popularMovies = await service.fetchPopularMovies();
          break;
        case 'trending':
          trendingMovies = await service.getTrendingMovies();
          break;
        case 'topRated':
          topRatedMovies = await service.fetchTopRatedMovies();
          break;
        case 'upcoming':
          upcomingMovies = await service.fetchUpcomingMovies();
          break;
        case 'kids':
          kidsMovies = await service.fetchKidsMovies();
          break;
        case 'anime':
          animeMovies = await service.fetchAnimatedMovies();
          break;
        case 'teen':
          teenMovies = await service.fetchTeenMovies();
          break;
        case 'adult':
          adultMovies = await service.fetchAdultMovies();
          break;
        default:
          print('Unknown category: $category');
      }
    } catch (e) {
      print("Error fetching $category movies: $e");
    }
  }

  Widget buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget buildMovieSection(String title, List movies, bool isdark, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isdark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieSlider(movies: movies),
                    ),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: isLoading
              ? ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (_, __) => buildShimmerItem(),
          )
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final imageUrl =
                  'https://image.tmdb.org/t/p/w500${movie['poster_path']}';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailsScreen(movie: movie),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isdark ? Colors.grey[850] : Colors.white, // Adjust for dark mode
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: isdark ? Colors.black54 : Colors.black12,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              height: 140,
                              width: 120,
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie['title'] ?? 'No Title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isdark ? Colors.white : Colors.black, // Adjust text color
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
    );
  }


  Widget buildCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: isLoading
              ? Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 250,
              decoration: const BoxDecoration(color: Colors.white),
            ),
          )
              : PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: popularMovies.length,
            itemBuilder: (context, index) {
              final movie = popularMovies[index];
              final imageUrl =
                  'https://image.tmdb.org/t/p/w500${movie['backdrop_path']}';
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MovieDetailsScreen(movie: movie),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Text(
                      movie['title'] ?? 'No Title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 6, color: Colors.black)
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (!isLoading) buildDotIndicator(), // 👈 Show only when data is loaded
      ],
    );
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homescreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  SearchScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  GenreScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  WatchlistScreen()),
        );
        break;
    }
  }
  Widget buildDotIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          popularMovies.length,
              (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.deepPurple : Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
                    : [],
              ),
            );
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Check if the system theme is dark or light
    final brightness = MediaQuery.of(context).platformBrightness;

    // Determine if dark mode is enabled
    bool isDarkMode = brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: ListView(
          children: [
            buildCarousel(),
            buildMovieSection("Trending Now", trendingMovies,isDarkMode,isLoading),
            buildMovieSection("Top Rated", topRatedMovies,isDarkMode,isLoading),
            buildMovieSection("Upcoming Movies", upcomingMovies,isDarkMode,isLoading),
            buildMovieSection("Kids Friendly", kidsMovies,isDarkMode,isLoading),
            buildMovieSection("Popular Picks", popularMovies,isDarkMode,isLoading),
            buildMovieSection("Anime Movies", animeMovies,isDarkMode,isLoading),
            buildMovieSection("Teen Movies", teenMovies,isDarkMode,isLoading),
            buildMovieSection("Adult Movies", adultMovies,isDarkMode,isLoading),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
                icon: Icon(Icons.category), label: 'Genres'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bookmark), label: 'Watchlist'),
          ],
        ),
      ),
    );
  }
}
