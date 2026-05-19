import 'dart:async'; // Used for timers and real-time updates (like listening to Firebase data)
import 'dart:ui'
    show lerpDouble; // Used for smooth animations (for moving the bus smoothly)
import 'package:flutter/material.dart'; // Main Flutter UI package (widgets, design, screens)
import 'active_trip_model.dart';
import 'firestore_service.dart'; // Handles all Firebase Firestore operations (start trip, update..)
import 'notification_service.dart';
import 'app_constants.dart';

// This is the main widget for tracking a bus on the Beirut → Saida route
class BusTrackerBeirutSaidaPage extends StatefulWidget {
  final String routeTitle;
  final String busTime;
  final String tripId;
  //This is constructor where When the user clicks Track, the app takes the route and time of that bus and sends it to the tracking page.
  const BusTrackerBeirutSaidaPage({
    super.key,
    required this.routeTitle,
    required this.busTime,
    required this.tripId,
  });
  // Creates the state object that controls this screen (logic + UI updates)
  @override
  State<BusTrackerBeirutSaidaPage> createState() =>
      _BusTrackerBeirutSaidaPageState();
}

class _BusTrackerBeirutSaidaPageState extends State<BusTrackerBeirutSaidaPage> {
  // Holds a real-time listener to Firebase so the app can receive trip updates (like start, progress, or end)
  StreamSubscription<ActiveTrip?>? _tripSubscription;
  // Used to get and update trip data from Firebase
  final FirestoreService firestoreService = FirestoreService();
  final NotificationService notificationService = NotificationService();

  double busProgress = 0.02;
  int passengerCount = 0;
  int maxCapacity = busMaxCapacity;
  int _lastSyncedStopIndex =
      -1; // Keeps track of last processed stop to avoid repeating updates or notifications
  bool _hasClosedForEndedTrip = false;
  bool hasReachedDestination = false;
  bool hasShownFullDialog =
      false; // Prevents showing "bus full" dialog more than once
  bool _isFullDialogShowing = false;
  bool hasShownNearStopNotification =
      false; // Prevents sending "near stop" notification multiple times
  bool hasShownDestinationNotification = false;
  // Prevents sending "destination reached" notification multiple times
  // List of stops for this route with their position and timing
  final List<_StopModel> stops = const [
    _StopModel(
      name: 'Beirut',
      progress: 0.00,
      minuteFromStart: 0,
    ), // First stop (starting point)
    // Second stop (25% of the route, 15 minutes from start)
    _StopModel(name: 'Khaldeh', progress: 0.25, minuteFromStart: 15),
    _StopModel(name: 'Damour', progress: 0.50, minuteFromStart: 28),
    _StopModel(name: 'Awali', progress: 0.75, minuteFromStart: 40),
    _StopModel(name: 'Sahet El Nejmeh', progress: 1.00, minuteFromStart: 50),
  ];

  //control spacing/layout of stops on the line
  static const double _row1Height = 120;
  static const double _row2Height = 84;
  static const double _row3Height = 108;
  static const double _row4Height = 126;
  static const double _row5Height = 112;
  //styling of the bus line
  static const double _timelineLeftWidth = 145;
  static const double _lineX = 24;
  static const double _dotSize = 12;
  static const double _bigDotSize = 16;
  static const double _busSize = 32;
  //getter for the heights
  List<double> get _rowHeights => const [
    _row1Height,
    _row2Height,
    _row3Height,
    _row4Height,
    _row5Height,
  ];

  // Calculates the vertical positions of each stop on the screen
  List<double> get _stopCenters {
    // Get heights of all rows (UI spacing)
    final heights = _rowHeights;

    // Used to keep track of total height while looping
    double sum = 0;

    // List to store center positions of each stop
    final centers = <double>[];

    // Loop through each row height
    for (final h in heights) {
      // Add the center position for this stop
      centers.add(sum + 22);

      // Move down by this row height
      sum += h;
    }

    // Return all stop positions
    return centers;
  }

  // Calculates the total height of the timeline by adding all row heights
  double get _timelineHeight => _rowHeights.reduce((a, b) => a + b);

  @override
  // Called once when the screen is first opened
  void initState() {
    super.initState();
    _listenToActiveTrip();
  }

