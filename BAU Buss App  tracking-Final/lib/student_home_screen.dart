// dart:async is needed because this screen uses StreamSubscription to listen to Firestore trip updates.
import 'dart:async';
// Flutter Material package gives us widgets like Scaffold, Container, Text, Row, Column, DropdownButton, etc.
import 'package:flutter/material.dart';
// Tracker page for the main route: Beirut to Debbieh.
import 'bus_tracker_page.dart';
// Tracker page for the reverse route: Debbieh to Beirut.
import 'bus_tracker_reverse.dart';
// Tracker page for the route: Debbieh to Saida.
import 'bus_tracker_debbieh_saida.dart';
// Tracker page for the route: Saida to Debbieh.
import 'bus_tracker_saida_debbieh.dart';
// Tracker page for the route: Beirut to Saida.
import 'bus_tracker_beirut_saida.dart';
// Profile screen opened from the bottom navigation bar.
import 'profile_screen.dart';
// Service file that communicates with Firestore and gets active trips.
import 'firestore_service.dart';
// ActiveTrip model represents one currently active bus trip from Firestore.
import 'active_trip_model.dart';
// NotificationService handles notification settings, unread count, and creating notifications.
import 'notification_service.dart';
// Screen that displays user notifications.
import 'notification_screen.dart';

