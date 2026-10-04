/**
 * One-off: recompute findings from stored reports, then force insights refresh.
 *
 * Usage:
 *   node scripts/recomputeFindingsAndRefresh.js shekhararya613@gmail.com
 */
import { computeFingerprint } from '../src/services/fingerprint.js';
import {
  buildPatientContext,
  getDb,
  initFirebase,
} from '../src/services/firestore.js';
import { refreshIfFindingsChanged } from '../src/services/insightsPipeline.js';

function asNum(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (value == null) return null;
  const n = Number(String(value).replace(/,/g, '').trim());
  return Number.isFinite(n) ? n : null;
}

function isLow(v) {
  if (!v) return false;
  const flag = String(v.flag || '').trim().toUpperCase();
  if (flag === 'L' || flag === 'LOW') return true;
  const value = asNum(v.value);
  const low = asNum(v.refLow);
  return value != null && low != null && value < low;
}

function isHigh(v) {
  if (!v) return false;
  const flag = String(v.flag || '').trim().toUpperCase();
  if (flag === 'H' || flag === 'HIGH') return true;
  const value = asNum(v.value);
  const high = asNum(v.refHigh);
  return value != null && high != null && value > high;
}

function reportSortDate(dateKey, data) {
  for (const key of [
    'collectedDate',
    'collectionDate',
    'reportApprovedDate',
    'testDate',
    'createdAt',
  ]) {
    const parsed = Date.parse(String(data?.[key] || ''));
    if (!Number.isNaN(parsed)) return parsed;
  }
  const fromKey = Date.parse(dateKey);
  return Number.isNaN(fromKey) ? 0 : fromKey;
}

function latestReport(userDoc, reportKey) {
  const raw = userDoc[reportKey];
  if (!raw || typeof raw !== 'object') return null;
  let bestDate = null;
  let bestData = null;
  let bestSort = -1;
  for (const [dateKey, entry] of Object.entries(raw)) {
    if (!entry || typeof entry !== 'object') continue;
    const sortAt = reportSortDate(dateKey, entry);
    if (sortAt >= bestSort) {
      bestSort = sortAt;
      bestDate = dateKey;
      bestData = entry;
    }
  }
  if (!bestDate || !bestData) return null;
  return { date: bestDate, data: bestData };
}

function valuesByKey(report) {
  const out = {};
  const values = Array.isArray(report.values) ? report.values : [];
  for (const item of values) {
    if (!item || typeof item !== 'object') continue;
    const key = String(item.parameterKey || item.parameter_key || '').trim();
    if (key) out[key] = item;
  }
  return out;
}

function computeFindings(userDoc) {
  const now = new Date().toISOString();
  const findings = {};

  const add = (key, derivedFrom, sinceDate) => {
    findings[key] = {
      key,
      derivedFrom,
      sinceDate,
      active: true,
      updatedAt: now,
    };
  };

  const cbc = latestReport(userDoc, 'cbc');
  if (cbc) {
    const byKey = valuesByKey(cbc.data);
    if (isLow(byKey.hemoglobin)) {
      add('low_hemoglobin', [`cbc/${cbc.date}/hemoglobin`], cbc.date);
    }
    if (isLow(byKey.mcv) && isLow(byKey.mch)) {
      add(
        'microcytic_pattern',
        [`cbc/${cbc.date}/mcv`, `cbc/${cbc.date}/mch`],
        cbc.date,
      );
    }
    if (isHigh(byKey.neutrophils_pct) || isHigh(byKey.neutrophils)) {
      const param = byKey.neutrophils_pct ? 'neutrophils_pct' : 'neutrophils';
      add('high_neutrophils', [`cbc/${cbc.date}/${param}`], cbc.date);
    }
  }

  return findings;
}

async function main() {
  const email = String(process.argv[2] || '')
    .trim()
    .toLowerCase();
  if (!email) {
    console.error('Usage: node scripts/recomputeFindingsAndRefresh.js <email>');
    process.exit(1);
  }

  initFirebase();
  const db = getDb();
  const ref = db.collection('USERS').doc(email);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new Error(`No USERS/${email} document`);
  }

  const userDoc = { id: snap.id, ...snap.data() };
  const findings = computeFindings(userDoc);
  await ref.set(
    {
      findings,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );

  const merged = { ...userDoc, findings };
  const ctx = buildPatientContext(merged);
  console.log('activeFindings', ctx.activeFindings.map((f) => f.key));
  console.log('fingerprint', computeFingerprint(ctx));

  console.log('Generating insights (force)...');
  const bundle = await refreshIfFindingsChanged({
    email,
    userDoc: merged,
    force: true,
    persist: true,
  });

  console.log(
    JSON.stringify(
      {
        reason: bundle.reason,
        fingerprint: bundle.fingerprint,
        cards: (bundle.cards || []).map((c) => ({
          id: c.id,
          title: c.title,
          category: c.category,
        })),
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
