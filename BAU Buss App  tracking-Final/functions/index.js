const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const routeStops = {
  'Beirut to Debbieh': ['Beirut', 'Choueifat', 'Khaldeh', 'Damour', 'Debbieh'],
  'Debbieh to Beirut': ['Debbieh', 'Damour', 'Khaldeh', 'Choueifat', 'Beirut'],
  'Debbieh to Saida': ['Debbieh', 'Damour', 'Jiyeh', 'Awali', 'Sahet El Nejmeh'],
  'Saida to Debbieh': ['Sahet El Nejmeh', 'Awali', 'Jiyeh', 'Damour', 'Debbieh'],
  'Beirut to Saida': ['Beirut', 'Khaldeh', 'Damour', 'Awali', 'Sahet El Nejmeh'],
};

exports.sendTripProgressNotifications = onDocumentUpdated(
  'activeTrips/{tripId}',
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    if (!beforeData || !afterData) return;

    const beforeIndex = Number(beforeData.currentStopIndex ?? 0);
    const afterIndex = Number(afterData.currentStopIndex ?? 0);

    if (afterIndex === beforeIndex) {
      logger.info('Trip stop index did not change.');
      return;
    }

    const route = String(afterData.route || '');
    const stops = routeStops[route];
    if (!stops || stops.length === 0) {
      logger.info(`No stops configured for route: ${route}`);
      return;
    }

    const tripId = event.params.tripId;
    const activeUsersSnapshot = await admin
      .firestore()
      .collection('users')
.where('role', '==', 'student')
      .where('selectedRoute', '==', route)
      .get();

    const sendPromises = [];

    for (const userDoc of activeUsersSnapshot.docs) {
      const userData = userDoc.data() || {};
      const pushNotifications = userData.pushNotifications !== false;
      if (!pushNotifications) {
        continue;
      }

      const selectedStop = String(userData.selectedStop || '');
      const selectedStopIndex = stops.indexOf(selectedStop);
      const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];

      if (selectedStopIndex === -1 || tokens.length === 0) {
        continue;
      }

      const userRef = admin.firestore().collection('users').doc(userDoc.id);
      const notificationsRef = userRef.collection('notifications');

      const jobs = [];

      const reachedNearStop =
        selectedStopIndex > 0 &&
        beforeIndex < selectedStopIndex - 1 &&
        afterIndex >= selectedStopIndex - 1 &&
        afterIndex < selectedStopIndex;

      if (reachedNearStop) {
        jobs.push(
          createAndSendNotification({
            userRef,
            notificationsRef,
            tokens,
            notificationId: `${tripId}_near_${selectedStop}`,
            title: 'Bus is near your stop',
            body: `Your bus is now near ${selectedStop}. Please get ready.`,
            type: 'near_stop',
            route,
            tripId,
          })
        );
      }

      const arrivalAlerts = userData.arrivalAlerts !== false;
      const reachedDestination =
        arrivalAlerts && beforeIndex < selectedStopIndex && afterIndex >= selectedStopIndex;

      if (reachedDestination) {
        jobs.push(
          createAndSendNotification({
            userRef,
            notificationsRef,
            tokens,
            notificationId: `${tripId}_arrived_${selectedStop}`,
            title: 'You arrived at your destination',
            body: `The bus has reached ${selectedStop}.`,
            type: 'destination_arrived',
            route,
            tripId,
          })
        );
      }

      sendPromises.push(...jobs);
    }

    await Promise.all(sendPromises);
  }
);

async function createAndSendNotification({
  userRef,
  notificationsRef,
  tokens,
  notificationId,
  title,
  body,
  type,
  route,
  tripId,
}) {
  const notificationDoc = notificationsRef.doc(notificationId);
  const existing = await notificationDoc.get();

  if (!existing.exists) {
    await notificationDoc.set({
      title,
      body,
      type,
      route,
      tripId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  const message = {
    notification: { title, body },
    data: {
      type: String(type),
      route: String(route),
      tripId: String(tripId),
      notificationId: String(notificationId),
    },
    tokens,
    android: {
      priority: 'high',
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  logger.info(`Sent ${type} to ${response.successCount} device(s).`);

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (!result.success) {
      const code = result.error?.code || '';
      logger.error('FCM send error', result.error);
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[index]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  }
}
