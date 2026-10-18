import fs from 'fs';
import path from 'path';
import admin from 'firebase-admin';
import { config } from '../config.js';

let initialized = false;

export function initFirebase() {
  if (initialized) return admin.app();

  let credential;
  if (config.firebase.serviceAccountJson) {
    const json = JSON.parse(config.firebase.serviceAccountJson);
    credential = admin.credential.cert(json);
  } else {
    const credPath = path.resolve(process.cwd(), config.firebase.credentialsPath);
    if (!fs.existsSync(credPath)) {
      console.warn(
        `[firestore] No service account at ${credPath}. ` +
          'Insights can still run in dry mode if you pass userDoc in the request body.',
      );
      initialized = true;
      return null;
    }
    const json = JSON.parse(fs.readFileSync(credPath, 'utf8'));
    credential = admin.credential.cert(json);
  }

  admin.initializeApp({ credential });
  initialized = true;
  return admin.app();
}

export function getDb() {
  if (!initialized) initFirebase();
  if (!admin.apps.length) {
    throw new Error(
      'Firebase Admin not initialized. Add serviceAccountKey.json or FIREBASE_SERVICE_ACCOUNT_JSON.',
    );
  }
  return admin.firestore();
}

export function getAuth() {
  if (!initialized) initFirebase();
  if (!admin.apps.length) {
    throw new Error('Firebase Admin not initialized.');
  }
  return admin.auth();
}

export async function fetchUserDoc(email) {
  const db = getDb();
  const ref = db
    .collection(config.firebase.usersCollection)
    .doc(email.trim().toLowerCase());
  const snap = await ref.get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() };
}

export async function writeInsightsBundle(email, bundle) {
  const db = getDb();
  const ref = db
    .collection(config.firebase.usersCollection)
    .doc(email.trim().toLowerCase());
  await ref.set(
    {
      insights: bundle,
      insights_meta: {
        fingerprint: bundle.fingerprint || '',
        generatedAt: bundle.generatedAt || new Date().toISOString(),
      },
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );
}

/**
 * Build active findings + supporting values from a USERS/{email} document
 * (same shape Flutter PatientContextService uses).
 */
export function buildPatientContext(userDoc) {
  const findingsRaw = userDoc?.findings;
  const findingsMap =
    findingsRaw && typeof findingsRaw === 'object' ? findingsRaw : {};

  const activeFindings = [];
  for (const value of Object.values(findingsMap)) {
    if (!value || typeof value !== 'object') continue;
    const key = String(value.key || '').trim();
    if (!key || value.active !== true) continue;
    activeFindings.push({
      key,
      derivedFrom: Array.isArray(value.derivedFrom) ? value.derivedFrom : [],
      sinceDate: String(value.sinceDate || ''),
      active: true,
      updatedAt: value.updatedAt || null,
    });
  }
  activeFindings.sort((a, b) =>
    String(b.sinceDate).localeCompare(String(a.sinceDate)),
  );

  const supportingValues = {};
  for (const finding of activeFindings) {
    supportingValues[finding.key] = finding.derivedFrom
      .map((p) => resolvePath(userDoc, p))
      .filter(Boolean);
  }

  const dob = String(userDoc?.dob || '');
  const sex = String(userDoc?.sex || userDoc?.gender || '');
  const drugAllergies = stringList(userDoc?.drugAllergies);
  const otherAllergies = stringList(userDoc?.otherAllergies);
  const foodIntolerances = stringList(userDoc?.foodIntolerances);
  const allergies = [
    ...new Set([
      ...drugAllergies,
      ...otherAllergies,
      ...foodIntolerances.filter((k) => k !== 'none'),
      ...stringList(userDoc?.allergies),
    ]),
  ];

  return {
    profile: {
      name: String(userDoc?.name || ''),
      dob,
      age: ageFromDob(dob),
      ageRange: String(userDoc?.ageRange || ''),
      ageApproximate: userDoc?.ageApproximate === true,
      sex,
      gender: sex,
      genderIdentity: String(userDoc?.genderIdentity || ''),
      height_cm: String(userDoc?.height_cm || ''),
      weight_kg: String(userDoc?.weight_kg || ''),
      bmi: String(userDoc?.bmi || ''),
      heightApproximate: userDoc?.heightApproximate === true,
      weightApproximate: userDoc?.weightApproximate === true,
      bloodGroup: String(userDoc?.bloodGroup || ''),
      knownConditions: stringList(userDoc?.knownConditions),
      onDialysis: userDoc?.onDialysis === true,
      eyeConditions: stringList(userDoc?.eyeConditions),
      skinConditions: stringList(userDoc?.skinConditions),
      foodIntolerances,
      medications: medicationNames(userDoc?.currentMedications),
      currentMedications: medicationDetails(userDoc?.currentMedications),
      allergies,
      drugAllergies,
      otherAllergies,
      smokingStatus: String(userDoc?.smokingStatus || ''),
      alcoholUse: String(userDoc?.alcoholUse || ''),
      dietPreference: String(userDoc?.dietPreference || ''),
      activityLevel: String(userDoc?.activityLevel || ''),
      pregnancyStatus: String(userDoc?.pregnancyStatus || ''),
    },
    activeFindings,
    supportingValues,
  };
}

function medicationNames(raw) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  for (const item of raw) {
    if (item && typeof item === 'object') {
      const name = String(item.name || '').trim();
      if (name) out.push(name);
    } else {
      const name = String(item ?? '').trim();
      if (name) out.push(name);
    }
  }
  return out;
}

