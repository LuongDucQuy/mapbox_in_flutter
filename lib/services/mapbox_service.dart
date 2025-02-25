
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MapboxService {
  final String _accessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"]!;

  // Tìm kiếm địa điểm
  Future<List<dynamic>> searchPlaces(String query) async {
    final String url =
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json"
        "?access_token=$_accessToken"
        "&types=poi,address,place,locality,neighborhood,postcode,district,region"
        "&limit=5"
        "&language=vi"
        "&country=VN";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Toa do' + data.toString());
      return data['features'];
    } else {
      throw Exception('Lỗi khi tìm kiếm địa điểm');
    }
  }

  // 🛣️ Lấy tuyến đường từ vị trí A đến B
  Future<Map<String, dynamic>> getRoute(double startLng, double startLat,
      double endLng, double endLat, String mode) async {
    final String url =
        "https://api.mapbox.com/directions/v5/mapbox/$mode/"
        "$startLng,$startLat;$endLng,$endLat"
        "?alternatives=false"
        "&geometries=geojson"
        "&steps=false"
        "&access_token=$_accessToken";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<List<double>> routeCoords = [];

      for (var point in data['routes'][0]['geometry']['coordinates']) {
        routeCoords.add([point[0], point[1]]);
      }

      double duration = data['routes'][0]['duration'] / 60; // Giây → Phút
      double distance = data['routes'][0]['distance'] / 1000; // Mét → Km

      return {
        "route": routeCoords,
        "duration": duration,
        "distance": distance,
      };
    } else {
      throw Exception('Lỗi khi lấy tuyến đường');
    }
  }
}