import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'active_trip_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'app_constants.dart';

class BusTrackerReversePage extends StatefulWidget {
  final String routeTitle;
  final String busTime;
  final String tripId;

  const BusTrackerReversePage({
    super.key,
    required this.routeTitle,
    required this.busTime,
    required this.tripId,
  });

  @override
  State<BusTrackerReversePage> createState() => _BusTrackerReversePageState();
}

class _BusTrackerReversePageState extends State<BusTrackerReversePage> {
  StreamSubscription<ActiveTrip?>? _tripSubscription;
  final FirestoreService firestoreService = FirestoreService();
  final NotificationService notificationService = NotificationService();

  double busProgress = 0.02;
  int passengerCount = 0;
  int maxCapacity = busMaxCapacity;
  int _lastSyncedStopIndex = -1;
  bool _hasClosedForEndedTrip = false;
  bool hasReachedDestination = false;
  bool hasShownFullDialog = false;
  bool _isFullDialogShowing = false;
  bool hasShownNearStopNotification = false;
  bool hasShownDestinationNotification = false;

  final List<_StopModel> stops = const [
    _StopModel(name: 'Debbieh', progress: 0.00, minuteFromStart: 0),
    _StopModel(name: 'Damour', progress: 0.25, minuteFromStart: 15),
    _StopModel(name: 'Khaldeh', progress: 0.50, minuteFromStart: 20),
    _StopModel(name: 'Choueifat', progress: 0.75, minuteFromStart: 30),
    _StopModel(name: 'Beirut', progress: 1.00, minuteFromStart: 40),
  ];

  static const double _row1Height = 120;
  static const double _row2Height = 84;
  static const double _row3Height = 108;
  static const double _row4Height = 126;
  static const double _row5Height = 112;

  static const double _timelineLeftWidth = 126;
  static const double _lineX = 24;
  static const double _dotSize = 14;
  static const double _bigDotSize = 18;
  static const double _busSize = 34;

  List<double> get _rowHeights => const [
    _row1Height,
    _row2Height,
    _row3Height,
    _row4Height,
    _row5Height,
  ];

  List<double> get _stopCenters {
    final heights = _rowHeights;
    double sum = 0;
    final centers = <double>[];
    for (final h in heights) {
      centers.add(sum + 22);
      sum += h;
    }
    return centers;
  }