  // Start listening to trip updates from Firebase
  void _listenToActiveTrip() {
    // Subscribe to trip data from Firebase using the trip ID
    _tripSubscription = firestoreService.getSingleTrip(tripId: widget.tripId)
    // This runs every time the trip data changes
    .listen((trip) {
      // If the screen is no longer active, stop doing anything
      if (!mounted) {
        return;
      }
      // If no trip is found (it was deleted or ended)
      if (trip == null) {
        // Close the tracking screen
        _closeTrackerForEndedTrip();
        return;
      }

      final tripStatus = trip.status.trim().toLowerCase();
      if (tripStatus == 'completed' || tripStatus == 'ended') {
        _closeTrackerForEndedTrip();
        return;
      }

      if (trip.isFull) {
        _showBusFullDialogOnce();
      } else {
        hasShownFullDialog = false;
      }
      // Makes sure the stop number stays between the first and last stop (so it doesn’t go out of range)
      final int currentStopIndex =
          trip.currentStopIndex.clamp(0, stops.length - 1).toInt();
      // Converts % to 0–1 and prevents invalid values
      final double liveProgress =
          (trip.progressPercent / 100).clamp(0.0, 1.0).toDouble();
      // Checks if passenger count or max capacity has changed
      final bool capacityChanged =
          trip.passengerCount != passengerCount ||
          trip.maxCapacity != maxCapacity;
      // If nothing changed, skip updating
      if (currentStopIndex == _lastSyncedStopIndex &&
          liveProgress == busProgress &&
          !capacityChanged) {
        return;
      }
      //It checks: “Did the bus reach a new stop?”
      //If yes → true
      //If still same stop → false
      final bool stopChanged = currentStopIndex != _lastSyncedStopIndex;

      //update UI if bus moves, capacity changes...
      setState(() {
        _lastSyncedStopIndex = currentStopIndex;
        busProgress = liveProgress;
        passengerCount = trip.passengerCount;
        maxCapacity = trip.maxCapacity;
        hasReachedDestination =
            trip.status == 'completed' || currentStopIndex >= stops.length - 1;
      });

      //make sure to keep everything updated if stop gets updated
      if (stopChanged) {
        checkAndSendNotifications(currentStopIndex: currentStopIndex);
      }
    });
  }

