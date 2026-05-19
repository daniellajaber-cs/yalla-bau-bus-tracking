import 'dart:async'
    show
        Future,
        Timer; // Used to create a timer that moves the bus during the trip
import 'dart:developer'
    as developer; // Added developer logging for avoid_print lint.
import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'app_constants.dart';

//This page is the Trip Control Page. It starts after the driver presses Start Trip. It uses
//a timer to update the bus progress every second and moves the bus icon on the route line.

//The page calculates the current stop and next stop based on the progress percentage. Then it updates
//Firebase Firestore so the student side can see the same trip progress in real time.

//The driver can also increase or decrease the passenger count, mark the bus as full, and end the trip.
// When the trip ends, the status is updated in Firebase and tracking stops

// This page controls an active trip after the driver presses Start Trip
class TripControlPage extends StatefulWidget {
  // Data received from the Driver Dashboard page
  final String selectedRoute;
  final String departureTime;
  final String tripId;
  final String busId;

  const TripControlPage({
    super.key,
    required this.selectedRoute,
    required this.departureTime,
    required this.tripId,
    required this.busId,
  });

  @override
  State<TripControlPage> createState() => _TripControlPageState();
}

class _TripControlPageState extends State<TripControlPage> {
  // Firebase service object used to update trip data in Firestore

  final FirestoreService firestoreService = FirestoreService();

  // Demo mode makes the trip move faster for presentation/testing
  bool demoMode = true;

  // Variables used to track trip progress and passenger capacity
  late int totalTripSeconds;
  double progressValue = 0;
  int passengerCount = 0;
  int maxCapacity = busMaxCapacity;

  Timer? timer;
  int elapsedSeconds = 0;
  bool isLoading = false;

  // Start loading trip data and begin the timer when the page opens
  @override
  void initState() {
    super.initState();
    totalTripSeconds = getTripDurationInSeconds(widget.selectedRoute);
    loadPassengerData();
    startTripTimer();
  }

