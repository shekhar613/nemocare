import { config } from '../config.js';
import { getAuth } from '../services/firestore.js';

/**
 * Optional Firebase ID token verification.
 * When REQUIRE_AUTH=false, passes through (local demo).
 */
export async function optionalFirebaseAuth(req, res, next) {
  if (!config.requireAuth) {
    return next();
  }

  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({ error: 'Missing Bearer token' });
  }

  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    req.user = {
      uid: decoded.uid,
      email: (decoded.email || '').toLowerCase(),
    };
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid Firebase ID token' });
  }
}

/** If auth is on, ensure body.email matches the token email. */
export function assertEmailMatchesAuth(req, res, next) {
  if (!config.requireAuth) return next();
  const bodyEmail = String(req.body?.email || '').trim().toLowerCase();
  if (!bodyEmail || !req.user?.email || bodyEmail !== req.user.email) {
    return res.status(403).json({
      error: 'email must match the authenticated user',
    });
  }
  return next();
}
