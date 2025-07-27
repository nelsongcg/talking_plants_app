/* ─────────────────  index.js (with plant search & caretaking update)  ───────────────── */
import express from 'express';
import bcrypt  from 'bcryptjs';
import jwt     from 'jsonwebtoken';
import mysql   from 'mysql2/promise';
import multer  from 'multer';
import path    from 'path';
import fs      from 'fs';
import axios   from 'axios';

import { v4 as uuid } from 'uuid';
import { fileURLToPath } from 'url';
import 'dotenv/config';              // loads .env

const app = express();
app.use(express.json());

/* ----------  robust uploads/ folder setup  ---------- */
const __dirname  = path.dirname(fileURLToPath(import.meta.url)); // …/src
const uploadsDir = path.join(__dirname, 'uploads');
try {
  fs.mkdirSync(uploadsDir, { recursive: true });
  fs.accessSync(uploadsDir, fs.constants.W_OK);
  console.log('📂  uploads dir =', uploadsDir);
} catch (err) {
  console.error('❌  Cannot write to uploads directory:', uploadsDir);
  console.error(err);
  process.exit(1);
}

const storage = multer.diskStorage({
  destination: uploadsDir,
  filename:    (_, file, cb) =>
    cb(null, `${Date.now()}-${file.originalname.replaceAll(' ', '_')}`),
});
const upload = multer({ storage });
app.use('/uploads', express.static(uploadsDir));

/* ------------ MySQL pool -------------------------------- */
const pool = mysql.createPool({
  host:     process.env.DB_HOST,
  user:     process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

/* ------------ helpers ----------------------------------- */
const sign = (id) => jwt.sign({ sub: id }, process.env.JWT_SECRET, { expiresIn: '15m' });

/* ─── call Lambda and return its reply ───────────────────────────── */
async function askPlantLambda({ user_id, device_id, plant_id, text }) {
  const r = await axios.post(
    'https://gt4m54l8n2.execute-api.us-east-1.amazonaws.com/api/mytalkingplant', // <- your API GW URL
    { user_id, device_id, plant_id, text },
    { timeout: 150000 }
  );
  return r.data.reply;   // Lambda returns  { "reply": "…" }
}

function verifyJwtMiddleware(req, res, next) {
  const hdr   = req.headers.authorization || '';
  const token = hdr.replace('Bearer ', '');
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Unauthenticated' });
  }
}

/* protect all /devices/* and /api/* */
app.use('/devices', verifyJwtMiddleware);
app.use('/api',     verifyJwtMiddleware);

/* ─────────────────  ROUTES  ───────────────── */

/* ---------- auth ---------- */
app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  const [[row]] = await pool.query('SELECT 1 FROM users WHERE email=?', [email]);
  if (row) return res.status(409).json({ message: 'Email in use' });

  const hash = await bcrypt.hash(password, 12);
  const id   = uuid();
  await pool.query('INSERT INTO users (id,email,passwordHash) VALUES (?,?,?)', [id, email, hash]);
  res.status(201).json({ id, token: sign(id) });
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const [[u]] = await pool.query('SELECT id,passwordHash FROM users WHERE email=?', [email]);
  if (!u) return res.status(401).json({ message: 'No user' });

  const ok = await bcrypt.compare(password, u.passwordHash);
  if (!ok) return res.status(401).json({ message: 'Bad password' });

  res.json({ token: sign(u.id) });
});

app.get('/auth/email-exists', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ message: 'Missing email' });
  const [[r]] = await pool.query('SELECT 1 AS x FROM users WHERE email=?', [email]);
  res.json({ exists: !!r });
});

/* ---------- user status ---------- */
app.get('/api/user/status', async (req, res) => {
  const [[r]] = await pool.query('SELECT COUNT(*) AS devices FROM caretaker WHERE user_id=?', [req.user.sub]);
  res.json(r);
});

/* ---------- user onboarding status ---------- */
app.get('/api/user/onboarding', async (req, res) => {
  const [rows] = await pool.query(
    'SELECT device_id, plant_id, device_synced FROM caretaker WHERE user_id=? ORDER BY id DESC LIMIT 1',
    [req.user.sub]
  );

  if (rows.length === 0) {
    return res.json({ step: 'claim' });
  }

  const ck = rows[0];
  let step = 'done';
  if (!ck.plant_id) {
    step = 'photo';
  } else if (ck.device_synced === 0) {
    step = 'wifi';
  }

  res.json({ step, device_id: ck.device_id });
});

