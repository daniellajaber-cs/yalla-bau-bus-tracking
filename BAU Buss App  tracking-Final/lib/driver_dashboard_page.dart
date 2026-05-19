import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_control_page.dart';
import 'driver_profile_page.dart';
import 'firestore_service.dart';
import 'app_constants.dart';

//When the driver presses Start Trip, the app creates a new trip ID, gets the selected route and stops,
//then stores the trip data in Firebase Firestore.
//After that, the driver is moved to the Trip Control page to control the live movement of the bus.

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  // Controller used to read the Bus ID entered by the driver
  final TextEditingController busIdController = TextEditingController();

  // Object used to call Firebase Firestore functions
  final FirestoreService firestoreService = FirestoreService();

  // List of available bus routes that the driver can choose from
  List<String> routes = [
    'Beirut to Debbieh',
    'Debbieh to Beirut',
    'Debbieh to Saida',
    'Saida to Debbieh',
    'Beirut to Saida',
  ];

  final List<TimeOfDay> departureTimes = const [
    TimeOfDay(hour: 7, minute: 10),
    TimeOfDay(hour: 8, minute: 10),
    TimeOfDay(hour: 8, minute: 15),
    TimeOfDay(hour: 8, minute: 30),
    TimeOfDay(hour: 9, minute: 10),
    TimeOfDay(hour: 10, minute: 15),
    TimeOfDay(hour: 11, minute: 10),
    TimeOfDay(hour: 12, minute: 15),
    TimeOfDay(hour: 13, minute: 10),
    TimeOfDay(hour: 14, minute: 10),
    TimeOfDay(hour: 14, minute: 15),
    TimeOfDay(hour: 15, minute: 15),
    TimeOfDay(hour: 16, minute: 15),
    TimeOfDay(hour: 17, minute: 15),
  ];

  // Stores the selected route, passenger count, trip status, and departure time
  String selectedRoute = 'Beirut to Debbieh';

  int passengerCount = 0;
  int maxCapacity = busMaxCapacity;

  String tripStatus = 'Awaiting Start';

  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 30);

  String busId = '';
  bool isStartingTrip = false;

  Future<void> pickDepartureTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  // This function changes the TimeOfDay value into readable format
  // Example: 8:30 AM
  String formatTime(TimeOfDay time) {
    final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // This function returns the bus capacity status based on passenger count
  String getBusStatusText() {
    if (passengerCount >= maxCapacity) {
      return 'Bus Status: Full';
    } else if (passengerCount >= (maxCapacity - 10)) {
      return 'Bus Status: Almost Full';
    } else {
      return 'Bus Status: Available';
    }
  }

  // This function returns a color depending on the bus capacity
  // Green = available, Orange = almost full, Red = full
  Color getBusStatusColor() {
    if (passengerCount >= maxCapacity) {
      return Colors.red;
    } else if (passengerCount >= (maxCapacity - 10)) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String getFirstStopName(String route) {
    return getStopsForRoute(route).first;
  }

  // This function returns all stops depending on the selected route
  List<String> getStopsForRoute(String route) {
    if (route == 'Beirut to Debbieh') {
      return ['Beirut', 'Choueifat', 'Khaldeh', 'Damour', 'Debbieh'];
    } else if (route == 'Debbieh to Beirut') {
      return ['Debbieh', 'Damour', 'Khaldeh', 'Choueifat', 'Beirut'];
    } else if (route == 'Saida to Debbieh') {
      return ['Sahet El Nejmeh', 'Awali', 'Jiyeh', 'Damour', 'Debbieh'];
    } else if (route == 'Debbieh to Saida') {
      return ['Debbieh', 'Damour', 'Jiyeh', 'Awali', 'Sahet El Nejmeh'];
    } else if (route == 'Beirut to Saida') {
      return ['Beirut', 'Khaldeh', 'Damour', 'Awali', 'Sahet El Nejmeh'];
    } else {
      return ['Start'];
    }
  }

  String getStopsText(String route) {
    if (route == 'Beirut to Debbieh') {
      return 'Stops: Choueifat - Khaldeh - Damour';
    } else if (route == 'Debbieh to Beirut') {
      return 'Stops: Damour - Khaldeh - Choueifat';
    } else if (route == 'Debbieh to Saida') {
      return 'Stops: Damour - Jiyeh - Awali';
    } else if (route == 'Saida to Debbieh') {
      return 'Stops: Jiyeh - Damour';
    } else if (route == 'Beirut to Saida') {
      return 'Stops: Khaldeh - Damour - Awali';
    } else {
      return 'Stops: ---';
    }
  }

  // This function starts a new trip and saves its data in Firebase
  Future<void> startTrip() async {
    if (busId.trim().isEmpty) {
      // Check if the driver entered a Bus ID before starting the trip
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Bus ID first')),
      );
      return;
    }

    try {
      // Show loading while the trip is being created
      setState(() {
        isStartingTrip = true;
      });

      // Create a unique trip ID using the current time
      final String newTripId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get trip details before saving them in Firebase
      final String departureTime = formatTime(selectedTime);
      final List<String> stops = getStopsForRoute(selectedRoute);
      final String firstStopName = stops.first;
      final String driverUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Save the new active trip in Firestore
      await firestoreService.startTrip(
        tripId: newTripId,
        busName: busId.trim(),
        route: selectedRoute,
        tripTime: departureTime,
        driverId: driverUid,
        firstStopName: firstStopName,
        nextStopName: stops.length > 1 ? stops[1] : firstStopName,
        destinationStop: stops.last,
        passengerCount: passengerCount,
      );

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      setState(() {
        tripStatus = 'Trip Started';
      });

      // After creating the trip, move the driver to the trip control page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => TripControlPage(
                selectedRoute: selectedRoute,
                departureTime: departureTime,
                tripId: newTripId,
                busId: busId.trim(),
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start trip: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isStartingTrip = false;
        });
      }
    }
  }

  //Dispose the controller to free memory when leaving the page
  @override
  void dispose() {
    busIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BAU Bus Tracker',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Driver Dashboard',
              style: TextStyle(
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages button pressed')),
              );
            },
            icon: const Icon(Icons.message_outlined, color: Colors.blue),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverProfilePage(busId: busId),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(
                      alpha: 0.15,
                    ), // Replaced deprecated withOpacity with withValues.
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 6,
                        backgroundColor: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: busIdController,
                    decoration: InputDecoration(
                      hintText: 'Enter Bus ID',
                      prefixIcon: const Icon(Icons.directions_bus),
                      filled: true,
                      fillColor: const Color(0xFFF5F6F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        busId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tripStatus,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_bus, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            busId.isEmpty ? 'Bus ID: ---' : 'Bus ID: $busId',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.groups, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '$passengerCount / $maxCapacity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Route:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedRoute,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    getStopsText(selectedRoute),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            'Departure Time: ${formatTime(selectedTime)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TimeOfDay>(
                        initialValue: selectedTime,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF5F6F8),
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items:
                            departureTimes.map((time) {
                              return DropdownMenuItem<TimeOfDay>(
                                value: time,
                                child: Text(formatTime(time)),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value == null) {
                            // Added braces to satisfy the curly-braces lint.
                            return;
                          }

                          setState(() {
                            selectedTime = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(
                      alpha: 0.15,
                    ), // Replaced deprecated withOpacity with withValues.
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Direction',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoute,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F6F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items:
                        routes.map((route) {
                          return DropdownMenuItem<String>(
                            value: route,
                            child: Text(route),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRoute = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(
                      alpha: 0.15,
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
                      'Passenger Capacity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF1F2F4),
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.grey),
                          onPressed: () {
                            if (passengerCount > 0) {
                              setState(() {
                                passengerCount--;
                              });
                            }
                          },
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '$passengerCount / $maxCapacity',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Boarded',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF1F2F4),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.grey),
                          onPressed: () {
                            if (passengerCount < maxCapacity) {
                              setState(() {
                                passengerCount++;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                        fontSize: 16,
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
                onPressed: isStartingTrip ? null : startTrip,
                icon:
                    isStartingTrip
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  isStartingTrip ? 'STARTING...' : 'START TRIP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(
                  alpha: 0.10,
                ), // Replaced deprecated withOpacity with withValues.
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please ensure all passengers are safely seated before starting the trip.',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverProfilePage(busId: busId),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
