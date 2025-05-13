import 'package:http/http.dart' as http;
import 'dart:convert';

class TMDBService {
  final String apiKey = '605177edc454a9d34b3d3f16d1cc8344';
  final String baseUrl = 'http://api.themoviedb.org/3';

  // 🔹 Generic GET request
  Future<Map<String, dynamic>> _getJson(Uri url) async {
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("HTTP Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("Exception during API call: $e");
    }
    return {};
  }

  // 🔹 Generic Movie Fetcher
  Future<List<dynamic>> fetchMovies(String category) async {
    final url = Uri.parse('$baseUrl/movie/$category?api_key=$apiKey&sort_by=release_date.desc');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    final url = Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=$query');
    final data = await _getJson(url);
    return List<Map<String, dynamic>>.from(data['results'] ?? []);
  }

  Future<String?> getUserCountry() async {
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json/?fields=countryCode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['countryCode'];
      }
    } catch (e) {
      print("Error fetching country: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    final url = Uri.parse('$baseUrl/trending/movie/week?api_key=$apiKey');
    final data = await _getJson(url);
    List<Map<String, dynamic>> movies = List<Map<String, dynamic>>.from(data['results'] ?? []);

    String? userCountry = await getUserCountry();

    movies.sort((a, b) {
      bool aMatch = a['origin_country']?.contains(userCountry) ?? false;
      bool bMatch = b['origin_country']?.contains(userCountry) ?? false;

      if (aMatch && !bMatch) return -1;
      if (!aMatch && bMatch) return 1;
      return 0;
    });

    return movies;
  }

  // 🔹 Category Specific Movie Fetchers
  Future<List> fetchPopularMovies() => fetchMovies('popular');
  Future<List> fetchUpcomingMovies() => fetchMovies('upcoming');
  Future<List> fetchTopRatedMovies() => fetchMovies('top_rated');

  // 🔹 Language Based
  Future<List> fetchLanguageMovies(String langCode) async {
    final url = Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&with_original_language=$langCode');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List> fetchBollywoodMovies() => fetchLanguageMovies('hi');
  Future<List> fetchHollywoodMovies() => fetchLanguageMovies('en');
  Future<List> fetchTollywoodMovies() => fetchLanguageMovies('te');
  Future<List> fetchPunjabiMovies() => fetchLanguageMovies('pa');
  Future<List> fetchMarathiMovies() => fetchLanguageMovies('mr');
  Future<List> fetchKoreanMovies() => fetchLanguageMovies('ko');

  // 🔹 Platform Based
  Future<List> fetchPlatformMovies(int providerId) async {
    final url = Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&with_watch_providers=$providerId&watch_region=IN');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List> fetchNetflixMovies() => fetchPlatformMovies(8);
  Future<List> fetchPrimeMovies() => fetchPlatformMovies(9);
  Future<List> fetchDisneyMovies() => fetchPlatformMovies(337);

  // 🔹 Genre Based
  Future<List> fetchGenreMovies(int genreId, {int page = 1}) async {
    final url = Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&with_genres=$genreId&page=$page');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List> fetchBiographyMovies() => fetchGenreMovies(22);
  Future<List> fetchKidsMovies() => fetchGenreMovies(10751);
  Future<List> fetchTeenMovies() => fetchGenreMovies(80);
  Future<List> fetchAdultMovies() => fetchGenreMovies(18);
  Future<List> fetchAnimatedMovies() => fetchGenreMovies(16);

  Future<List<Map<String, dynamic>>> fetchAvengerMovies() async {
    List<Map<String, dynamic>> allMovies = [];
    for (int page = 1; page <= 3; page++) {
      final url = Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&with_companies=420&page=$page&sort_by=popularity.desc');
      final data = await _getJson(url);
      allMovies.addAll(List<Map<String, dynamic>>.from(data['results'] ?? []));
    }
    return allMovies;
  }

  // 🔹 Anime
  Future<List<Map<String, dynamic>>> fetchTrendingAnime() async {
    final url = Uri.parse('http://kitsu.io/api/edge/anime?page[limit]=20&sort=-averageRating');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    }
    return [];
  }

  // 🔹 TV Shows
  Future<List> fetchTVShows(String category) async {
    final url = Uri.parse('$baseUrl/tv/$category?api_key=$apiKey');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List> fetchTrendingTVShows() async {
    final url = Uri.parse('$baseUrl/trending/tv/week?api_key=$apiKey');
    final data = await _getJson(url);
    return data['results'] ?? [];
  }

  Future<List> fetchTopRatedTVShows() => fetchTVShows('top_rated');
  Future<List> fetchNetflixTVShows() => fetchPlatformMovies(8);
  Future<List> fetchPrimeTVShows() => fetchPlatformMovies(9);
  Future<List> fetchDisneyTVShows() => fetchPlatformMovies(337);

  // 🔹 YouTube Trailer
  Future<String?> getTrailer(String movieId) async {
    final url = Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey');
    final data = await _getJson(url);
    final results = data['results'];

    if (results != null && results.isNotEmpty) {
      final trailer = results.firstWhere(
            (video) => video['site'] == 'YouTube' && video['type'] == 'Trailer',
        orElse: () => results[0],
      );
      return trailer['key'];
    }
    return null;
  }
}