  // Stop the timer when leaving the page to avoid memory leaks
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // Load passenger count and capacity from Firebase
  Future<void> loadPassengerData() async {
    try {
      final trip =
          await firestoreService.getSingleTrip(tripId: widget.tripId).first;

      if (trip == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        passengerCount = trip.passengerCount;
        maxCapacity = trip.maxCapacity;
      });
    } catch (e) {
      debugPrint('Error loading passenger data: $e');
    }
  }

  // Returns trip duration depending on the selected route
  int getTripDurationInSeconds(String route) {
    int durationMinutes = 40;

    if (route == 'Beirut to Debbieh' || route == 'Debbieh to Beirut') {
      durationMinutes = 40;
    } else if (route == 'Saida to Debbieh' || route == 'Debbieh to Saida') {
      durationMinutes = 40;
    } else if (route == 'Beirut to Saida') {
      durationMinutes = 50;
    }

    return demoMode ? durationMinutes : durationMinutes * 60;
  }

  // Starts a timer that updates the bus progress every second
  void startTripTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      if (elapsedSeconds < totalTripSeconds) {
        setState(() {
          elapsedSeconds++;

          // Update progress value based on elapsed time
          progressValue = (elapsedSeconds / totalTripSeconds) * 100;
        });

        // Send updated stop and progress information to Firebase
        await updateStopInFirestore();
      } else {
        timer.cancel();

        if (progressValue < 100) {
          setState(() {
            progressValue = 100;
          });
        }

        // This function updates the current stop, next stop, and progress in Firebase
        await updateStopInFirestore();
        await endTrip(autoClose: true, showMessage: false);
      }
    });
  }

  Future<void> updateStopInFirestore() async {
    try {
      // Get stops for the selected route and calculate arrived stop

      List<String> stops = getStops();
      int stopIndex = getArrivedStopIndex();

      developer.log('=== DRIVER UPDATE ===');
      developer.log('tripId = ${widget.tripId}');
      developer.log('route = ${widget.selectedRoute}');
      developer.log('stopIndex = $stopIndex');
      developer.log('stopName = ${stops[stopIndex]}');
      developer.log('progressValue = $progressValue');

      // Update trip stop details in Firestore so students can see live changes
      await firestoreService.updateTripStop(
        tripId: widget.tripId,
        newStopIndex: stopIndex,
        newStopName: stops[stopIndex],
        nextStopIndex:
            stopIndex >= stops.length - 1 ? stopIndex : stopIndex + 1,
        nextStopName:
            stopIndex >= stops.length - 1 ? stops.last : stops[stopIndex + 1],
        progressPercent: progressValue,
        destinationStop: stops.last,
      );

      developer.log(
        'Firestore update sent successfully',
      ); // Replaced print with developer.log.
    } catch (e) {
      debugPrint('Error updating trip stop: $e');
    }
  }

  // Returns the list of stops based on the selected route
  List<String> getStops() {
    if (widget.selectedRoute == 'Beirut to Debbieh') {
      return ['Beirut', 'Choueifat', 'Khaldeh', 'Damour', 'Debbieh'];
    } else if (widget.selectedRoute == 'Debbieh to Beirut') {
      return ['Debbieh', 'Damour', 'Khaldeh', 'Choueifat', 'Beirut'];
    } else if (widget.selectedRoute == 'Saida to Debbieh') {
      return ['Sahet El Nejmeh', 'Awali', 'Jiyeh', 'Damour', 'Debbieh'];
    } else if (widget.selectedRoute == 'Debbieh to Saida') {
      return ['Debbieh', 'Damour', 'Jiyeh', 'Awali', 'Sahet El Nejmeh'];
    } else if (widget.selectedRoute == 'Beirut to Saida') {
      return ['Beirut', 'Khaldeh', 'Damour', 'Awali', 'Sahet El Nejmeh'];
    } else {
      return ['Start', 'Stop 1', 'Stop 2', 'End'];
    }
  }

  // Returns the next stop based on the current progress percentage
  String getNextStop() {
    List<String> stops = getStops();

    if (stops.length == 5) {
      if (progressValue < 25) {
        // Added braces to satisfy the curly-braces lint.
        return stops[1];
      }
      if (progressValue < 50) {
        // Added braces to satisfy the curly-braces lint.
        return stops[2];
      }
      if (progressValue < 75) {
        // Added braces to satisfy the curly-braces lint.
        return stops[3];
      }
      if (progressValue < 100) {
        // Added braces to satisfy the curly-braces lint.
        return stops[4];
      }
    }

    if (stops.length == 4) {
      if (progressValue < 33) {
        // Added braces to satisfy the curly-braces lint.
        return stops[1];
      }
      if (progressValue < 66) {
        // Added braces to satisfy the curly-braces lint.
        return stops[2];
      }
      if (progressValue < 100) {
        // Added braces to satisfy the curly-braces lint.
        return stops[3];
      }
    }

    return 'Trip Completed';
  }

  // Calculates which stop the bus has reached based on progress percentage
  int getArrivedStopIndex() {
    List<String> stops = getStops();

    if (stops.length == 5) {
      if (progressValue >= 100) {
        // Added braces to satisfy the curly-braces lint.
        return 4;
      }
      if (progressValue >= 75) {
        // Added braces to satisfy the curly-braces lint.
        return 3;
      }
      if (progressValue >= 50) {
        // Added braces to satisfy the curly-braces lint.
        return 2;
      }
      if (progressValue >= 25) {
        // Added braces to satisfy the curly-braces lint.
        return 1;
      }
      return 0;
    }

    if (stops.length == 4) {
      if (progressValue >= 100) {
        // Added braces to satisfy the curly-braces lint.
        return 3;
      }
      if (progressValue >= 66) {
        // Added braces to satisfy the curly-braces lint.
        return 2;
      }
      if (progressValue >= 33) {
        // Added braces to satisfy the curly-braces lint.
        return 1;
      }
      return 0;
    }

    return 0;
  }

  // Increase passenger count and update Firebase

  Future<void> increasePassengerCount() async {
    if (passengerCount >= maxCapacity) {
      // Added braces to satisfy the curly-braces lint.
      return;
    }

    final int newCount = passengerCount + 1;

    setState(() {
      passengerCount = newCount;
    });

    try {
      await firestoreService.updatePassengerCount(
        tripId: widget.tripId,
        passengerCount: newCount,
      );
    } catch (e) {
      debugPrint('Failed to increase passenger count: $e');
    }
  }

  // Decrease passenger count and update Firebase

  Future<void> decreasePassengerCount() async {
    if (passengerCount <= 0) {
      // Added braces to satisfy the curly-braces lint.
      return;
    }

    final int newCount = passengerCount - 1;

    setState(() {
      passengerCount = newCount;
    });

    try {
      await firestoreService.updatePassengerCount(
        tripId: widget.tripId,
        passengerCount: newCount,
      );
    } catch (e) {
      debugPrint('Failed to decrease passenger count: $e');
    }
  }

  // Ends the trip, stops the timer, and updates Firebase status
  Future<void> endTrip({
    bool autoClose = false,
    bool showMessage = true,
  }) async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      timer?.cancel();

      final stops = getStops();

      await firestoreService.endTrip(
        tripId: widget.tripId,
        finalStopIndex: stops.length - 1,
        finalStopName: stops.last,
        destinationStop: stops.last,
      );

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ended successfully')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to end trip: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> markBusAsFull() async {
    try {
      setState(() {
        passengerCount = maxCapacity;
      });

      await firestoreService.markBusFull(tripId: widget.tripId);

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bus marked as full')));
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark bus as full: $e')));
    }
  }

  // Shows the bus capacity status as Available, Almost Full, or Full
  String getBusStatusText() {
    if (passengerCount >= maxCapacity) {
      return 'Bus Status: Full';
    } else if (passengerCount >= (maxCapacity - 10)) {
      return 'Bus Status: Almost Full';
    } else {
      return 'Bus Status: Available';
    }
  }

  Color getBusStatusColor() {
    if (passengerCount >= maxCapacity) {
      return Colors.red;
    } else if (passengerCount >= (maxCapacity - 10)) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> stops = getStops();
    int arrivedIndex = getArrivedStopIndex();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await endTrip();
          },
        ),
        title: const Text(
          'Trip Control',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.busId.toUpperCase()} - ACTIVE',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Currently at ${progressValue.toInt()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Next stop: ${getNextStop()}',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 80,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double lineWidth = constraints.maxWidth;

                    double busLeft = (lineWidth * (progressValue / 100)) - 12;

                    if (busLeft < 0) {
                      // Added braces to satisfy the curly-braces lint.
                      busLeft = 0;
                    }
                    if (busLeft > lineWidth - 24) {
                      // Added braces to satisfy the curly-braces lint.
                      busLeft = lineWidth - 24;
                    }

                    return Stack(
                      children: [
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(
                                alpha: 0.3,
                              ), // Replaced deprecated withOpacity with withValues.
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          left: 0,
                          child: Container(
                            width: lineWidth * (progressValue / 100),
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              stops.length,
                              (index) => CircleAvatar(
                                radius: 8,
                                backgroundColor:
                                    index <= arrivedIndex
                                        ? Colors.blue
                                        : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: busLeft,
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stops.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    'MIDPOINT',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    stops.last.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stops.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.6,
                ),
                itemBuilder: (context, index) {
                  bool isArrived = index <= arrivedIndex;

                  return Card(
                    color: isArrived ? Colors.blue : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        isArrived
                            ? 'Arrived ${stops[index]}'
                            : 'Pending ${stops[index]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isArrived ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(
                        alpha: 0.12,
                      ), // Replaced deprecated withOpacity with withValues.
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PASSENGER CAPACITY',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFF1F2F4),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.black),
                            onPressed: decreasePassengerCount,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$passengerCount / $maxCapacity',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Boarded',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFF1F2F4),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.black),
                            onPressed: increasePassengerCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: markBusAsFull,
                        child: const Text('MARK BUS AS FULL'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: getBusStatusColor().withValues(
                          alpha: 0.12,
                        ), // Replaced deprecated withOpacity with withValues.
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        getBusStatusText(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: getBusStatusColor(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : endTrip,
                  icon:
                      isLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.stop_circle, color: Colors.white),
                  label: Text(
                    isLoading ? 'ENDING...' : 'END TRIP',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