/* ---------- plant master search ---------- */
app.get('/api/plants', async (req, res) => {
  const q     = (req.query.q || '').toString().trim();
  const limit = Math.min(Number(req.query.limit) || 20, 50);
  if (!q) return res.json([]);

  const like = `%${q}%`;
  const [rows] = await pool.query(
    `SELECT id, scientific_name, common_name_en, mood_reference, personality_default
       FROM plants
      WHERE scientific_name LIKE ? OR common_name_en LIKE ?
      LIMIT ?`,
    [like, like, limit]
  );
  res.json(rows);
});

/* ---------- device claim ---------- */
app.post('/devices/claim', async (req, res) => {
  const { device_id, token } = req.body || {};
  if (!device_id || !token) return res.status(400).json({ message: 'Missing params' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[dev]] = await conn.query('SELECT claimed, claim_token FROM devices WHERE id=? FOR UPDATE', [device_id]);
    if (!dev)               { await conn.rollback(); return res.status(404).json({ message:'No device' }); }
    if (dev.claimed)        { await conn.rollback(); return res.status(409).json({ message:'Claimed'  }); }
    if (dev.claim_token !== token) { await conn.rollback(); return res.status(401).json({ message:'Bad token' }); }

    await conn.query('INSERT INTO caretaker (user_id,device_id) VALUES (?,?)', [req.user.sub, device_id]);
    await conn.commit();
    res.status(201).json({ device_id });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  } finally {
    conn.release();
  }
});

/* ---------- plant photo / caretaker complete ---------- */
// multipart/form-data: { device_id, plant_id, avatar_name?, photo }
app.post('/api/plants/photo', upload.single('photo'), async (req, res) => {
  const { device_id, plant_id, avatar_name } = req.body || {};
  if (!device_id || !plant_id || !req.file)
    return res.status(400).json({ message: 'Missing params' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // verify caretaker exists and is owned by this user
    const [[ck]] = await conn.query('SELECT id FROM caretaker WHERE user_id=? AND device_id=? FOR UPDATE', [req.user.sub, device_id]);
    if (!ck) { await conn.rollback(); return res.status(403).json({ message:'Device not linked to user' }); }

    // fetch plant defaults
    const [[pl]] = await conn.query('SELECT common_name_en AS plant_type, mood_reference, personality_default FROM plants WHERE id=?', [plant_id]);
    if (!pl) { await conn.rollback(); return res.status(404).json({ message:'Unknown plant' }); }

    const url = `/uploads/${req.file.filename}`;
    const avatarId = uuid();

    const moodJSON = typeof pl.mood_reference === 'string'
      ? pl.mood_reference
      : JSON.stringify(pl.mood_reference || {});

    await conn.query(
      `UPDATE caretaker SET photo_url = ?,
                            plant_id  = ?,
                            plant_type = ?,
                            mood_reference_values = CAST(? AS JSON),
                            personality_default   = JSON_QUOTE(?),
                            avatar_id = ?, avatar_name = ?
        WHERE id = ?`,
      [
        url,
        plant_id,
        pl.plant_type,
        moodJSON,                 // ← bound parameter, not string-interpolated
        pl.personality_default,
        avatarId,
        avatar_name || pl.plant_type,
        ck.id,
      ],
    );
    await conn.commit();
    res.status(201).json({ photo_url: url, caretaker_id: ck.id });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  } finally {
    conn.release();
  }
});

/* ---------- chat ---------- */
app.post('/api/chat', async (req, res) => {
  const { device_id, text } = req.body || {};          // ← now device_id
  if (!device_id || text === undefined) {
    return res.status(400).json({ message: 'Missing params' });
  }

  try {
    // look up plant_id for this user + device
    const [[ck]] = await pool.query(
      'SELECT id AS caretaker_id, plant_id FROM caretaker ' +
      'WHERE user_id=? AND device_id=? AND device_synced=1',
      [req.user.sub, device_id]
    );
    if (!ck) return res.status(404).json({ message: 'Device not linked' });

    // 🔸 NEW: actually call Lambda so `reply` is defined
    const reply = await askPlantLambda({
      user_id:  req.user.sub,
      device_id,
      plant_id: ck.plant_id,
      text
    });

    res.json({ reply });
  } catch (e) {
    console.error('chat error:', e);
    res.status(502).json({ message: 'Brain offline' });
  }
});

/* ---------- device online callback ---------- */
app.post('/device/online', async (req, res) => {
  const { device_id, claim_token } = req.body || {};
  if (!device_id || !claim_token) return res.status(400).json({ msg:'missing params' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[dev]] = await conn.query('SELECT claim_token FROM devices WHERE id=? FOR UPDATE', [device_id]);
    if (!dev) { await conn.rollback(); return res.status(404).json({ msg:'unknown device' }); }
    if (dev.claim_token !== claim_token) { await conn.rollback(); return res.status(401).json({ msg:'bad token' }); }

    await conn.query('UPDATE devices SET claimed=1, online=1 WHERE id=?', [device_id]);
    await conn.query('UPDATE caretaker SET device_synced=1 WHERE device_id=?', [device_id]);

    // fetch caretaker info so we can insert the initial personality row
    const [[ck]] = await conn.query(
      `SELECT plant_id, plant_type, personality_default
         FROM caretaker
        WHERE device_id = ?
        LIMIT 1 FOR UPDATE`,
      [device_id]
    );

    if (ck && ck.plant_id) {
      await conn.query(
        `INSERT INTO personality_evolution
            (device_id, plant_id, personality_description, plant_type, personality_params, current_mood, sensor_readings)
         VALUES (?, ?, ?, ?,'{}', '{}', '{}')`,
        [device_id, ck.plant_id, ck.personality_default, ck.plant_type]
      );
    }



    await conn.commit();
    res.json({ ok:true });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ msg:'server error' });
  } finally {
    conn.release();
  }
});

