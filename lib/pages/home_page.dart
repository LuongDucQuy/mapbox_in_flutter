import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import '../services/mapbox_service.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapboxService _mapboxService = MapboxService();
  mapbox.MapboxMap? _mapboxMapController;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;

  List<List<double>>? _routeCoords;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<dynamic> _startResults = [];
  List<dynamic> _endResults = [];
  List<double>? _startPoint;
  List<double>? _endPoint;

  mapbox.CircleAnnotation? _currentCircle; // Lưu hình tròn hiện tại

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm đường Mapbox')),
      body: Stack(
        children: [
          mapbox.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
          ),
          Positioned(
            top: 52,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildSearchBox("Nhập điểm bắt đầu", _startController, (value) async {
                  _startResults = await _mapboxService.searchPlaces(value);
                  setState(() {});
                }, _startResults, (place) {
                  _selectLocation(true, place);
                }),
                const SizedBox(height: 10),
                _buildSearchBox("Nhập điểm đến", _endController, (value) async {
                  _endResults = await _mapboxService.searchPlaces(value);
                  setState(() {});
                }, _endResults, (place) {
                  _selectLocation(false, place);
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "gps",
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "route",
            onPressed: _drawRoute,
            child: const Icon(Icons.directions),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(mapbox.MapboxMap controller) async {
    setState(() {
      _mapboxMapController = controller;
    });
    _pointAnnotationManager = await _mapboxMapController?.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await _mapboxMapController?.annotations.createPolylineAnnotationManager();
    _circleAnnotationManager = await _mapboxMapController?.annotations.createCircleAnnotationManager();

    // Thêm ảnh marker vào Mapbox style
    //final ByteData bytes = await rootBundle.load('assets/icon/red_marker.png');
    //final Uint8List list = bytes.buffer.asUint8List();
    //await _mapboxMapController?.addImage("red_marker", list);
  }

  Widget _buildSearchBox(String hint, TextEditingController controller, Function(String) onChanged,
      List<dynamic> results, Function(dynamic) onSelect) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10), // Giảm padding bên trong
            ),
            style: TextStyle(fontSize: 14), // Giảm kích thước chữ
          ),
        ),
        if (results.isNotEmpty)
          Container(
            color: Colors.white,
            child: Column(
              children: results
                  .map((place) => ListTile(
                title: Text(place['place_name']),
                onTap: () => onSelect(place),
              ))
                  .toList(),
            ),
          ),
      ],
    );
  }


  void _selectLocation(bool isStart, dynamic place) {
    List<dynamic> rawCoordinates = place['geometry']['coordinates'];
    List<double> selectedPoint = rawCoordinates.map((e) => (e as num).toDouble()).toList();

    setState(() {
      if (isStart) {
        _startController.text = place['place_name'];
        _startPoint = selectedPoint;
        _startResults = [];
        // Xóa đường đi cũ
        _polylineAnnotationManager?.deleteAll();
        _addCircle(_startPoint!); // Hình tròn cho điểm bắt đầu

      } else {
        _endController.text = place['place_name'];
        _endPoint = selectedPoint;
        _endResults = [];
        // Xóa đường đi cũ
        _polylineAnnotationManager?.deleteAll();
        _addMarker(_endPoint!); // Marker cho điểm đến
      }
    });

    _zoomToLocation(selectedPoint);
  }

  void _zoomToLocation(List<double> coordinates) {
    if (_mapboxMapController != null) {
      _mapboxMapController!.setCamera(mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(coordinates[0], coordinates[1])),
        zoom: 14,
      ));
    }
  }

  Future<void> _addMarker(List<double> coordinates) async {
    if (_pointAnnotationManager == null) return;

    // Xóa các marker cũ nếu cần
    await _pointAnnotationManager!.deleteAll();

    // Thêm marker mới
    await _pointAnnotationManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: mapbox.Position(coordinates[0], coordinates[1])),
        iconSize: 1.0, // Kích thước marker
        textField: "Điểm đến", // Chú thích marker
        textSize: 14.0,
        textColor: 0xFF000000,
        iconImage: "assets/icon/red_marker.png", // Tham chiếu đến biểu tượng marker
      ),
    );
  }





  Future<void> _addCircle(List<double> coordinates) async {
    if (_circleAnnotationManager == null) return;

    // Xóa hình tròn cũ nếu có
    if (_currentCircle != null) {
      await _circleAnnotationManager!.delete(_currentCircle!);
      _currentCircle = null;
    }

    // Thêm hình tròn mới
    _currentCircle = await _circleAnnotationManager!.create(mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(coordinates: mapbox.Position(coordinates[0], coordinates[1])),
      circleRadius: 8.0,
      circleColor: int.parse("0xffee4e8b"),
      circleStrokeWidth: 2.0,
      circleStrokeColor: int.parse("0xffffffff"),
    ));
  }

  Future<void> _drawRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    // Xóa đường đi cũ
    _polylineAnnotationManager?.deleteAll();

    List<List<double>> route =
    await _mapboxService.getRoute(_startPoint![0], _startPoint![1], _endPoint![0], _endPoint![1]);

    setState(() {
      _routeCoords = route;
    });

    if (_mapboxMapController != null) {
      _polylineAnnotationManager?.create(mapbox.PolylineAnnotationOptions(
        lineColor: Colors.blue.toARGB32(),
        lineWidth: 4.0,
        lineJoin: mapbox.LineJoin.ROUND,
        geometry: mapbox.LineString(
          coordinates: _routeCoords!.map((e) => mapbox.Position(e[0], e[1])).toList(),
        ),
      ));

      _mapboxMapController!.setCamera(mapbox.CameraOptions(
        zoom: 14,
        center: mapbox.Point(coordinates: mapbox.Position(
          (_startPoint![0] + _endPoint![0]) / 2,
          (_startPoint![1] + _endPoint![1]) / 2,
        )),
      ));
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.deniedForever) return;
    }

    geo.Position position = await geo.Geolocator.getCurrentPosition();

    setState(() {
      _startController.text = "Vị trí hiện tại";
      _startPoint = [position.longitude, position.latitude];
      _startResults = [];
    });

    _addCircle(_startPoint!);
    _zoomToLocation(_startPoint!);
  }
}