import 'dart:developer'
    as developer; //This class = your backend logic for the bus tracking
//It controls:Start trip, Update bus location, Update passengers, End trip,Stream live data to app
// Import developer package for logging instead of print (better for debugging)
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firebase Firestore package to interact with database

import 'active_trip_model.dart'; // Import your custom ActiveTrip model

import 'app_constants.dart'; // Import your custom ActiveTrip model

// Service class responsible for all Firestore operations related to trips
class FirestoreService {
  // Create an instance of Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter to access "activeTrips" collection easily
  CollectionReference<Map<String, dynamic>> get activeTripsCollection =>
      _firestore.collection('activeTrips');

  // ===================== START TRIP =====================
  // This function creates a new trip document in Firestore
  Future<void> startTrip({
    required String tripId, // Unique ID of trip
    required String busName, // Bus name
    required String route, // Route name
    required String tripTime, // Time of trip
    required String driverId, // Driver ID
    required String firstStopName, // First stop
    String? nextStopName, // Next stop (optional)
    String? destinationStop, // Final destination (optional)
    int passengerCount = 0, // Initial passengers (default = 0)
  }) async {
    // Make sure passenger count does not exceed max capacity
    final int cappedPassengerCount =
        passengerCount.clamp(0, busMaxCapacity).toInt();

    // Create/overwrite document in Firestore
    await activeTripsCollection.doc(tripId).set({
      // Basic trip info
      'tripId': tripId,
      'busName': busName,
      'route': route,
      'routeId': route, // Same as route (can be used differently later)
      'tripTime': tripTime,
      'driverId': driverId,

      // Trip status
      'status': 'active',

      // Check if bus is full
      'isFull': cappedPassengerCount >= busMaxCapacity,

      // Tracking indexes
      'currentStopIndex': 0,
      'nextStopIndex': nextStopName == null ? 0 : 1,

      // Progress of trip (0% at start)
      'progressPercent': 0.0,

      // Stop names
      'currentStopName': firstStopName,
      'nextStopName': nextStopName ?? firstStopName,
      'destinationStop': destinationStop ?? firstStopName,

      // Capacity data
      'passengerCount': cappedPassengerCount,
      'maxCapacity': busMaxCapacity,

      // Timestamps
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================== UPDATE STOP =====================
  // Updates bus position (when it moves to next stop)
  Future<void> updateTripStop({
    required String tripId,
    required int newStopIndex, // Current stop index
    required String newStopName, // Current stop name
    required int nextStopIndex, // Next stop index
    required String nextStopName, // Next stop name
    required double progressPercent, // Trip progress %
    required String destinationStop, // Final destination
  }) async {
    try {
      // Logging (for debugging)
      developer.log('=== FIRESTORE SERVICE ===');
      developer.log('Updating document: $tripId');
      developer.log('newStopIndex: $newStopIndex');
      developer.log('newStopName: $newStopName');

      // Update Firestore document
      await activeTripsCollection.doc(tripId).update({
        'currentStopIndex': newStopIndex,
        'nextStopIndex': nextStopIndex,

        // Ensure progress stays between 0 and 100
        'progressPercent': progressPercent.clamp(0.0, 100.0),

        'currentStopName': newStopName,
        'nextStopName': nextStopName,
        'destinationStop': destinationStop,

        // Update timestamp
        'updatedAt': FieldValue.serverTimestamp(),
      });

      developer.log('Firestore document updated');
    } catch (e) {
      // Log error if something fails
      developer.log('Firestore updateTripStop error: $e');
    }
  }

  // ===================== UPDATE PASSENGERS =====================
  // Updates number of passengers inside the bus
  Future<void> updatePassengerCount({
    required String tripId,
    required int passengerCount,
  }) async {
    // Prevent exceeding capacity
    final int cappedPassengerCount =
        passengerCount.clamp(0, busMaxCapacity).toInt();

    await activeTripsCollection.doc(tripId).update({
      'passengerCount': cappedPassengerCount,
      'maxCapacity': busMaxCapacity,

      // Automatically update full status
      'isFull': cappedPassengerCount >= busMaxCapacity,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================== MARK BUS FULL =====================
  // Forces the bus to be full manually
  Future<void> markBusFull({required String tripId}) async {
    await activeTripsCollection.doc(tripId).update({
      'isFull': true,
      'passengerCount': busMaxCapacity, // Set to max
      'maxCapacity': busMaxCapacity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================== END TRIP =====================
  // Ends the trip and marks it as completed
  Future<void> endTrip({
    required String tripId,
    int? finalStopIndex, // Optional final index
    String? finalStopName, // Optional final stop name
    String? destinationStop,
  }) async {
    // Base data for ending trip
    final data = <String, dynamic>{
      'status': 'completed',
      'progressPercent': 100.0, // Trip finished
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update stop indexes if provided
    if (finalStopIndex != null) {
      data['currentStopIndex'] = finalStopIndex;
      data['nextStopIndex'] = finalStopIndex;
    }

    // Update stop names if provided
    if (finalStopName != null) {
      data['currentStopName'] = finalStopName;
      data['nextStopName'] = finalStopName;
    }

    // Update destination if provided
    if (destinationStop != null) {
      data['destinationStop'] = destinationStop;
    }

    // Update Firestore document
    await activeTripsCollection.doc(tripId).update(data);
  }

  // ===================== GET ACTIVE TRIPS =====================
  // Returns a stream of trips filtered by route & time
  Stream<List<ActiveTrip>> getActiveTripsForRouteAndTime({
    required String route,
    required String tripTime,
  }) {
    return activeTripsCollection
        .where('route', isEqualTo: route)
        .where('tripTime', isEqualTo: tripTime)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          // Convert Firestore docs to ActiveTrip objects
          return snapshot.docs.map((doc) {
            return ActiveTrip.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // ===================== GET SINGLE TRIP =====================
  // Returns a stream of one specific trip
  Stream<ActiveTrip?> getSingleTrip({required String tripId}) {
    return activeTripsCollection.doc(tripId).snapshots().map((doc) {
      // If document doesn't exist → return null
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      // Convert document to ActiveTrip object
      return ActiveTrip.fromMap(doc.id, doc.data()!);
    });
  }
}
