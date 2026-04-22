import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:reliefnet/services/gemini_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyHospitalsPage extends StatefulWidget {
  const NearbyHospitalsPage({super.key});

  @override
  State<NearbyHospitalsPage> createState() => _NearbyHospitalsPageState();
}

class _NearbyHospitalsPageState extends State<NearbyHospitalsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hospitals = [];
  String _currentAddress = "Searching...";

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hospitals = [];
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permissions are denied';
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable them in settings.';
      }

      // Using lower accuracy for faster first fix if needed, but High is better for radius
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      String address = "Unknown Area";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = "${p.subLocality ?? p.locality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}".replaceAll(RegExp(r'^, |, $'), '').trim();
          if (address.isEmpty || address == ",") address = "Lat: ${position.latitude.toStringAsFixed(2)}, Lng: ${position.longitude.toStringAsFixed(2)}";
          if (mounted) setState(() => _currentAddress = address);
        }
      } catch (e) {
        print("Geocoding error: $e");
        address = "Lat: ${position.latitude.toStringAsFixed(2)}, Lng: ${position.longitude.toStringAsFixed(2)}";
        if (mounted) setState(() => _currentAddress = address);
      }

      final results = await GeminiService.getNearbyHospitals(
        position.latitude,
        position.longitude,
        address,
      );
      
      if (mounted) setState(() => _hospitals = results);
    } catch (e) {
      print("Fetch Hospitals Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            action: SnackBarAction(label: 'Retry', onPressed: _fetchHospitals),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchDirections(String hospitalName, String address) async {
    final query = Uri.encodeComponent("$hospitalName, $address");
    final url = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text("Locating your current area...", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _currentAddress,
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchHospitals,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentAddress,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Hospitals within 7km radius",
                          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _hospitals.isEmpty
                        ? ListView( // Using ListView so RefreshIndicator works
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text("No hospitals found in this area.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    Text("Try refreshing or checking your GPS.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _hospitals.length,
                            itemBuilder: (context, index) {
                              final hospital = _hospitals[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.local_hospital, color: Colors.red),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hospital['name'] ?? "Unknown Hospital",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              hospital['address'] ?? "Address not available",
                                              style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    "${hospital['distance']} km",
                                                    style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                                Text(" ${hospital['rating']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.blue.withOpacity(0.1),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        icon: const Icon(Icons.directions_rounded, color: Colors.blue, size: 20),
                                        onPressed: () => _launchDirections(hospital['name'] ?? '', hospital['address'] ?? ''),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
