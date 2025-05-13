import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

class AnimeScreen extends StatefulWidget {
  final String animeId;
  const AnimeScreen({Key? key, required this.animeId}) : super(key: key);

  @override
  _AnimeScreenState createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  Map<String, dynamic>? animeData;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    fetchAnimeDetails();
  }

  List<dynamic> recommendedAnime = [];

  Future<void> fetchAnimeDetails() async {
    final url = Uri.parse("https://kitsu.io/api/edge/anime/${widget.animeId}");
    final recommendationUrl = Uri.parse("https://kitsu.io/api/edge/anime/${widget.animeId}/relationships/related-anime");

    try {
      final response = await http.get(url);
      final recommendationResponse = await http.get(recommendationUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          animeData = data["data"]["attributes"] ?? {};
          isLoading = false;
        });
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }

      if (recommendationResponse.statusCode == 200) {
        final recData = jsonDecode(recommendationResponse.body);
        setState(() {
          recommendedAnime = recData["data"] ?? [];
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: GestureDetector(
            onTap: (){
              Navigator.pop(context);
            },
            child: Icon(Icons.arrow_back_ios)),
      ),
      body: isLoading
          ? _buildShimmerEffect()
          : hasError
          ? _buildErrorWidget()
          : _buildAnimeDetails(),
    );
  }

  Widget _buildShimmerEffect() {
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[500]!,
        child: Column(
          children: [
            Container(height: 300, width: double.infinity, color: Colors.white),
            const SizedBox(height: 20),
            Container(height: 20, width: 200, color: Colors.white),
            const SizedBox(height: 10),
            Container(height: 15, width: 250, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Text("Error fetching anime details!", style: TextStyle(color: Colors.white)),
    );
  }


  Widget _buildAnimeDetails() {
    final String posterUrl = animeData?["coverImage"]?["original"] ?? "";
    final String animeTitle = animeData?["canonicalTitle"] ?? "Unknown Anime";
    final String synopsis = animeData?["synopsis"] ?? "No synopsis available.";

    return Stack(
      children: [
        // Background Poster with Parallax Effect
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
          ),
        ),

        // Glassmorphism Overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        ),

        // Content
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Poster
              Hero(
                tag: "anime_${widget.animeId}",
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 400,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain, // Ensure image fits without cropping
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[900]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                      ),
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 20),

              // Anime Title
              _buildTextSection(animeTitle, 28, FontWeight.bold),

              const SizedBox(height: 10),

              // Anime Details Row (Rating, Episodes, Popularity)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _infoBadge(Icons.star, animeData?["averageRating"] ?? "N/A", Colors.yellow),
                    const SizedBox(width: 10),
                    _infoBadge(Icons.tv, "${animeData?["episodeCount"] ?? "?"} Episodes", Colors.blueAccent),
                    const SizedBox(width: 10),
                    _infoBadge(Icons.trending_up, "Rank #${animeData?["popularityRank"] ?? "?"}", Colors.redAccent),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Synopsis Section
              _sectionTitle("Synopsis"),
              _buildTextSection(synopsis, 16, FontWeight.normal),

              const SizedBox(height: 20),

              // Extra Anime Details
              _sectionTitle("Details"),
              _detailRow("Status", animeData?["status"] ?? "Unknown"),
              _detailRow("Age Rating", animeData?["ageRating"] ?? "N/A"),
              _detailRow("Type", animeData?["showType"] ?? "N/A"),

              const SizedBox(height: 40),

              // Recommended Anime Section
              if (recommendedAnime.isNotEmpty) _buildRecommendedAnimeSection(),
            ],
          ),
        ),
      ],
    );
  }

// Helper Widget for Text Sections
  Widget _buildTextSection(String text, double fontSize, FontWeight weight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: TextStyle(fontSize: fontSize, fontWeight: weight, color: Colors.white),
      ),
    );
  }

// Recommended Anime Section
  Widget _buildRecommendedAnimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("You May Also Like"),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendedAnime.length,
            itemBuilder: (context, index) {
              final anime = recommendedAnime[index];
              final animeId = anime["id"];
              final animeTitle = anime["attributes"]["canonicalTitle"] ?? "Unknown";
              final animeImage = anime["attributes"]["posterImage"]["medium"] ?? "";

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AnimeScreen(animeId: animeId)),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(animeImage), fit: BoxFit.cover),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: Text(
                        animeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent.shade200)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Row(
        children: [
          Text('${label} =  ${value}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70)),

        ],
      ),
    );
  }
}
