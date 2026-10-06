import '../domain/models.dart';

const atlas = <Place>[
  Place(name: 'Kathmandu', region: 'Nepal', latitude: 27.7172, longitude: 85.3240, timezone: 'Asia/Kathmandu'),
  Place(name: 'Pokhara', region: 'Nepal', latitude: 28.2096, longitude: 83.9856, timezone: 'Asia/Kathmandu'),
  Place(name: 'Lalitpur', region: 'Nepal', latitude: 27.6588, longitude: 85.3247, timezone: 'Asia/Kathmandu'),
  Place(name: 'Biratnagar', region: 'Nepal', latitude: 26.4525, longitude: 87.2718, timezone: 'Asia/Kathmandu'),
  Place(name: 'Bharatpur', region: 'Nepal', latitude: 27.6706, longitude: 84.4384, timezone: 'Asia/Kathmandu'),
  Place(name: 'New Delhi', region: 'India', latitude: 28.6139, longitude: 77.2090, timezone: 'Asia/Kolkata'),
  Place(name: 'Mumbai', region: 'India', latitude: 19.0760, longitude: 72.8777, timezone: 'Asia/Kolkata'),
  Place(name: 'Kolkata', region: 'India', latitude: 22.5726, longitude: 88.3639, timezone: 'Asia/Kolkata'),
  Place(name: 'Chennai', region: 'India', latitude: 13.0827, longitude: 80.2707, timezone: 'Asia/Kolkata'),
  Place(name: 'Bengaluru', region: 'India', latitude: 12.9716, longitude: 77.5946, timezone: 'Asia/Kolkata'),
  Place(name: 'Varanasi', region: 'India', latitude: 25.3176, longitude: 82.9739, timezone: 'Asia/Kolkata'),
  Place(name: 'Jaipur', region: 'India', latitude: 26.9124, longitude: 75.7873, timezone: 'Asia/Kolkata'),
  Place(name: 'Dhaka', region: 'Bangladesh', latitude: 23.8103, longitude: 90.4125, timezone: 'Asia/Dhaka'),
  Place(name: 'Colombo', region: 'Sri Lanka', latitude: 6.9271, longitude: 79.8612, timezone: 'Asia/Colombo'),
  Place(name: 'London', region: 'United Kingdom', latitude: 51.5074, longitude: -0.1278, timezone: 'Europe/London'),
  Place(name: 'Paris', region: 'France', latitude: 48.8566, longitude: 2.3522, timezone: 'Europe/Paris'),
  Place(name: 'Berlin', region: 'Germany', latitude: 52.5200, longitude: 13.4050, timezone: 'Europe/Berlin'),
  Place(name: 'New York', region: 'USA', latitude: 40.7128, longitude: -74.0060, timezone: 'America/New_York'),
  Place(name: 'Los Angeles', region: 'USA', latitude: 34.0522, longitude: -118.2437, timezone: 'America/Los_Angeles'),
  Place(name: 'Chicago', region: 'USA', latitude: 41.8781, longitude: -87.6298, timezone: 'America/Chicago'),
  Place(name: 'Toronto', region: 'Canada', latitude: 43.6532, longitude: -79.3832, timezone: 'America/Toronto'),
  Place(name: 'Sydney', region: 'Australia', latitude: -33.8688, longitude: 151.2093, timezone: 'Australia/Sydney'),
  Place(name: 'Tokyo', region: 'Japan', latitude: 35.6762, longitude: 139.6503, timezone: 'Asia/Tokyo'),
  Place(name: 'Singapore', region: 'Singapore', latitude: 1.3521, longitude: 103.8198, timezone: 'Asia/Singapore'),
  Place(name: 'Dubai', region: 'UAE', latitude: 25.2048, longitude: 55.2708, timezone: 'Asia/Dubai'),
];

List<Place> searchPlaces(String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return atlas.take(8).toList();
  return atlas.where((p) => p.label.toLowerCase().contains(s)).toList();
}

final kathmandu = atlas.first;
