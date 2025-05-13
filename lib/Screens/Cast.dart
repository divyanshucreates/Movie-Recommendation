import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movies/Screens/movie_detail_screen.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';


const String apiKey = "605177edc454a9d34b3d3f16d1cc8344";

class CastDetailScreen extends StatefulWidget {
  final int personId;
  const CastDetailScreen({Key? key, required this.personId}) : super(key: key);

  @override
  _CastDetailScreenState createState() => _CastDetailScreenState();
}

class _CastDetailScreenState extends State<CastDetailScreen> {
  Map<String, dynamic>? castDetails;
  List<dynamic> movieCredits = [];
  Map<String, dynamic>?socialMedia;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCastDetails(widget.personId);
  }

  Future<void> fetchCastDetails(int personId) async {
    try {
      final personUrl = "http://api.themoviedb.org/3/person/$personId?api_key=$apiKey";
      final movieCreditsUrl = "http://api.themoviedb.org/3/person/$personId/movie_credits?api_key=$apiKey";
      final socialMediaUrl = "http://api.themoviedb.org/3/person/$personId/external_ids?api_key=$apiKey";

      final personResponse = await http.get(Uri.parse(personUrl));
      final movieResponse = await http.get(Uri.parse(movieCreditsUrl));
      final socialResponse = await http.get(Uri.parse(socialMediaUrl));

      if (personResponse.statusCode == 200 && movieResponse.statusCode == 200 && socialResponse.statusCode == 200) {
        final personData = json.decode(personResponse.body);
        final movieData = json.decode(movieResponse.body);
        final socialData = json.decode(socialResponse.body);

        if (personData['birthday'] != null && personData['birthday'].isNotEmpty) {
          DateTime birthDate = DateTime.parse(personData['birthday']);
          personData['formatted_birthday'] = DateFormat('dd/MM/yyyy').format(birthDate); // Ensure proper format
        } else {
          personData['formatted_birthday'] = "N/A";
        }




        // Sorting movies by year (latest first)
        List<dynamic> sortedMovies = movieData['cast'];
        sortedMovies.sort((a, b) {
          String? dateA = a['release_date']; // Extract release date
          String? dateB = b['release_date'];

          if (dateA == null || dateA.isEmpty) return 1;
          if (dateB == null || dateB.isEmpty) return -1;

          return DateTime.parse(dateB).compareTo(DateTime.parse(dateA)); // Sort by latest first
        });

        // Format movie release dates
        for (var movie in sortedMovies) {
          if (movie['release_date'] != null && movie['release_date'].isNotEmpty) {
            DateTime releaseDate = DateTime.parse(movie['release_date']);
            movie['release_date'] = DateFormat('dd/MM/yyyy').format(releaseDate);
          }
        }

        setState(() {
          castDetails = personData;
          movieCredits = sortedMovies;
          socialMedia = socialData;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to fetch data");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty || birthDate == "N/A") return 0; // Handle null case

    try {
      print("Birth Date Received: $birthDate"); // Debugging line

      DateTime birthDateTime = DateFormat('dd/MM/yyyy').parse(birthDate);
      DateTime today = DateTime.now();
      int age = today.year - birthDateTime.year;

      if (today.month < birthDateTime.month ||
          (today.month == birthDateTime.month && today.day < birthDateTime.day)) {
        age--;
      }

      print("Calculated Age: $age"); // Debugging line
      return age;
    } catch (e) {
      print("Error in _calculateAge: $e");
      return 0; // Default value on error
    }
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print("Could not open URL: $url");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.black,
        title: Text(
          castDetails?['name'] ?? "Actor Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 3,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (castDetails?['profile_path'] != null)
                Center(
                  child: ThreeDEffectAvatar(
                    imageUrl: "http://image.tmdb.org/t/p/w300${castDetails!['profile_path']}",
                    tag: "actor_${castDetails!['id']}",

                  ),
                ),
              SizedBox(height: 16),
              _buildGlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      castDetails?['name'] ?? "Unknown",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(Icons.cake, "Born: ${castDetails?['formatted_birthday'] ?? 'Unknown'}"),
                    _buildDetailRow(Icons.location_on, "Place: ${castDetails?['place_of_birth'] ?? 'Unknown'}"),
                    _buildDetailRow(Icons.favorite, "Marital Status: ${castDetails?['marital_status'] ?? 'Unknown'}"),
                    SizedBox(height: 16),
                    Text("Biography:", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 6),
                    ExpandableOverview(overview: castDetails?['biography'] ?? "No biography available."),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildSocialButtons(),
              SizedBox(height: 20),
              Text("Movies:", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              _buildMovieList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildSocialIcon(
          "http://img.freepik.com/free-vector/new-2023-twitter-logo-x-icon-design_1017-45418.jpg",
          "http://twitter.com/${socialMedia?['twitter_id']}",
        ),
        _buildSocialIcon(
          "http://upload.wikimedia.org/wikipedia/commons/a/a5/Instagram_icon.png",
          "http://instagram.com/${socialMedia?['instagram_id']}",
        ),
        _buildSocialIcon(
          "http://upload.wikimedia.org/wikipedia/commons/0/05/Facebook_Logo_%282019%29.png",
          "http://facebook.com/${socialMedia?['facebook_id']}",
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String imageUrl, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: () => _launchURL(url),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withOpacity(0.2),
          child: ClipOval(
            child: Image.network(imageUrl, fit: BoxFit.cover, width: 35, height: 35),
          ),
        ),
      ),
    );
  }

  Widget _buildMovieList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: movieCredits.length,
      itemBuilder: (context, index) {
        final movie = movieCredits[index];
        return Card(
          color: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Hero(
              tag: "movie_${movie['id']}",
              child: movie["poster_path"] != null
                  ? Image.network("http://image.tmdb.org/t/p/w92${movie["poster_path"]}", width: 50)
                  : Icon(Icons.movie, size: 50, color: Colors.white),
            ),
            title: Text(movie["title"], style: TextStyle(color: Colors.white)),
            subtitle: Text("Release Date: ${movie["release_date"] ?? 'Unknown'}", style: TextStyle(color: Colors.white70)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
            ),
          ),
        );
      },
    );
  }
}


class ThreeDEffectAvatar extends StatelessWidget {
  final String imageUrl;
  final String tag;

  ThreeDEffectAvatar({required this.imageUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: tag,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Blur for Depth Effect
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            // Outer Shadow for 3D Effect
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    spreadRadius: 8,
                    blurRadius: 15,
                    offset: Offset(6, 6),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    spreadRadius: -2,
                    blurRadius: 8,
                    offset: Offset(-3, -3),
                  ),
                ],
              ),
            ),
            // Image inside the Circular Frame (Full Fit)
            ClipOval(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover, // Image will fully cover the circle
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