function medicationDetails(raw) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  for (const item of raw) {
    if (item && typeof item === 'object') {
      const name = String(item.name || '').trim();
      if (!name) continue;
      const dosage = String(item.dosage || '').trim();
      out.push(dosage ? { name, dosage } : { name });
    } else {
      const name = String(item ?? '').trim();
      if (name) out.push({ name });
    }
  }
  return out;
}

function resolvePath(userDoc, pathStr) {
  const parts = String(pathStr)
    .split('/')
    .filter(Boolean);
  if (parts.length < 3) return null;
  const [reportKey, dateKey, parameterKey] = parts;
  const reportType = userDoc?.[reportKey];
  if (!reportType || typeof reportType !== 'object') return null;
  const report = reportType[dateKey];
  if (!report || typeof report !== 'object') return null;

  const values = Array.isArray(report.values) ? report.values : [];
  const match = values.find(
    (v) =>
      v &&
      String(v.parameterKey || v.parameter_key || '').trim() === parameterKey,
  );
  if (!match) return null;

  return {
    ...match,
    path: pathStr,
    reportType: reportKey,
    date: dateKey,
    labName: report.labName,
    reportName: report.reportName || report.docType || reportKey,
  };
}

const PROFILE_KEYS = new Set([
  'name',
  'dob',
  'ageRange',
  'ageApproximate',
  'sex',
  'gender',
  'genderIdentity',
  'height_cm',
  'weight_kg',
  'bmi',
  'heightApproximate',
  'weightApproximate',
  'married',
  'bloodGroup',
  'knownConditions',
  'onDialysis',
  'eyeConditions',
  'skinConditions',
  'foodIntolerances',
  'drugAllergies',
  'otherAllergies',
  'currentMedications',
  'medicationNames',
  'allergies',
  'smokingStatus',
  'alcoholUse',
  'dietPreference',
  'activityLevel',
  'pregnancyStatus',
  'onboardingCompleted',
  'onboardingCompletedAt',
  'email',
  'uid',
  'createdAt',
  'updatedAt',
  'findings',
  'insights',
  'insights_meta',
]);

function reportSortMs(dateKey, data) {
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

/**
 * Latest dated entry under each report type (cbc, kft, …) with compact values.
 * Used by home chat so questions like "platelet count" see normal labs too.
 */
export function latestReportsSummary(userDoc, { maxReports = 3, maxValues = 40 } = {}) {
  if (!userDoc || typeof userDoc !== 'object') return [];

  const reports = [];
  for (const [reportKey, byDate] of Object.entries(userDoc)) {
    if (PROFILE_KEYS.has(reportKey)) continue;
    if (!byDate || typeof byDate !== 'object' || Array.isArray(byDate)) continue;

    let bestDate = null;
    let bestData = null;
    let bestSort = -1;
    for (const [dateKey, entry] of Object.entries(byDate)) {
      if (!entry || typeof entry !== 'object') continue;
      // Skip nested non-report maps that don't look like reports.
      if (!Array.isArray(entry.values) && !entry.docType && !entry.reportName) {
        continue;
      }
      const sortAt = reportSortMs(dateKey, entry);
      if (sortAt >= bestSort) {
        bestSort = sortAt;
        bestDate = dateKey;
        bestData = entry;
      }
    }
    if (!bestDate || !bestData) continue;

    const values = Array.isArray(bestData.values) ? bestData.values : [];
    reports.push({
      reportType: reportKey,
      date: bestDate,
      reportName: bestData.reportName || bestData.docType || reportKey,
      labName: bestData.labName || '',
      values: values.slice(0, maxValues).map((v) => ({
        parameterKey: v.parameterKey || v.parameter_key || '',
        rawLabel: v.rawLabel || '',
        value: v.value ?? v.qualitativeValue ?? '',
        unit: v.unit || '',
        flag: v.flag ?? null,
        refLow: v.refLow ?? null,
        refHigh: v.refHigh ?? null,
      })),
      _sort: bestSort,
    });
  }

  reports.sort((a, b) => b._sort - a._sort);
  return reports.slice(0, maxReports).map(({ _sort, ...rest }) => rest);
}

function ageFromDob(dob) {
  if (!dob) return null;
  const d = new Date(dob);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
  return age;
}

function stringList(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => String(e ?? '').trim()).filter(Boolean);
}