// StudentHomeScreen is the main home page for the student side of the bus app.
// It is StatefulWidget because the selected route, visible buses, and trip list can change while the user uses the screen.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  // Creates the mutable state object that contains the logic and UI for this screen.
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // Object used to read active bus trips from Firestore.
  final FirestoreService firestoreService = FirestoreService();
  // Object used to read notification settings, unread count, and create notifications.
  final NotificationService notificationService = NotificationService();

  // The route selected by default when the screen first opens.
  String selectedRoute = 'Beirut to Debbieh';

  // List of all routes shown inside the dropdown menu.
  final List<String> routes = [
    'Beirut to Debbieh',
    'Debbieh to Beirut',
    'Debbieh to Saida',
    'Saida to Debbieh',
    'Beirut to Saida',
  ];

  // Each route has its own list of trip times.
  // The key is the route name, and the value is the list of times for that route.
  final Map<String, List<String>> schedules = {
    'Beirut to Debbieh': [
      '7:10 AM',
      '8:10 AM',
      '9:10 AM',
      '11:10 AM',
      '1:10 PM',
      '2:10 PM',
    ],
    'Debbieh to Beirut': [
      '8:15 AM',
      '10:15 AM',
      '12:15 PM',
      '2:15 PM',
      '3:15 PM',
      '4:15 PM',
    ],
    'Debbieh to Saida': [
      '10:15 AM',
      '12:15 PM',
      '2:15 PM',
      '3:15 PM',
      '4:15 PM',
    ],
    'Saida to Debbieh': [
      '7:10 AM',
      '8:10 AM',
      '9:10 AM',
      '11:10 AM',
      '1:10 PM',
    ],
    'Beirut to Saida': ['2:15 PM', '3:15 PM', '4:15 PM', '5:15 PM'],
  };

  // Each route has its own ordered list of stops.
  // This is used to know when the bus is near or has arrived at the selected stop.
  final Map<String, List<String>> routeStops = {
    'Beirut to Debbieh': [
      'Beirut',
      'Choueifat',
      'Khaldeh',
      'Damour',
      'Debbieh',
    ],
    'Debbieh to Beirut': [
      'Debbieh',
      'Damour',
      'Khaldeh',
      'Choueifat',
      'Beirut',
    ],
    'Debbieh to Saida': [
      'Debbieh',
      'Damour',
      'Jiyeh',
      'Awali',
      'Sahet El Nejmeh',
    ],
    'Saida to Debbieh': [
      'Sahet El Nejmeh',
      'Awali',
      'Jiyeh',
      'Damour',
      'Debbieh',
    ],
    'Beirut to Saida': [
      'Beirut',
      'Khaldeh',
      'Damour',
      'Awali',
      'Sahet El Nejmeh',
    ],
  };

  // currentTrips stores the trip times for the currently selected route.
  // It is late because it is initialized in initState after selectedRoute is already known.
  late List<String> currentTrips;

  // Stores whether the available buses section is shown or hidden for each trip card.
  // Example: showBuses[0] = true means the first trip card is expanded.
  final Map<int, bool> showBuses = {};
  // Stores Firestore stream subscriptions so they can be cancelled later in dispose().
  // This prevents memory leaks when leaving the page.
  final List<StreamSubscription<List<ActiveTrip>>> _tripSubscriptions = [];
  // Keeps the last stop index processed for each trip.
  // This prevents sending the same notification many times for the same stop.
  final Map<String, int> _lastProcessedStopIndexByTrip = {};

  // Runs once when the screen is first created.
  @override
  void initState() {
    super.initState();

    // Load the trip times of the default selected route.
    currentTrips = List.from(schedules[selectedRoute]!);
    // Start listening to active trips so notifications can be checked while the student is inside the app.
    _startGlobalTripListeners();
  }

  // Runs when this screen is removed from memory.
  // We cancel all Firestore listeners here to avoid background memory usage.
  @override
  void dispose() {
    // Cancel all active Firestore listeners before the screen is destroyed.
    for (final subscription in _tripSubscriptions) {
      subscription.cancel();
    }
    _tripSubscriptions.clear();
    super.dispose();
  }

  // Starts Firestore listeners for every trip time in the selected route.
  // Every time Firestore sends new trip data, we check if a notification should be created.
  void _startGlobalTripListeners() {
    // Cancel old listeners before starting new ones.
    // This is important when the user changes the selected route.
    for (final subscription in _tripSubscriptions) {
      subscription.cancel();
    }
    _tripSubscriptions.clear();

    // Create one listener for each trip time of the selected route.
    for (final tripTime in schedules[selectedRoute] ?? <String>[]) {
      final subscription = firestoreService
          .getActiveTripsForRouteAndTime(
            route: selectedRoute,
            tripTime: tripTime,
          )
          .listen((trips) {
            for (final trip in trips) {
              _handleTripUpdate(trip);
            }
          });

      _tripSubscriptions.add(subscription);
    }
  }

  // Handles each trip update coming from Firestore.
  // It only continues if the bus moved to a new stop index.
  Future<void> _handleTripUpdate(ActiveTrip trip) async {
    // Get the last stop index that was already processed for this specific trip.
    final previousStopIndex = _lastProcessedStopIndexByTrip[trip.id];

    // If the stop index did not change, do nothing to avoid duplicate notifications.
    if (previousStopIndex == trip.currentStopIndex) {
      return;
    }

    // Save the new stop index as processed.
    _lastProcessedStopIndexByTrip[trip.id] = trip.currentStopIndex;
    await _checkAndSendGlobalNotifications(trip);
  }

  // Checks user notification settings and decides whether to create a near-stop or arrival notification.
  Future<void> _checkAndSendGlobalNotifications(ActiveTrip trip) async {
    // Read the user's notification preferences, such as selected stop and arrival alerts.
    final settings = await notificationService.getSettings();

    // If the widget was removed before the async task finished, stop safely.
    if (!mounted) {
      return;
    }
    // If push notifications are disabled by the user, do not create notifications.
    if (!settings.pushNotifications) {
      return;
    }

    // Get the stops list that belongs to this trip's route.
    final stops = routeStops[trip.route];
    // If the route has no stops saved, we cannot compare stop positions.
    if (stops == null || stops.isEmpty) {
      return;
    }

    // Find the position of the user's selected stop inside the stops list.
    final selectedStopIndex = stops.indexOf(settings.selectedStop);
    // If the selected stop is not part of this route, stop checking.
    if (selectedStopIndex == -1) {
      return;
    }

    // Keep currentStopIndex inside the valid range so the app does not crash from an invalid index.
    final currentStopIndex = trip.currentStopIndex.clamp(0, stops.length - 1);

    // Send a notification when the bus is one stop before the user's selected stop.
    if (selectedStopIndex > 0 &&
        currentStopIndex >= selectedStopIndex - 1 &&
        currentStopIndex < selectedStopIndex) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${trip.id}_near_${settings.selectedStop}',
        title: 'Bus is near your stop',
        body:
            'Your bus is now near ${settings.selectedStop}. Please get ready.',
        type: 'near_stop',
        route: trip.route,
        tripId: trip.id,
      );
    }

    // Send an arrival notification when the bus reaches or passes the selected stop.
    if (settings.arrivalAlerts && currentStopIndex >= selectedStopIndex) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${trip.id}_arrived_${settings.selectedStop}',
        title: 'Be Ready!',
        body: 'The bus has reached ${settings.selectedStop}.',
        type: 'destination_arrived',
        route: trip.route,
        tripId: trip.id,
        requireArrivalAlerts: true,
      );
    }
  }

  // Returns today's date in a simple format like: Tuesday, May 12.
  String getTodayDate() {
    final now = DateTime.now();

    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  // Reloads the trip times of the selected route and closes all expanded bus sections.
  void refreshTrips() {
    setState(() {
      currentTrips = List.from(schedules[selectedRoute]!);
      showBuses.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trips refreshed')));
  }

  // Called when the user selects another route from the dropdown.
  // It updates the trip list and restarts Firestore listeners for the new route.
  void changeRoute(String route) {
    setState(() {
      selectedRoute = route;
      currentTrips = List.from(schedules[route]!);
      showBuses.clear();
    });
    // Start listening to active trips so notifications can be checked while the student is inside the app.
    _startGlobalTripListeners();
  }

  // Shows the first trip as ACTIVE and the remaining trips as SCHEDULED.
  String getStatus(int index) {
    return index == 0 ? 'ACTIVE' : 'SCHEDULED';
  }

  // Returns the color used for the trip status label.
  Color getStatusColor(int index) {
    return index == 0 ? const Color(0xFF2F80ED) : const Color(0xFF98A2B3);
  }

  // Returns a demo crowd level based on the trip index.
  // This is not coming from Firestore; it rotates between High, Medium, and Low.
  String getCrowdLevel(int index) {
    if (index % 3 == 0) {
      return 'High';
    }
    if (index % 3 == 1) {
      return 'Medium';
    }
    return 'Low';
  }

  // Chooses the circle color depending on the crowd level.
  Color getCrowdColor(String crowdLevel) {
    if (crowdLevel == 'High') {
      return const Color(0xFFEF4444);
    } else if (crowdLevel == 'Medium') {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFF22C55E);
    }
  }

  // Expands or hides the available buses section for one trip card.
  void handleMainTrackTap(int index) {
    setState(() {
      showBuses[index] = !(showBuses[index] ?? false);
    });
  }

  // Opens the correct tracker page depending on the selected route.
  // Each route has its own tracker screen, so we use if/else to choose the right one.
  void openTrackerPage({required int tripIndex, required ActiveTrip trip}) {
    if (selectedRoute == 'Debbieh to Beirut') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BusTrackerReversePage(
                routeTitle: '$selectedRoute - ${trip.busName}',
                busTime: currentTrips[tripIndex],
                tripId: trip.id,
              ),
        ),
      );
    } else if (selectedRoute == 'Debbieh to Saida') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BusTrackerDebbiehSaidaPage(
                routeTitle: '$selectedRoute - ${trip.busName}',
                busTime: currentTrips[tripIndex],
                tripId: trip.id,
              ),
        ),
      );
    } else if (selectedRoute == 'Saida to Debbieh') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BusTrackerSaidaDebbiehPage(
                routeTitle: '$selectedRoute - ${trip.busName}',
                busTime: currentTrips[tripIndex],
                tripId: trip.id,
              ),
        ),
      );
    } else if (selectedRoute == 'Beirut to Saida') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BusTrackerBeirutSaidaPage(
                routeTitle: '$selectedRoute - ${trip.busName}',
                busTime: currentTrips[tripIndex],
                tripId: trip.id,
              ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BusTrackerPage(
                routeTitle: '$selectedRoute - ${trip.busName}',
                busTime: currentTrips[tripIndex],
                tripId: trip.id,
              ),
        ),
      );
    }
  }

  // Builds the small bus row that appears under a trip when the user taps Track.
  // It shows the bus name, FULL label if needed, and the Track button.
  Widget buildBusBox({required int tripIndex, required ActiveTrip trip}) {
    // If the bus is full, the Track button will be disabled.
    final bool isFull = trip.isFull;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDFE4EA), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              trip.busName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isFull ? const Color(0xFF98A2B3) : const Color(0xFF101828),
              ),
            ),
          ),
          if (isFull)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text(
                'FULL',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ElevatedButton(
            onPressed:
                isFull
                    ? null
                    : () {
                      openTrackerPage(tripIndex: tripIndex, trip: trip);
                    },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor:
                  isFull ? const Color(0xFFF2F4F7) : const Color(0xFF2F80ED),
              foregroundColor: isFull ? const Color(0xFF98A2B3) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isFull ? 'Full' : 'Track',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Builds one trip card in the list of today's trips.
  // It shows the trip time, status, crowd level, and expandable active buses.
  Widget buildTripCard(int index) {
    // The first trip card is treated as active.
    final bool isActive = index == 0;
    // Get the crowd level text for this trip card.
    final String crowdLevel = getCrowdLevel(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF2F6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      currentTrips[index],
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? const Color(0xFFEAF2FF)
                                : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        getStatus(index),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: getStatusColor(index),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () {
                          handleMainTrackTap(index);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF2F80ED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(
                          (showBuses[index] ?? false) ? 'Hide' : 'Track',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: Color(0xFF98A2B3),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'CROWD LEVEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: getCrowdColor(crowdLevel),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      crowdLevel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF344054),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showBuses[index] == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Buses',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<ActiveTrip>>(
                    stream: firestoreService.getActiveTripsForRouteAndTime(
                      route: selectedRoute,
                      tripTime: currentTrips[index],
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Error loading buses',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      final trips = snapshot.data ?? [];

                      if (trips.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No active buses yet',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children:
                            trips.map((trip) {
                              return buildBusBox(tripIndex: index, trip: trip);
                            }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Builds the full UI of the student home screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yalla BAU',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                getTodayDate(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF667085),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Listens to unread notification count and updates the badge automatically.
                        StreamBuilder<int>(
                          stream: notificationService.unreadCountStream(),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NotificationScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Color(0xFF2F80ED),
                                      size: 23,
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2F80ED),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              unreadCount > 9
                                                  ? '9+'
                                                  : '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDFE4EA)),
                      ),
                      child: // Removes the default underline from the dropdown to keep the custom design clean.
                          DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRoute,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF344054),
                          ),
                          items:
                              routes.map((route) {
                                return DropdownMenuItem<String>(
                                  value: route,
                                  child: Text(route),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              changeRoute(value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Today's Trips",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: refreshTrips,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 17,
                                color: Color(0xFF2F80ED),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Refresh',
                                style: TextStyle(
                                  color: Color(0xFF2F80ED),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Build one trip card for each trip time in the selected route.
                    ...List.generate(currentTrips.length, (index) {
                      return buildTripCard(index);
                    }),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF7FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD6EBFF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9ECFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF2F80ED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Selected route: $selectedRoute\nNotifications keep checking in the background while you stay inside the student side of the app.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: Color(0xFF475467),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEF2F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomItem(
                    icon: Icons.home_filled,
                    label: 'Home',
                    isSelected: true,
                    onTap: () {},
                  ),
                  _bottomItem(
                    icon: Icons.notifications,
                    label: 'Notifications',
                    isSelected: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  _bottomItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isSelected: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ProfileScreen(selectedRoute: selectedRoute),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable widget for one item in the bottom navigation bar.
  Widget _bottomItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? const Color(0xFF2F80ED)
                      : const Color(0xFF98A2B3),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    isSelected
                        ? const Color(0xFF2F80ED)
                        : const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