/* ---------- online status poll ---------- */
app.get('/api/devices/:id/status', async (req, res) => {
  const [[r]] = await pool.query('SELECT online FROM devices WHERE id=?', [req.params.id]);
  res.json(r || { online:0 });
});

/* ---------- list user devices ---------- */
app.get('/api/devices', async (req, res) => {
  const [rows] = await pool.query(
    'SELECT device_id, plant_id FROM caretaker WHERE user_id=? and device_synced = 1',
    [req.user.sub]
  );
  res.json(rows);          // e.g. [ { device_id:'A0:B7...', plant_id:16 } ]
});

/* 
  GET /api/personality‐evolution
  Query params:
    • device_id  – string (required)
  Returns (for the last 30 days of data):
    [
      {
        date: "2025-06-01",           // from `timestamp`
        luminosity: 5477.839232988888,
        night_hours: 5.985277777777778,
        soil_moisture: 80.4845537271605,
        day_temperature: 21.734381417037103,
        night_temperature: 20.70229598389567,
        relative_humidity: 83.03977181823765
      },
      …
    ]
*/
app.get('/api/personality-evolution', async (req, res) => {
  const { device_id } = req.query || {};
  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1. Verify device belongs to this user, get plant_id
    const [[ck]] = await pool.query(
      `SELECT c.plant_id
         FROM caretaker AS c
        WHERE c.user_id = ? AND c.device_id = ? AND c.device_synced = 1`,
      [req.user.sub, device_id]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }
    const plantId = ck.plant_id;

    // 2. Find the most recent timestamp for this plant
    const [[{ max_ts }]] = await pool.query(
      `SELECT MAX(\`timestamp\`) AS max_ts
         FROM personality_evolution
        WHERE plant_id = ?`,
      [plantId]
    );
    if (!max_ts) {
      // No data at all for this plant → return empty array
      return res.json([]);
    }

    // 3. Fetch all rows ≥ (max_ts − 30 days)
    //    We rely on MySQL's DATE_SUB(...) to subtract 30 days from max_ts
    const [rows] = await pool.query(
      `SELECT \`timestamp\`, sensor_readings
         FROM personality_evolution
        WHERE plant_id = ?
          AND \`timestamp\` >= DATE_SUB(?, INTERVAL 30 DAY)
        ORDER BY \`timestamp\` ASC`,
      [plantId, max_ts]
    );

    // 4. Transform each row into { date: "YYYY-MM-DD", luminosity, … }
    const daily = rows.map((r) => {
      // sensor_readings may already be parsed as JSON or returned as string
      const j = typeof r.sensor_readings === 'string'
        ? JSON.parse(r.sensor_readings)
        : r.sensor_readings;

      return {
        date: r.timestamp.toISOString().slice(0, 10),
        luminosity: j.luminosity,
        night_hours: j.night_hours,
        soil_moisture: j.soil_moisture,
        day_temperature: j.day_temperature,
        night_temperature: j.night_temperature,
        relative_humidity: j.relative_humidity
      };
    });

    return res.json(daily);
  } catch (err) {
    console.error('Error fetching last-30-days of personality evolution:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/health/latest
 * Query params:
 *   • device_id (required)
 *
 * Response:
 *   200 → { current_mood: { luminosity: [...], soil_moisture: [...], … } }
 *   404 → if device isn’t linked or there’s no data yet
 */
app.get('/api/health/latest', async (req, res) => {
  const deviceId = req.query.device_id;
  if (!deviceId) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1) verify caretaker & get plant_id
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [req.user.sub, deviceId]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }

    // 2) fetch the single most recent row
    const [[row]] = await pool.query(
      `SELECT current_mood, status_checked, streak_claimed
        FROM personality_evolution
        WHERE plant_id = ?
        ORDER BY \`timestamp\` DESC
        LIMIT 1`,
      [ck.plant_id]
    );
    if (!row) return res.status(404).json({ message: 'No health data available yet' });

    const mood = typeof row.current_mood === 'string'
      ? JSON.parse(row.current_mood)
      : row.current_mood;

    return res.json({
      current_mood:    mood,
      status_checked:  row.status_checked  === 1 ? 1 : 0,
      streak_claimed:  row.streak_claimed  === 1 ? 1 : 0,
    });

  } catch (err) {
    console.error('Error in /api/health/latest:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/health/mark-checked
 * Body:
 *   { device_id: string }
 *
 * Marks the most‐recent personality_evolution row for this device’s plant
 * (i.e. today’s summary) by setting status_checked = 1.
 */
app.post('/api/health/mark-checked', async (req, res) => {
  const { device_id } = req.body || {};
  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1) verify caretaker & get plant_id
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [req.user.sub, device_id]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }

    // 2) find the latest timestamp for that plant
    const [[{ max_ts }]] = await pool.query(
      `SELECT MAX(\`timestamp\`) AS max_ts
         FROM personality_evolution
        WHERE plant_id = ?`,
      [ck.plant_id]
    );
    if (!max_ts) {
      return res.status(404).json({ message: 'No mood entry found to mark' });
    }

    // 3) update that row’s status_checked = 1
    const [result] = await pool.query(
      `UPDATE personality_evolution
          SET status_checked = 1
        WHERE plant_id = ? AND \`timestamp\` = ?`,
      [ck.plant_id, max_ts]
    );

    if (result.affectedRows === 0) {
      return res.status(500).json({ message: 'Failed to mark checked' });
    }
    return res.json({ success: true });
  } catch (err) {
    console.error('Error in /api/health/mark-checked:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/health/claim-streak', async (req, res) => {
  const { device_id } = req.body || {};
  const user_id = req.user.sub;
  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1) verify caretaker & get plant_id
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [user_id, device_id]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }
    const plant_id = ck.plant_id;

    // 2) find the most recent timestamp for that plant_id
    const [[{ max_ts }]] = await pool.query(
      `SELECT MAX(\`timestamp\`) AS max_ts
         FROM personality_evolution
        WHERE plant_id = ?`,
      [plant_id]
    );
    if (!max_ts) {
      return res.status(404).json({ message: 'No mood entry found to claim streak' });
    }

    // 3) mark that row claimed
    const [upd] = await pool.query(
      `UPDATE personality_evolution
          SET streak_claimed = 1
        WHERE plant_id = ? AND \`timestamp\` = ?`,
      [plant_id, max_ts]
    );
    if (upd.affectedRows === 0) {
      return res.status(500).json({ message: 'Failed to claim streak' });
    }

    // 4) upsert into streak according to your logic
    const tsDate = max_ts.toISOString().slice(0, 10); // "YYYY-MM-DD"

    // fetch existing streak row
    const [rows] = await pool.query(
      `SELECT id, current_streak, longest_streak, last_date, streak_started_at
         FROM streak
        WHERE device_id = ? AND plant_id = ? AND user_id = ?`,
      [device_id, plant_id, user_id]
    );

    let newCurrent, newLongest, newStarted;

    if (rows.length === 0) {
      // no record → insert first-day streak
      newCurrent = 1;
      newLongest = 1;
      newStarted = tsDate;
      await pool.query(
        `INSERT INTO streak
           (device_id, plant_id, user_id, current_streak, longest_streak, last_date, streak_started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [device_id, plant_id, user_id, newCurrent, newLongest, tsDate, newStarted]
      );

    } else {
      // existing record → compare last_date
      const rec = rows[0];
      const lastDate = rec.last_date ? rec.last_date.toISOString().slice(0, 10) : null;

      // helper to compute date-difference = 1 day
      const isConsecutive = (() => {
        if (!lastDate) return false;
        const d1 = new Date(lastDate), d2 = new Date(tsDate);
        return (d2 - d1) === 24*60*60*1000;
      })();

      if (isConsecutive) {
        newCurrent = rec.current_streak + 1;
      } else if (lastDate === tsDate) {
        // already claimed today → leave streak unchanged
        newCurrent = rec.current_streak;
      } else {
        // gap of ≥2 days → reset streak
        newCurrent = 1;
      }

      newLongest = Math.max(rec.longest_streak, newCurrent);
      newStarted = (newCurrent === 1) ? tsDate : rec.streak_started_at.toISOString().slice(0, 10);

      await pool.query(
        `UPDATE streak
            SET current_streak    = ?,
                longest_streak    = ?,
                last_date         = ?,
                streak_started_at = ?,
                updated_at        = CURRENT_TIMESTAMP
          WHERE id = ?`,
        [newCurrent, newLongest, tsDate, newStarted, rec.id]
      );
    }

    return res.json({ success: true, current_streak: newCurrent, longest_streak: newLongest });
  }
  catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});
app.post('/api/health/claim-streak', async (req, res) => {
  const { device_id } = req.body || {};
  const user_id = req.user.sub;
  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1) verify caretaker & get plant_id
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [user_id, device_id]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }
    const plant_id = ck.plant_id;

    // 2) find the most recent timestamp for that plant_id
    const [[{ max_ts }]] = await pool.query(
      `SELECT MAX(\`timestamp\`) AS max_ts
         FROM personality_evolution
        WHERE plant_id = ?`,
      [plant_id]
    );
    if (!max_ts) {
      return res.status(404).json({ message: 'No mood entry found to claim streak' });
    }

    // 3) mark that row claimed
    const [upd] = await pool.query(
      `UPDATE personality_evolution
          SET streak_claimed = 1
        WHERE plant_id = ? AND \`timestamp\` = ?`,
      [plant_id, max_ts]
    );
    if (upd.affectedRows === 0) {
      return res.status(500).json({ message: 'Failed to claim streak' });
    }

    // 4) upsert into streak according to your logic
    const tsDate = max_ts.toISOString().slice(0, 10); // "YYYY-MM-DD"

    // fetch existing streak row
    const [rows] = await pool.query(
      `SELECT id, current_streak, longest_streak, last_date, streak_started_at
         FROM streak
        WHERE device_id = ? AND plant_id = ? AND user_id = ?`,
      [device_id, plant_id, user_id]
    );

    let newCurrent, newLongest, newStarted;

    if (rows.length === 0) {
      // no record → insert first-day streak
      newCurrent = 1;
      newLongest = 1;
      newStarted = tsDate;
      await pool.query(
        `INSERT INTO streak
           (device_id, plant_id, user_id, current_streak, longest_streak, last_date, streak_started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [device_id, plant_id, user_id, newCurrent, newLongest, tsDate, newStarted]
      );

    } else {
      // existing record → compare last_date
      const rec = rows[0];
      const lastDate = rec.last_date ? rec.last_date.toISOString().slice(0, 10) : null;

      // helper to compute date-difference = 1 day
      const isConsecutive = (() => {
        if (!lastDate) return false;
        const d1 = new Date(lastDate), d2 = new Date(tsDate);
        return (d2 - d1) === 24*60*60*1000;
      })();

      if (isConsecutive) {
        newCurrent = rec.current_streak + 1;
      } else if (lastDate === tsDate) {
        // already claimed today → leave streak unchanged
        newCurrent = rec.current_streak;
      } else {
        // gap of ≥2 days → reset streak
        newCurrent = 1;
      }

      newLongest = Math.max(rec.longest_streak, newCurrent);
      newStarted = (newCurrent === 1) ? tsDate : rec.streak_started_at.toISOString().slice(0, 10);

      await pool.query(
        `UPDATE streak
            SET current_streak    = ?,
                longest_streak    = ?,
                last_date         = ?,
                streak_started_at = ?,
                updated_at        = CURRENT_TIMESTAMP
          WHERE id = ?`,
        [newCurrent, newLongest, tsDate, newStarted, rec.id]
      );
    }

    return res.json({ success: true, current_streak: newCurrent, longest_streak: newLongest });
  }
  catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/health/current-streak
 * Query: ?device_id=XXXX
 *
 * Returns { current_streak: <int> }
 *
 *   • Verifies that the caller is the caretaker of the device.
 *   • Looks up (device_id, plant_id, user_id) in the `streak` table.
 *   • If no row found → returns 0.
 *   • If the row exists but the last_date is stale (gap ≥ 2 days)
 *     → also returns 0 (so the UI never shows an outdated streak).
 */
app.get('/api/health/current-streak', async (req, res) => {
  const { device_id } = req.query || {};
  const user_id = req.user.sub;          // your Auth0 “sub” from JWT

  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    /* 1) Verify the user really “owns” this device & fetch plant_id  */
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [user_id, device_id]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or plant not found' });
    }
    const plant_id = ck.plant_id;

    /* 2) Ask streak table for this trio */
    const [rows] = await pool.query(
      `SELECT current_streak, last_date
         FROM streak
        WHERE device_id = ? AND plant_id = ? AND user_id = ?`,
      [device_id, plant_id, user_id]
    );

    let current = 0;

    if (rows.length) {
      const row = rows[0];
      current = row.current_streak;

      // sanity-check: if the last_date isn’t yesterday or today, the streak is broken
      const lastDate = row.last_date ? new Date(row.last_date) : null;
      if (lastDate) {
        const today = new Date();
        const diffDays = (today.setHours(0,0,0,0) - lastDate.setHours(0,0,0,0))
                         / (24 * 60 * 60 * 1000);

        if (diffDays >= 2) current = 0;          // streak has lapsed
      }
    }

    return res.json({ current_streak: current });
  } catch (err) {
    console.error('Error in /api/health/current-streak:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// ─── GET /api/chat/history ───────────────────────────────────────────
app.get('/api/chat/history', verifyJwtMiddleware, async (req, res) => {
  const deviceId = req.query.device_id;
  console.log('⚙️  GET /api/chat/history called for user=', req.user.sub,'device=', req.query.device_id);
  const userId   = req.user.sub;

  if (!deviceId) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    // 1) Verify caretaker & get plant_id
    const [[ck]] = await pool.query(
      `SELECT plant_id
         FROM caretaker
        WHERE user_id = ? AND device_id = ? AND device_synced = 1`,
      [userId, deviceId]
    );
    if (!ck) {
      return res.status(404).json({ message: 'Device not linked or no plant found' });
    }
    const plantId = ck.plant_id;

    // 2) Fetch last 10 messages for this user+plant
    const [rows] = await pool.query(
      `SELECT message_text, role
         FROM messages
        WHERE user_id = ? AND plant_id = ?
        ORDER BY created_at DESC
        LIMIT 10`,
      [userId, plantId]
    );

    // 3) Map DB rows into { text, is_user } for your Flutter client
    const history = rows.map(r => ({
      text:    r.message_text,
      is_user: r.role === 'caretaker'    // your “role” column: caretaker → user; plant → bot
    }));

    return res.json(history);
  } catch (err) {
    console.error('Error in /api/chat/history:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/* ---------- tutorial flags ---------- */
app.get('/api/tutorial-flags', async (req, res) => {
  const userId   = req.user.sub;
  const deviceId = req.query.device_id;
  if (!deviceId) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    const [[row]] = await pool.query(
      `SELECT tutorial_onboarding_seen, tutorial_onboarding_eligible
         FROM caretaker
        WHERE user_id=? AND device_id=?`,
      [userId, deviceId]
    );

    const seen     = row?.tutorial_onboarding_seen ?? 1;
    const eligible = row?.tutorial_onboarding_eligible ?? 1;

    res.json({
      tutorial_onboarding_seen: seen,
      tutorial_onboarding_eligible: eligible,
    });
  } catch (err) {
    console.error('Error fetching tutorial flags:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/tutorial-flags', async (req, res) => {
  const userId   = req.user.sub;
  const { device_id, tutorial_onboarding_seen, tutorial_onboarding_eligible } =
    req.body || {};

  if (!device_id) {
    return res.status(400).json({ message: 'Missing device_id' });
  }

  try {
    await pool.query(
      `UPDATE caretaker
          SET tutorial_onboarding_seen     = COALESCE(?, tutorial_onboarding_seen),
              tutorial_onboarding_eligible = COALESCE(?, tutorial_onboarding_eligible)
        WHERE user_id = ? AND device_id = ?`,
      [tutorial_onboarding_seen, tutorial_onboarding_eligible, userId, device_id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error updating tutorial flags:', err);
    res.status(500).json({ message: 'Server error' });
  }
});




/* ---------- start server ---------- */
app.listen(3000, () => console.log('Auth server on :3000'));
