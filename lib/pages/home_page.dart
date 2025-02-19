import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription<gl.Position>? userPositionStream;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: mp.MapWidget(
        onMapCreated: _onMapCreated,
        styleUri: mp.MapboxStyles.MAPBOX_STREETS,
      ),
    );
  }

  // Hàm khởi tạo bản đồ
  void _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });

    // Hiển thị vị trí người dùng
    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );

    // Thêm annotation tuỳ chỉnh
    final pointPointAnnotationManager = await mapboxMapController?.annotations.createPointAnnotationManager();

    if (pointPointAnnotationManager != null) {
      final Uint8List imageData = await loadHQMarketImage();

      mp.PointAnnotationOptions pointAnnotationOptions = mp.PointAnnotationOptions(
        image: imageData,
        iconSize: 0.3,
        geometry: mp.Point(coordinates: mp.Position(-122.0312186, 37.33233141)),
      );

      pointPointAnnotationManager.create(pointAnnotationOptions);
    }
  }

  // Hàm thiết lập theo dõi vị trí người dùng
  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    // Kiểm tra dịch vụ vị trí
    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Kiểm tra quyền vị trí
    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // Cài đặt theo dõi vị trí
    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    // Theo dõi vị trí người dùng
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

  // Hàm load ảnh từ thư mục assets
  Future<Uint8List> loadHQMarketImage() async {
    var byteData = await rootBundle.load("assets/icon/market.png"); // Đặt đúng đường dẫn tới file ảnh
    return byteData.buffer.asUint8List();
  }
}
