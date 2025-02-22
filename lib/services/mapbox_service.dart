import 'dart:convert';
import 'package:http/http.dart' as http;

class MapboxService {
  static const String _apiKey = "pk.eyJ1IjoiZGF0MTUxMCIsImEiOiJjbTc4d3Rma3cwMTJyMnFvbGE4aGNsam5kIn0.2dAqovqd9va216DchFb4QQ";
  static const String _baseUrl = "https://api.mapbox.com";

  /// Gợi ý địa điểm dựa trên từ khóa nhập vào
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    final url = Uri.parse(
      "$_baseUrl/geocoding/v5/mapbox.places/$query.json?access_token=$_apiKey&autocomplete=true&limit=5",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['features'] as List)
          .map((place) => {
        "name": place['place_name'],
        "longitude": place['geometry']['coordinates'][0],
        "latitude": place['geometry']['coordinates'][1],
      })
          .toList();
    } else {
      throw Exception("Failed to fetch locations");
    }
  }

  /// Tìm đường đi giữa hai vị trí (start và end)
  Future<List<List<double>>> getRoute(
      double startLng, double startLat, double endLng, double endLat) async {
    final url = Uri.parse(
      "$_baseUrl/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson&access_token=$_apiKey",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['routes'][0]['geometry']['coordinates'] as List)
          .map<List<double>>(
              (coord) => [coord[0].toDouble(), coord[1].toDouble()]) // Ép kiểu
          .toList();
    } else {
      throw Exception("Failed to fetch route");
    }
  }
}
