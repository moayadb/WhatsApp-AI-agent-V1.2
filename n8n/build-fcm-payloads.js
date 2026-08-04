// n8n Code node: "Build FCM Payloads"  (Mode: Run Once for All Items)
//
// Builds one FCM v1 request body per registered device.
//
// Reads the Firestore CREATE RESPONSE from 'HTTP Request1' rather than the
// pre-write body, for two reasons: only alerts that actually persisted should
// notify anyone, and the response carries the generated document id, so
// alert_id is real and the app can deep-link to it.

const AR_PRIORITY = {
  urgent: 'عاجلة',
  high: 'عالية',
  medium: 'متوسطة',
  low: 'منخفضة',
};
const AR_DEPARTMENT = {
  sales: 'المبيعات',
  operations: 'العمليات',
  delivery: 'التوصيل',
  finance: 'المالية',
  support: 'الدعم',
  management: 'الإدارة',
};

const created = $('HTTP Request1').first().json ?? {};
const f = created.fields ?? {};

// Firestore REST wraps every value: { summary: { stringValue: "..." } }.
const s = (key) => String(f[key]?.stringValue ?? '').trim();

const priority = s('priority').toLowerCase();
const department = s('department').toLowerCase();
// name is "projects/.../documents/alerts/<docId>".
const alertId = String(created.name ?? '').split('/').pop() ?? '';

// --- the three iOS notification slots -------------------------------------
// title    : how urgent, and whose problem it is
// subtitle : who is complaining
// body     : what actually happened, in the agent's own Arabic sentence
//
// summary ONLY in the body. display_text and message_content are the
// customer's verbatim words, and a notification body renders on a locked
// screen in full view of whoever is standing nearby.
const title =
  [AR_PRIORITY[priority], AR_DEPARTMENT[department]].filter(Boolean).join(' · ') ||
  'تنبيه جديد';

// display_name is guaranteed non-empty by Normalize Payload, but fall through
// anyway so a payload variation degrades instead of showing a blank line.
const subtitle = s('display_name') || s('sender_name') || s('sender_phone');

const body = s('summary') || 'تنبيه جديد يحتاج مراجعة';

// An empty subtitle key renders as a blank line on iOS, so omit it entirely.
const alert = { title, body };
if (subtitle) alert.subtitle = subtitle;

// Android has no subtitle slot, so the sender folds into the body instead.
const androidBody = subtitle ? `${subtitle}: ${body}` : body;

// Firestore REST returns { documents: [...] } and omits the key when empty.
const docs = $input.first().json?.documents ?? [];

return docs
  .map((d) => d.fields?.token?.stringValue)
  .filter(Boolean)
  .map((token) => ({
    json: {
      token,
      payload: {
        message: {
          token,
          // Cross-platform fallback. iOS ignores this in favour of aps.alert
          // below, which is the ONLY place APNs accepts a subtitle --
          // message.notification has no such field. Android overrides it via
          // the android block.
          notification: { title, body },
          apns: {
            payload: {
              aps: {
                alert,
                sound: 'default',
              },
            },
          },
          android: {
            notification: {
              // No subtitle slot on Android: sender goes into the body.
              body: androidBody,
              // Channel + icon must match what the app declares --
              // MainActivity.kt creates the channel, the manifest and
              // res/drawable/ic_stat_sanayed.xml define the icon. A channel id
              // Android doesn't know would drop alerts into the generic
              // "Miscellaneous" bucket; an unknown icon name shows a blank.
              channel_id: 'sanayed_alerts',
              icon: 'ic_stat_sanayed',
              sound: 'default',
            },
          },
          data: { alert_id: alertId, priority },
        },
      },
    },
  }));