  double get _timelineHeight => _rowHeights.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _listenToActiveTrip();
  }

  void _listenToActiveTrip() {
    _tripSubscription = firestoreService
        .getSingleTrip(tripId: widget.tripId)
        .listen((trip) {
          if (!mounted) { // Added braces to satisfy the curly-braces lint.
            return;
          }

          if (trip == null) {
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

          final int currentStopIndex =
              trip.currentStopIndex.clamp(0, stops.length - 1).toInt();
          final double liveProgress =
              (trip.progressPercent / 100).clamp(0.0, 1.0).toDouble();

          final bool capacityChanged =
              trip.passengerCount != passengerCount ||
              trip.maxCapacity != maxCapacity;

          if (currentStopIndex == _lastSyncedStopIndex &&
              liveProgress == busProgress &&
              !capacityChanged) {
            return;
          }

          final bool stopChanged = currentStopIndex != _lastSyncedStopIndex;

          setState(() {
            _lastSyncedStopIndex = currentStopIndex;
            busProgress = liveProgress;
            passengerCount = trip.passengerCount;
            maxCapacity = trip.maxCapacity;
            hasReachedDestination =
                trip.status == 'completed' ||
                currentStopIndex >= stops.length - 1;
          });

          if (stopChanged) {
            checkAndSendNotifications(currentStopIndex: currentStopIndex);
          }
        });
  }

  void _showBusFullDialogOnce() {
    if (hasShownFullDialog || _isFullDialogShowing || !mounted) { // Added braces to satisfy the curly-braces lint.
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
        if (mounted) {
          _isFullDialogShowing = false;
        }
      });
    });
  }

  void _closeTrackerForEndedTrip() {
    if (_hasClosedForEndedTrip || !mounted) { // Added braces to satisfy the curly-braces lint.
      return;
    }

    _hasClosedForEndedTrip = true;
    Future.microtask(() {
      if (!mounted) { // Added braces to satisfy the curly-braces lint.
        return;
      }

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  int getCurrentStopIndex() {
    for (int i = stops.length - 1; i >= 0; i--) {
      if (busProgress >= stops[i].progress) {
        return i;
      }
    }
    return 0;
  }

  _StopModel get currentStop {
    for (int i = 0; i < stops.length - 1; i++) {
      if (busProgress >= stops[i].progress &&
          busProgress < stops[i + 1].progress) {
        return stops[i];
      }
    }
    return stops.last;
  }

  _StopModel get nextStop {
    if (hasReachedDestination) { // Added braces to satisfy the curly-braces lint.
      return stops.last;
    }

    for (int i = 0; i < stops.length - 1; i++) {
      if (busProgress < stops[i + 1].progress) {
        return stops[i + 1];
      }
    }
    return stops.last;
  }

  String get currentLocationText {
    if (hasReachedDestination) { // Added braces to satisfy the curly-braces lint.
      return stops.last.name;
    }
    return currentStop.name;
  }

  String get nextStopDistanceText {
    if (hasReachedDestination) { // Added braces to satisfy the curly-braces lint.
      return 'Arrived';
    }

    final double start = currentStop.progress;
    final double end = nextStop.progress;
    final double section = end - start;
    final double remaining = (end - busProgress) / section;
    final double km = 0.4 + (remaining * 2.0);

    return '${km.toStringAsFixed(1)} km away';
  }

  int _minutesFromStartAtProgress(double progressValue) {
    for (int i = 0; i < stops.length - 1; i++) {
      final startStop = stops[i];
      final endStop = stops[i + 1];

      if (progressValue >= startStop.progress &&
          progressValue <= endStop.progress) {
        final localT =
            (progressValue - startStop.progress) /
            (endStop.progress - startStop.progress);

        final minutes =
            lerpDouble(
              startStop.minuteFromStart.toDouble(),
              endStop.minuteFromStart.toDouble(),
              localT,
            )!;

        return minutes.round();
      }
    }

    return stops.last.minuteFromStart;
  }

  int get currentMinuteFromStart => _minutesFromStartAtProgress(busProgress);

  int get nextStopEtaMinutes {
    if (hasReachedDestination) { // Added braces to satisfy the curly-braces lint.
      return 0;
    }
    final eta = nextStop.minuteFromStart - currentMinuteFromStart;
    return eta < 0 ? 0 : eta;
  }

  int get destinationEtaMinutes {
    final eta = stops.last.minuteFromStart - currentMinuteFromStart;
    return eta < 0 ? 0 : eta;
  }

  bool isPassed(_StopModel stop) => busProgress >= stop.progress;

  bool isHighlighted(_StopModel stop) {
    if (hasReachedDestination && stop.name == stops.last.name) { // Added braces to satisfy the curly-braces lint.
      return true;
    }
    return nextStop.name == stop.name;
  }

  double get _busCenterY {
    final centers = _stopCenters;

    for (int i = 0; i < stops.length - 1; i++) {
      final startStop = stops[i];
      final endStop = stops[i + 1];

      if (busProgress >= startStop.progress &&
          busProgress <= endStop.progress) {
        final localT =
            (busProgress - startStop.progress) /
            (endStop.progress - startStop.progress);

        return lerpDouble(centers[i], centers[i + 1], localT)!;
      }
    }

    return centers.last;
  }

  Color getCapacityColor(int passengerCount, int maxCapacity) {
    if (passengerCount >= maxCapacity) {
      return const Color(0xFFEF4444);
    } else if (passengerCount >= (maxCapacity - 10)) {
      return const Color(0xFFF79009);
    } else {
      return const Color(0xFF22C55E);
    }
  }

  String getCapacityLabel(int passengerCount, int maxCapacity) {
    if (passengerCount >= maxCapacity) {
      return 'FULL';
    } else if (passengerCount >= (maxCapacity - 10)) {
      return 'BUSY';
    } else {
      return 'AVAILABLE';
    }
  }

  Future<void> checkAndSendNotifications({
    required int currentStopIndex,
  }) async {
    final settings = await notificationService.getSettings();

    if (!mounted) { // Added braces to satisfy the curly-braces lint.
      return;
    }
    if (!settings.pushNotifications) { // Added braces to satisfy the curly-braces lint.
      return;
    }

    final int selectedStopIndex = stops.indexWhere(
      (stop) => stop.name == settings.selectedStop,
    );

    if (selectedStopIndex == -1) { // Added braces to satisfy the curly-braces lint.
      return;
    }

    final double selectedStopProgress = stops[selectedStopIndex].progress;
    const double nearThreshold = 0.08;

    if (!hasShownNearStopNotification &&
        selectedStopIndex > 0 &&
        busProgress >= (selectedStopProgress - nearThreshold) &&
        busProgress < selectedStopProgress) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${widget.tripId}_near_${settings.selectedStop}',
        title: 'Bus is near your stop',
        body:
            'Your bus is now near ${settings.selectedStop}. Please get ready.',
        type: 'near_stop',
        route: widget.routeTitle,
        tripId: widget.tripId,
      );

      hasShownNearStopNotification = true;
    }

    if (!hasShownDestinationNotification &&
        settings.arrivalAlerts &&
        busProgress >= selectedStopProgress) {
      await notificationService.createNotificationIfAllowed(
        notificationId: '${widget.tripId}_arrived_${settings.selectedStop}',
        title: 'Be Ready!',
        body: 'The bus has reached ${settings.selectedStop}.',
        type: 'destination_arrived',
        route: widget.routeTitle,
        tripId: widget.tripId,
        requireArrivalAlerts: true,
      );

      hasShownDestinationNotification = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF101828),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Yalla BAU',
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
      top: centerY - 12,
      right: 0,
      child: SizedBox(
        height: 24,
        child: Row(
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
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                stop.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: highlighted ? 13 : 12,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                  color:
                      highlighted
                          ? const Color(0xFF2F80ED)
                          : const Color(0xFF98A2B3),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101828),
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
              Text(
                nextStopDistanceText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F80ED),
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
                  style: const TextStyle(
                    fontSize: 12,
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CAPACITY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF98A2B3),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: capacityColor.withValues(alpha: 0.12), // Replaced deprecated withOpacity with withValues.
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  capacityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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
                const TextSpan(text: ''),
                TextSpan(
                  text: '$passengerCount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: capacityColor,
                  ),
                ),
                TextSpan(
                  text: ' /$maxCapacity',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEAECF0),
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

class _StopModel {
  final String name;
  final double progress;
  final int minuteFromStart;

  const _StopModel({
    required this.name,
    required this.progress,
    required this.minuteFromStart,
  });
}
