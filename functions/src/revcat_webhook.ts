import { https } from 'firebase-functions/v2';
import { firestore } from './firebase.js';
import admin from './firebase.js';
import * as functions from 'firebase-functions';

// 🧭 Maps RevenueCat product identifiers → internal tiers
const ENTITLEMENT_TIER_MAP: Record<string, 'home_chef' | 'master_chef'> = {
  home_chef_monthly: 'home_chef',
  master_chef_monthly: 'master_chef',
  master_chef_yearly: 'master_chef',
};

// Internal union incl. “no access”
type TierOrNone = 'home_chef' | 'master_chef' | 'none';

export const revenueCatWebhook = https.onRequest(async (req, res) => {
  try {
    // Basic CORS (adjust as needed)
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Headers', 'authorization, content-type');
      res.status(204).send('');
      return;
    }

    // 🔐 Verify secret
    const secret =
      process.env.REVENUECAT_WEBHOOK_SECRET ||
      functions.config().revenuecat?.webhook_secret;
    const authHeader = req.headers.authorization;

    if (!secret || authHeader !== `Bearer ${secret}`) {
      console.warn('❌ Unauthorised webhook attempt');
      res.status(403).send('Forbidden');
      return;
    }

    const event = req.body ?? {};
    const {
      event: eventType,
      app_user_id,
      aliases,
      ...data
    } = event as any;

    const uid: string | undefined = app_user_id || aliases?.[0];

    // RevenueCat may send a single entitlement or an array depending on event
    const entitlementId: string | undefined =
      data?.entitlement_id || data?.entitlement_ids?.[0];

    // Map entitlement → internal tier, default to “none”
    const resolvedTier: TierOrNone =
      (entitlementId && ENTITLEMENT_TIER_MAP[entitlementId]) || 'none';

    console.log(
      `📦 RevenueCat event: ${eventType ?? 'unknown'} | uid=${uid ?? 'unknown'} | entitlement=${entitlementId ?? 'n/a'} → tier=${resolvedTier}`
    );

    // 🧠 Log raw webhook for audit/debug
    await firestore.collection('logs').doc().set({
      source: 'revcat_webhook',
      uid: uid ?? null,
      eventType: eventType ?? 'unknown',
      entitlement: entitlementId ?? null,
      resolvedTier,
      environment: data?.environment ?? 'unknown',
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
      // ✅ Events that should set/refresh the paid tier
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'TRIAL_STARTED':
      case 'TRIAL_CONVERTED':
      case 'UNCANCELLATION': {
        // If no entitlement (or unmapped), don’t overwrite to “none” on an upgrade-ish event
        if (!entitlementId || resolvedTier === 'none') {
          console.warn(
            `⚠️ ${eventType}: missing or unmapped entitlementId → leaving user tier unchanged`
          );
          break;
        }
        await userRef.set(
          {
            tier: resolvedTier,           // 'home_chef' | 'master_chef'
            entitlementId,                // keep the concrete product id
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        console.log(`✅ Tier "${resolvedTier}" synced to Firestore for ${uid}`);
        break;
      }

      // 🔻 Events that should remove access (hard gate → "none")
      case 'CANCELLATION':
      case 'NON_RENEWING_PURCHASE':
      case 'EXPIRATION':
      case 'TRIAL_EXPIRED': {
        await userRef.set(
          {
            tier: 'none',
            entitlementId: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        console.log(`🔄 Downgraded to "none" for ${uid}`);
        break;
      }

      // ℹ️ Informational / no-op events
      case 'BILLING_ISSUE':
      case 'SUBSCRIBER_ALIAS':
      default: {
        console.log(`ℹ️ No tier action taken for event type: ${eventType}`);
      }
    }

    res.status(200).send('OK');
  } catch (err) {
    console.error('❌ RevenueCat Webhook error:', err);
    res.status(500).send('Internal Server Error');
  }
});