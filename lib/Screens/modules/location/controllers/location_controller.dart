import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationController extends GetxController {
  final Rx<LatLng> currentCenter = const LatLng(10.0159, 76.3419).obs;
  final RxDouble zoomLevel = 14.4746.obs;
  final RxBool isTrafficEnabled = false.obs;

  GoogleMapController? _mapController;

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void toggleTraffic() {
    isTrafficEnabled.value = !isTrafficEnabled.value;
  }

  void centerOnVehicle() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentCenter.value, zoom: zoomLevel.value),
        ),
      );
    }
  }

  void zoomIn() {
    zoomLevel.value++;
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    zoomLevel.value--;
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  void onClose() {
    _mapController?.dispose();
    super.onClose();
  }
}