  // if the driver presses bus is full show dialog box of that if not don't show anything
  void _showBusFullDialogOnce() {
    if (hasShownFullDialog || _isFullDialogShowing || !mounted) {
      // Added braces to satisfy the curly-braces lint.
      return;
    }

    hasShownFullDialog = true;
    _isFullDialogShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isFullDialogShowing = false;
        return;
      }
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Bus is full',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: const Text(
                'This bus is now full. You can go back and choose another available bus.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      ).then((_) {
        // After the dialog is closed, mark that it is no longer showing
        if (mounted) {
          _isFullDialogShowing = false;
        }
      });
    });
  }

  //close the tracking screen if the driver ends the trip
  void _closeTrackerForEndedTrip() {
    if (_hasClosedForEndedTrip || !mounted) {
      return;
    }

    _hasClosedForEndedTrip = true;
    Future.microtask(() {
      //Run this after the current code finished to avoid errors and inorder to run the code smoothly
      if (!mounted) {
        return;
      }
      // Get the navigator (used to move between screens)
      final navigator = Navigator.of(context);
      // If there is a screen to go back to, close the current screen
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  @override
  void dispose() {
    _tripSubscription
        ?.cancel(); // cancel the stream subscription to avoid memory leaks
    super.dispose(); // call parent dispose
  }

  int getCurrentStopIndex() {
    // loop from last stop to first
    for (int i = stops.length - 1; i >= 0; i--) {
      // if current bus progress reached this stop
      if (busProgress >= stops[i].progress) {
        return i; // return this stop index
      }
    }
    return 0; // default to first stop
  }

  _StopModel get currentStop {
    // loop through stops to find current section
    for (int i = 0; i < stops.length - 1; i++) {
      if (busProgress >= stops[i].progress &&
          busProgress < stops[i + 1].progress) {
        return stops[i]; // return current stop
      }
    }
    return stops.last; // if beyond all, return last stop
  }

  _StopModel get nextStop {
    if (hasReachedDestination) {
      return stops.last; // if reached destination, next = last
    }

    // find next stop based on progress
    for (int i = 0; i < stops.length - 1; i++) {
      if (busProgress < stops[i + 1].progress) {
        return stops[i + 1]; // next stop
      }
    }
    return stops.last; // fallback
  }

  String get nextStopDistanceText {
    if (hasReachedDestination) {
      return 'Arrived'; // already arrived
    }

    final double start = currentStop.progress; // start progress of current stop
    final double end = nextStop.progress; // end progress of next stop
    final double section = end - start; // section length
    final double remaining =
        (end - busProgress) / section; // remaining percentage
    final double km = 0.4 + (remaining * 2.2); // calculate estimated distance

    return '${km.toStringAsFixed(1)} km away'; // return formatted text
  }

  int _minutesFromStartAtProgress(double progressValue) {
    // loop through stops
    for (int i = 0; i < stops.length - 1; i++) {
      final startStop = stops[i]; // current segment start
      final endStop = stops[i + 1]; // current segment end

      // check if progress lies between these stops
      if (progressValue >= startStop.progress &&
          progressValue <= endStop.progress) {
        final localT =
            (progressValue - startStop.progress) /
            (endStop.progress - startStop.progress); // normalize progress

        final minutes =
            lerpDouble(
              startStop.minuteFromStart.toDouble(),
              endStop.minuteFromStart.toDouble(),
              localT,
            )!; // interpolate minutes

        return minutes.round(); // return rounded minutes
      }
    }

    return stops.last.minuteFromStart; // fallback to last stop time
  }

  int get currentMinuteFromStart => _minutesFromStartAtProgress(busProgress);
  // get current minutes from start using bus progress

  int get nextStopEtaMinutes {
    if (hasReachedDestination) {
      return 0; // no ETA if arrived
    }
    final eta =
        nextStop.minuteFromStart -
        currentMinuteFromStart; // calculate difference
    return eta < 0 ? 0 : eta; // avoid negative values
  }

  int get destinationEtaMinutes {
    final eta =
        stops.last.minuteFromStart -
        currentMinuteFromStart; // time until final stop
    return eta < 0 ? 0 : eta; // avoid negative values
  }

  bool isPassed(_StopModel stop) => busProgress >= stop.progress;
  // check if bus already passed a stop

  bool isHighlighted(_StopModel stop) {
    if (hasReachedDestination && stop.name == stops.last.name) {
      // highlight last stop if destination reached
      return true;
    }
    return nextStop.name == stop.name; // otherwise highlight next stop
  }

  double get _busCenterY {
    final centers = _stopCenters; // UI positions of stops

    // find correct segment for interpolation
    for (int i = 0; i < stops.length - 1; i++) {
      final startStop = stops[i];
      final endStop = stops[i + 1];

      if (busProgress >= startStop.progress &&
          busProgress <= endStop.progress) {
        final localT =
            (busProgress - startStop.progress) /
            (endStop.progress - startStop.progress); // normalize

        return lerpDouble(centers[i], centers[i + 1], localT)!;
        // interpolate Y position of bus
      }
    }

    return centers.last; // fallback position
  }

  Color getCapacityColor(int passengerCount, int maxCapacity) {
    if (passengerCount >= maxCapacity) {
      return const Color(0xFFEF4444); // red = full
    } else if (passengerCount >= (maxCapacity - 10)) {
      return const Color(0xFFF79009); // orange = busy
    } else {
      return const Color(0xFF22C55E); // green = available
    }
  }

  String getCapacityLabel(int passengerCount, int maxCapacity) {
    if (passengerCount >= maxCapacity) {
      return 'FULL'; // bus full
    } else if (passengerCount >= (maxCapacity - 10)) {
      return 'BUSY'; // nearly full
    } else {
      return 'AVAILABLE'; // free seats
    }
  }

  Future<void> checkAndSendNotifications({
    required int currentStopIndex,
  }) async {
    final settings =
        await notificationService.getSettings(); // get user settings

    if (!mounted) {
      return; // ensure widget still exists
    }
    if (!settings.pushNotifications) {
      return; // stop if notifications disabled
    }

    final int selectedStopIndex = stops.indexWhere(
      (stop) => stop.name == settings.selectedStop,
    ); // find user-selected stop

    if (selectedStopIndex == -1) {
      return; // stop not found
    }

    // notify when bus is near stop
    if (!hasShownNearStopNotification &&
        selectedStopIndex > 0 &&
        currentStopIndex >= selectedStopIndex - 1 &&
        currentStopIndex < selectedStopIndex) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${widget.tripId}_near_${settings.selectedStop}',
        title: 'Bus is near your stop',
        body:
            'Your bus is now near ${settings.selectedStop}. Please get ready.',
        type: 'near_stop',
        route: widget.routeTitle,
        tripId: widget.tripId,
      );

      hasShownNearStopNotification = true; // mark as shown
    }

    // notify when bus arrives
    if (!hasShownDestinationNotification &&
        settings.arrivalAlerts &&
        currentStopIndex >= selectedStopIndex) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${widget.tripId}_arrived_${settings.selectedStop}',
        title: 'Be Ready!',
        body: 'The bus has reached ${settings.selectedStop}.',
        type: 'destination_arrived',
        route: widget.routeTitle,
        tripId: widget.tripId,
        requireArrivalAlerts: true,
      );

      hasShownDestinationNotification = true; // mark as shown
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // page background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB), // app bar color
        elevation: 0, // no shadow
        centerTitle: true, // center title
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded, // back arrow icon
            color: Color(0xFF101828),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context), // go back
        ),
        title: const Text(
          'Yalla BAU', // app title
          style: TextStyle(
            color: Color(0xFF101828),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: Stack(
                  children: [
                    _buildFixedTimeline(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const SizedBox(height: 10),
                          _buildContentRow(
                            height: _row1Height,
                            card: _buildNextStopCard(),
                          ),
                          const SizedBox(height: 10),
                          _buildContentRow(
                            height: _row2Height,
                            card: _buildNextStopEtaCard(),
                          ),
                          const SizedBox(height: 10),
                          _buildContentRow(
                            height: _row3Height,
                            card: _buildMyStopEtaCard(),
                          ),
                          const SizedBox(height: 10),
                          _buildContentRow(
                            height: _row4Height,
                            card: _buildCapacityCard(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedTimeline() {
    final centers = _stopCenters;

    return SizedBox(
      width: _timelineLeftWidth,
      height: _timelineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _lineX - 2,
            top: centers.first,
            child: Container(
              width: 4,
              height: centers.last - centers.first,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBF6),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: _lineX - 2,
            top: centers.first,
            child: Container(
              width: 4,
              height: (_busCenterY - centers.first).clamp(0.0, 10000.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2F80ED),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          for (int i = 0; i < stops.length; i++)
            _buildFixedStop(stop: stops[i], centerY: centers[i]),
          Positioned(
            left: _lineX - (_busSize / 2) + 2,
            top: _busCenterY - (_busSize / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeInOut,
              width: _busSize,
              height: _busSize,
              decoration: BoxDecoration(
                color: const Color(0xFF2F80ED),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x332F80ED),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedStop({required _StopModel stop, required double centerY}) {
    final bool highlighted = isHighlighted(stop);
    final bool passed = isPassed(stop);

    return Positioned(
      left: 0,
      top: centerY - 24,
      right: 0,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              child: Center(
                child: Container(
                  width: highlighted ? _bigDotSize : _dotSize,
                  height: highlighted ? _bigDotSize : _dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color:
                          (highlighted || passed)
                              ? const Color(0xFF2F80ED)
                              : const Color(0xFFD0D5DD),
                      width: highlighted ? 3 : 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                stop.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: highlighted ? 10.5 : 9.5,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                  color:
                      highlighted
                          ? const Color(0xFF2F80ED)
                          : const Color(0xFF98A2B3),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentRow({required double height, Widget? card}) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(left: _timelineLeftWidth),
        child: Align(
          alignment: Alignment.topLeft,
          child: card ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildNextStopCard() {
    return _buildWhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT STOP',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextStop.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101828),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.navigation_rounded,
                size: 15,
                color: Color(0xFF2F80ED),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nextStopDistanceText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2F80ED),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextStopEtaCard() {
    return _buildWhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: Color(0xFF2F80ED),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEXT STOP ETA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF98A2B3),
                ),
              ),
              const SizedBox(height: 3),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$nextStopEtaMinutes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const TextSpan(
                      text: ' mins',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyStopEtaCard() {
    return _buildWhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF667085),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FINAL DESTINATION ETA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$destinationEtaMinutes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const Text(
                      ' mins',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Final Destination: ${stops.last.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard() {
    final double progress =
        maxCapacity == 0 ? 0 : (passengerCount / maxCapacity).clamp(0.0, 1.0);
    final Color capacityColor = getCapacityColor(passengerCount, maxCapacity);
    final String capacityLabel = getCapacityLabel(passengerCount, maxCapacity);

    return _buildWhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CAPACITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF98A2B3),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: capacityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  capacityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: capacityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$passengerCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: capacityColor,
                  ),
                ),
                TextSpan(
                  text: ' / $maxCapacity',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF2F4F7),
              valueColor: AlwaysStoppedAnimation(capacityColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: child,
    );
  }
}

// Model representing a bus stop with its details
class _StopModel {
  // Name of the stop (e.g., Beirut, Khaldeh)
  final String name;

  // Position of the stop on the route (from 0 to 1)
  final double progress;

  // Time (in minutes) from trip start to reach this stop
  final int minuteFromStart;

  // Constructor to create a stop with its data
  const _StopModel({
    required this.name,
    required this.progress,
    required this.minuteFromStart,
  });
}
