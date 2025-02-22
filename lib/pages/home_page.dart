import 'dart:async';
// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:google_maps_in_flutter/services/mapbox_service.dart'; // Sửa đường dẫn import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription<gl.Position>? userPositionStream;
  final TextEditingController startLocationController = TextEditingController();
  final TextEditingController searchLocationController = TextEditingController();
  final MapboxService _mapboxService = MapboxService();

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    startLocationController.dispose();
    searchLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapbox Navigation')),
      body: Stack(
        children: [
          mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mp.MapboxStyles.MAPBOX_STREETS,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildTextField(searchLocationController, 'Search Location'),
                const SizedBox(height: 8),
                _buildTextField(startLocationController, 'Start Location'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _findRoute,
                  child: const Text('Find Route'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _moveToCurrentLocation,
                  child: const Text('Go to My Location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });

    mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );

    final pointAnnotationManager = await mapboxMapController?.annotations.createPointAnnotationManager();
    if (pointAnnotationManager != null) {
      final Uint8List imageData = await loadHQMarketImage();
      mp.PointAnnotationOptions pointAnnotationOptions = mp.PointAnnotationOptions(
        image: imageData,
        iconSize: 0.3,
        geometry: mp.Point(coordinates: mp.Position(-122.0312186, 37.33233141)),
      );
      pointAnnotationManager.create(pointAnnotationOptions);
    }
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    gl.LocationSettings locationSettings = const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (gl.Position? position) {
        if (position != null && mapboxMapController != null) {
          mapboxMapController?.setCamera(
            mp.CameraOptions(
              zoom: 15,
              center: mp.Point(
                coordinates: mp.Position(position.longitude, position.latitude),
              ),
            ),
          );
        }
      },
    );
  }

  Future<Uint8List> loadHQMarketImage() async {
    var byteData = await rootBundle.load("assets/icon/market.png");
    return byteData.buffer.asUint8List();
  }

  void _moveToCurrentLocation() async {
    gl.Position position = await gl.Geolocator.getCurrentPosition();
    if (mapboxMapController != null) {
      mapboxMapController?.setCamera(
        mp.CameraOptions(
          zoom: 15,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
      );
    }
  }

  void _findRoute() async {
    String startLocation = startLocationController.text;
    String endLocation = searchLocationController.text;

    if (startLocation.isEmpty || endLocation.isEmpty) return;

    List<Map<String, dynamic>> startResults = await _mapboxService.searchLocation(startLocation);
    List<Map<String, dynamic>> endResults = await _mapboxService.searchLocation(endLocation);

    if (startResults.isNotEmpty && endResults.isNotEmpty) {
      double startLng = startResults.first['longitude'];
      double startLat = startResults.first['latitude'];
      double endLng = endResults.first['longitude'];
      double endLat = endResults.first['latitude'];

      List<List<double>> routeCoordinates = await _mapboxService.getRoute(startLng, startLat, endLng, endLat);

    }
  }
}
