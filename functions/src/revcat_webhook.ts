import { https } from 'firebase-functions/v2';
import { firestore } from './firebase.js';
import admin from './firebase.js';
import * as functions from 'firebase-functions';

export const revenueCatWebhook = https.onRequest(async (req, res) => {
  try {
    const secret = process.env.REVENUECAT_WEBHOOK_SECRET || functions.config().revenuecat?.webhook_secret;
    const authHeader = req.headers.authorization;

    if (!secret || authHeader !== `Bearer ${secret}`) {
      console.warn('❌ Unauthorised webhook attempt');
      res.status(403).send('Forbidden');
      return;
    }

    const event = req.body;
    const { event: eventType, app_user_id, aliases, ...data } = event;

    const uid = app_user_id || aliases?.[0];
    const entitlement = data.entitlement_id || data.entitlement_ids?.[0];

    console.log(`📦 RevenueCat event received: ${eventType} for user ${uid ?? 'unknown'} (entitlement: ${entitlement})`);

    // 🧠 Log the webhook event to Firestore
    await firestore.collection('logs').doc().set({
      source: 'revcat_webhook',
      uid: uid ?? null,
      eventType: eventType ?? 'unknown',
      entitlement: entitlement ?? null,
      environment: data.environment ?? 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      rawPayload: event,
    });

    if (!uid) {
      console.error('❌ Missing user ID in webhook payload:', event);
      res.status(400).send('Missing user ID');
      return;
    }

    const userRef = firestore.doc(`users/${uid}`);

    switch (eventType) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'TRIAL_STARTED':
        if (entitlement) {
          await userRef.set(
            {
              subscription: {
                tier: entitlement,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            },
            { merge: true }
          );
          console.log(`✅ Entitlement "${entitlement}" synced for ${uid}`);
        }
        break;

      case 'CANCELLATION':
      case 'NON_RENEWING_PURCHASE':
      case 'UNCANCELLATION':
      case 'EXPIRATION':
      case 'TRIAL_CONVERTED':
      case 'TRIAL_EXPIRED':
        await userRef.set(
          {
            subscription: {
              tier: 'free',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
        console.log(`🔄 Downgraded to "free" tier for ${uid}`);
        break;

      default:
        console.log(`ℹ️ No action taken for event type: ${eventType}`);
    }

    res.status(200).send('OK');
    return;
  } catch (err) {
    console.error('❌ RevenueCat Webhook error:', err);
    res.status(500).send('Internal Server Error');
  }
});