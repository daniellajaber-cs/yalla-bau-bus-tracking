import 'app_constants.dart';
//This model acts as a bridge between the frontend UI and Firebase database
//This file represents the ActiveTrip model. It is used to store and manage all data related to a
//bus trip such as route, stops, progress, and passenger count.

// This class represents a single active bus trip in the system

class ActiveTrip {
  final String id; // unique id of the trip from firestore
  final String busName;
  final String route;
  final String routeId;
  final String tripTime;
  final String driverId;
  final String status;
  final bool isFull;
  final int currentStopIndex; // index of current stop in the route
  final int nextStopIndex;
  final double progressPercent; // progreess of the trip (0--> 1 0% --> 100%)
  final String currentStopName;
  final String nextStopName;
  final String destinationStop;
  final int passengerCount;
  final int maxCapacity;

  //contructors to initialize all values
  ActiveTrip({
    required this.id,
    required this.busName,
    required this.route,
    required this.routeId,
    required this.tripTime,
    required this.driverId,
    required this.status,
    required this.isFull,
    required this.currentStopIndex,
    required this.nextStopIndex,
    required this.progressPercent,
    required this.currentStopName,
    required this.nextStopName,
    required this.destinationStop,
    required this.passengerCount,
    required this.maxCapacity,
  });
  //convert firestore data map into active trip object so it can be used inside the app
  factory ActiveTrip.fromMap(String id, Map<String, dynamic> data) {
    //ensure passenger count is valid and does not exceed max capacity
    final passengerCount =
        ((data['passengerCount'] as num?)?.toInt() ?? 0)
            .clamp(0, busMaxCapacity)
            .toInt();

    return ActiveTrip(
      id: id,

      //get values from firestore
      busName: data['busName'] ?? '',
      route: data['route'] ?? '',

      //if routeID is missing , use route instead
      routeId: data['routeId'] ?? data['route'] ?? '',

      tripTime: data['tripTime'] ?? '',
      driverId: data['driverId'] ?? '',
      status: data['status'] ?? '',

      //bus is full if all passengers count reaches max
      isFull: passengerCount >= busMaxCapacity || (data['isFull'] ?? false),

      currentStopIndex: data['currentStopIndex'] ?? 0,
      nextStopIndex: data['nextStopIndex'] ?? 0,

      //convert progress to double safety
      progressPercent: (data['progressPercent'] ?? 0).toDouble(),

      currentStopName: data['currentStopName'] ?? '',
      nextStopName: data['nextStopName'] ?? '',
      destinationStop: data['destinationStop'] ?? '',

      passengerCount: passengerCount,

      // Set max capacity from constants file
      maxCapacity: busMaxCapacity,
    );
  }

  // Convert ActiveTrip object into Map to store in Firestore so it can be stored in Firestore
  Map<String, dynamic> toMap() {
    return {
      'busName': busName,
      'route': route,
      'routeId': routeId,
      'tripTime': tripTime,
      'driverId': driverId,
      'status': status,
      'isFull': isFull,
      'currentStopIndex': currentStopIndex,
      'nextStopIndex': nextStopIndex,
      'progressPercent': progressPercent,
      'currentStopName': currentStopName,
      'nextStopName': nextStopName,
      'destinationStop': destinationStop,
      'passengerCount': passengerCount,
      'maxCapacity': busMaxCapacity,
    };
  }
}
