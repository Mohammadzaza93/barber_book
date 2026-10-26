/**
 * BarberBook — Google Form → Sheets → Firestore
 *
 * ثبّت الخصائص من Project Settings → Script properties:
 *   FIREBASE_PROJECT_ID, SHOP_ID, SERVICE_ACCOUNT_EMAIL, PRIVATE_KEY
 *
 * Trigger: onFormSubmit (From spreadsheet → On form submit)
 *
 * عدّل INDEX_* حسب ترتيب أعمدة جدول الردود (الصف 1 = عناوين).
 * العمود 1 عادة Timestamp تلقائي من Google Form.
 */

var INDEX = {
  TIMESTAMP: 1,
  NAME: 2,
  PHONE: 3,
  SERVICE: 4,
  WHEN: 5,
  NOTES: 6 // اختياري — احذف إن لم يوجد
};

var DEFAULT_DURATION_MIN = 30;

/**
 * يُستدعى تلقائياً عند كل إجابة جديدة على النموذج.
 */
function onFormSubmit(e) {
  try {
    var row;
    if (e && e.range) {
      row = e.range.getRow();
    } else {
      row = SpreadsheetApp.getActiveSheet().getLastRow();
    }
    sendRowToFirestore(row);
  } catch (err) {
    console.error('onFormSubmit failed: ' + err);
    throw err;
  }
}

/**
 * لتجربة يدوية من المحرر: أرسل آخر صف.
 */
function testLastRow() {
  var row = SpreadsheetApp.getActiveSheet().getLastRow();
  sendRowToFirestore(row);
}

function sendRowToFirestore(row) {
  var sheet = SpreadsheetApp.getActiveSheet();
  var props = PropertiesService.getScriptProperties();

  var projectId = mustProp(props, 'FIREBASE_PROJECT_ID');
  var shopId = mustProp(props, 'SHOP_ID');

  var customerName = String(sheet.getRange(row, INDEX.NAME).getValue() || '').trim();
  var phone = String(sheet.getRange(row, INDEX.PHONE).getValue() || '').trim();
  var service = String(sheet.getRange(row, INDEX.SERVICE).getValue() || '').trim();
  var whenRaw = sheet.getRange(row, INDEX.WHEN).getValue();
  var notes = '';
  try {
    notes = String(sheet.getRange(row, INDEX.NOTES).getValue() || '').trim();
  } catch (_) {}

  if (!customerName && !phone) {
    console.warn('Empty row ' + row + ', skip');
    return;
  }

  var start = parseWhen(whenRaw);
  var end = new Date(start.getTime() + DEFAULT_DURATION_MIN * 60 * 1000);
  var now = new Date();
  var ref = 'GF-' + Utilities.getUuid().replace(/-/g, '').substring(0, 6).toUpperCase();
  var docId = Utilities.getUuid().replace(/-/g, '').substring(0, 20);

  // Firestore REST document fields (متوافق مع Appointment.fromMap)
  var fields = {
    shopId: stringField(shopId),
    reference: stringField(ref),
    customerName: stringField(customerName),
    customerPhone: stringField(phone),
    customerEmail: stringField(''),
    employeeId: stringField(''), // يُعيَّن لاحقاً من التطبيق
    serviceIds: {
      arrayValue: {
        values: service ? [stringField(service)] : []
      }
    },
    startTime: timestampField(start),
    endTime: timestampField(end),
    status: stringField('requested'),
    paymentStatus: stringField('unpaid'),
    totalAmount: doubleField(0),
    depositAmount: doubleField(0),
    collectedAmount: doubleField(0),
    discountAmount: doubleField(0),
    notes: stringField(
      [notes, 'مصدر: Google Form', 'خدمة: ' + service]
        .filter(Boolean)
        .join(' | ')
    ),
    recurring: boolField(false),
    outOfHours: boolField(false),
    createdAt: timestampField(now),
    reminderSent: boolField(false)
  };

  var url =
    'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents/shops/' +
    encodeURIComponent(shopId) +
    '/appointments?documentId=' +
    encodeURIComponent(docId);

  var token = getAccessToken_();
  var res = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify({ fields: fields }),
    muteHttpExceptions: true
  });

  var code = res.getResponseCode();
  var body = res.getContentText();
  if (code < 200 || code >= 300) {
    throw new Error('Firestore HTTP ' + code + ': ' + body);
  }
  console.log('Created appointment ' + docId + ' ref=' + ref + ' row=' + row);
}

// ─── helpers ───────────────────────────────────────────

function mustProp(props, key) {
  var v = props.getProperty(key);
  if (!v) throw new Error('Missing Script property: ' + key);
  return v;
}

function stringField(s) {
  return { stringValue: String(s == null ? '' : s) };
}

function doubleField(n) {
  return { doubleValue: Number(n) || 0 };
}

function boolField(b) {
  return { booleanValue: !!b };
}

function timestampField(d) {
  return { timestampValue: new Date(d).toISOString() };
}

function parseWhen(raw) {
  if (raw instanceof Date && !isNaN(raw.getTime())) return raw;
  var s = String(raw || '').trim();
  if (!s) return new Date();
  var d = new Date(s);
  if (!isNaN(d.getTime())) return d;
  return new Date();
}

/**
 * JWT service-account → access_token (scope datastore).
 */
function getAccessToken_() {
  var props = PropertiesService.getScriptProperties();
  var email = mustProp(props, 'SERVICE_ACCOUNT_EMAIL');
  var key = mustProp(props, 'PRIVATE_KEY').replace(/\\n/g, '\n');

  var now = Math.floor(Date.now() / 1000);
  var header = { alg: 'RS256', typ: 'JWT' };
  var claim = {
    iss: email,
    sub: email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/datastore'
  };

  var encHeader = base64url_(Utilities.newBlob(JSON.stringify(header)).getBytes());
  var encClaim = base64url_(Utilities.newBlob(JSON.stringify(claim)).getBytes());
  var toSign = encHeader + '.' + encClaim;
  var sigBytes = Utilities.computeRsaSha256Signature(toSign, key);
  var jwt = toSign + '.' + base64url_(sigBytes);

  var tokenRes = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    },
    muteHttpExceptions: true
  });
  var tokenJson = JSON.parse(tokenRes.getContentText());
  if (!tokenJson.access_token) {
    throw new Error('Token error: ' + tokenRes.getContentText());
  }
  return tokenJson.access_token;
}

function base64url_(bytes) {
  return Utilities.base64EncodeWebSafe(bytes).replace(/=+$/, '');
}
