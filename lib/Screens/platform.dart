import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';



// 🎥 Movie Detail Page
class MovieDetailPage extends StatefulWidget {
  final int movieId;

  const MovieDetailPage({Key? key, required this.movieId}) : super(key: key);

  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  String? userCountry;
  List<Map<String, String>> platforms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadStreamingPlatforms();
    print('platform is ${platforms}');
  }

  Future<void> loadStreamingPlatforms() async {
    String? country = await getUserCountry();
    if (country != null) {
      List<Map<String, String>> data = await getAvailablePlatforms(widget.movieId, country);
      setState(() {
        userCountry = country;
        platforms = data;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.only(left: 16.0, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📺Where to Watch:",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),

            isLoading
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (index) => shimmerEffect()),
              ),
            )
                : platforms.isEmpty
                ? Text(
              "No streaming platforms available in your region.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: platforms.map((platform) {
                  bool isFree = platform['type'] == "Free";

                  return Container(
                    width: 120,
                    height: 160,
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isFree
                            ? [Colors.green.withOpacity(0.8), Colors.green.withOpacity(0.4)]
                            : [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            platform['logo']!,
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          platform['name']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFree ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFree ? "Free" : "Paid",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ✨ Shimmer Loading Effect
  Widget shimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[700]!,
      highlightColor: Colors.grey[500]!,
      child: Container(
        width: 120,
        height: 160,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

}

// 🌍 Get User's Country
Future<String?> getUserCountry() async {
  final response = await http.get(Uri.parse('http://ip-api.com/json/?fields=countryCode'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['countryCode']; // Returns country code like 'IN', 'US', 'UK'
  }

  return null;
}

// 🔍 Fetch Available Platforms from TMDB API
Future<List<Map<String, String>>> getAvailablePlatforms(int movieId, String country) async {
  const String apiKey = "605177edc454a9d34b3d3f16d1cc8344";
  String url = "http://api.themoviedb.org/3/movie/$movieId/watch/providers?api_key=$apiKey";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final results = data['results'];

    if (results != null && results.containsKey(country)) {
      Set<String> uniqueProviders = {};
      List<Map<String, String>> providerList = [];

      // Map to store provider type with priority
      Map<String, String> providerType = {};

      List<dynamic> providers = [];

      if (results[country].containsKey('flatrate')) {
        for (var provider in results[country]['flatrate']) {
          providerType.putIfAbsent(provider['provider_name'], () => "Free");
        }
        providers.addAll(results[country]['flatrate']);
      }
      if (results[country].containsKey('buy')) {
        for (var provider in results[country]['buy']) {
          providerType[provider['provider_name']] = "Paid";
        }
        providers.addAll(results[country]['buy']);
      }
      if (results[country].containsKey('rent')) {
        for (var provider in results[country]['rent']) {
          providerType[provider['provider_name']] = "Paid";
        }
        providers.addAll(results[country]['rent']);
      }

      for (var provider in providers) {
        String providerName = provider['provider_name'].toString();
        String logoUrl = "https://image.tmdb.org/t/p/w200${provider['logo_path']}";
        String type = providerType[providerName] ?? "Paid";

        if (!uniqueProviders.contains(providerName)) {
          uniqueProviders.add(providerName);
          providerList.add({
            "name": providerName,
            "logo": logoUrl,
            "type": type,
          });
        }
      }

      return providerList;
    }
  }

  return [];
}
