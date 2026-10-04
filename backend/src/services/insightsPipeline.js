import { computeFingerprint } from './fingerprint.js';
import {
  buildPatientContext,
  fetchUserDoc,
  writeInsightsBundle,
} from './firestore.js';
import { config } from '../config.js';
import { formatKbForPrompt, retrieveForFinding } from './medicalKb.js';
import { chatJson } from './nvidia.js';
import { formatSourcesForPrompt, tavilySearch } from './tavily.js';

const TAVILY_QUERIES = {
  high_blood_sugar:
    'long term health risks of high blood sugar eyes heart kidneys',
  low_hemoglobin: 'symptoms and causes of low hemoglobin anemia',
  microcytic_pattern: 'causes of low MCV MCH iron deficiency early signs',
  high_neutrophils: 'causes of high neutrophil percentage in blood test',
  hiv_1_2_abnormal: 'next steps after reactive HIV screening test',
  hcv_antibody_abnormal: 'next steps after reactive HCV antibody test',
  hbsag_abnormal: 'next steps after reactive HBsAg hepatitis B test',
};

/** Per-user in-flight + pending catch-up (same idea as Flutter InsightsService). */
const refreshInFlight = new Map();
const pendingUserDoc = new Map();
const pendingForce = new Map();

/**
 * Main entry: regenerate insights when evidence fingerprint changes.
 *
 * @param {{ email: string, userDoc?: object, force?: boolean, persist?: boolean }} opts
 */
export async function refreshIfFindingsChanged({
  email,
  userDoc: providedDoc,
  force = false,
  persist = true,
}) {
  const key = email.trim().toLowerCase();
  if (!key) throw new Error('email is required');

  if (refreshInFlight.get(key)) {
    pendingUserDoc.set(key, providedDoc ?? null);
    if (force) pendingForce.set(key, true);
    const doc = providedDoc ?? (await fetchUserDoc(key));
    return bundleFromDoc(doc);
  }

  refreshInFlight.set(key, true);
  let result;
  try {
    result = await doRefresh({
      email: key,
      userDoc: providedDoc,
      force,
      persist,
    });
    while (pendingUserDoc.has(key)) {
      const pending = pendingUserDoc.get(key);
      pendingUserDoc.delete(key);
      const pf = pendingForce.get(key) || false;
      pendingForce.delete(key);
      result = await doRefresh({
        email: key,
        userDoc: pending,
        force: pf,
        persist,
      });
    }
  } finally {
    refreshInFlight.delete(key);
  }

  if (pendingUserDoc.has(key)) {
    const pending = pendingUserDoc.get(key);
    pendingUserDoc.delete(key);
    const pf = pendingForce.get(key) || false;
    pendingForce.delete(key);
    return refreshIfFindingsChanged({
      email: key,
      userDoc: pending,
      force: pf,
      persist,
    });
  }

  return result;
}

async function doRefresh({ email, userDoc: providedDoc, force, persist }) {
  const userDoc = providedDoc ?? (await fetchUserDoc(email));
  if (!userDoc) {
    throw new Error(`User document not found for ${email}`);
  }

  const context = buildPatientContext(userDoc);
  const fingerprint = computeFingerprint(context);
  const existing = bundleFromDoc(userDoc);

  if (!force && existing.fingerprint === fingerprint) {
    return { ...existing, skipped: true, reason: 'fingerprint_unchanged' };
  }

  if (context.activeFindings.length === 0) {
    const empty = {
      fingerprint: '',
      cards: [],
      generatedAt: new Date().toISOString(),
    };
    if (persist) await writeInsightsBundle(email, empty);
    return { ...empty, skipped: false, reason: 'no_active_findings' };
  }

  const cards = await generateInsights(context);
  const bundle = {
    fingerprint,
    cards,
    generatedAt: new Date().toISOString(),
  };
  if (persist) await writeInsightsBundle(email, bundle);
  return { ...bundle, skipped: false, reason: 'regenerated' };
}

export async function generateInsights(context) {
  const insights = [];
  for (const finding of context.activeFindings) {
    try {
      const insight = await generateForFinding(finding, context);
      if (insight) insights.push(insight);
    } catch (err) {
      console.error(`Insight error for ${finding.key}:`, err.message);
    }
  }
  return insights;
}

/**
 * Medical KB (+ optional Tavily) → NVIDIA write → critic → safety filter.
 *
 * Default: KB-only from insights_knowledge_base.json / MEDICAL_KB.
 * Set USE_TAVILY=true only if you want extra web grounding.
 */
async function generateForFinding(finding, context) {
  const activeFindingKeys = context.activeFindings.map((f) => f.key);
  const kbChunks = await retrieveForFinding(finding.key, {
    activeFindingKeys,
    age: typeof context.profile?.age === 'number' ? context.profile.age : null,
  });

  if (!kbChunks.length) {
    console.warn(
      `No MEDICAL_KB entry for ${finding.key} — skipping (add to insights_knowledge_base.json)`,
    );
    return null;
  }

  let webSources = [];
  if (config.tavily.enabled) {
    const query =
      TAVILY_QUERIES[finding.key] || `health effects of ${finding.key}`;
    try {
      webSources = await tavilySearch(query);
    } catch (err) {
      console.warn(`Tavily skipped for ${finding.key}:`, err.message);
    }
  }

  // Optional http(s) URLs from KB; org names stay in MEDICAL_KB text.
  const kbSources = kbChunks.flatMap((c) =>
    (c.sources || [])
      .map((s) => {
        if (typeof s === 'string' && /^https?:\/\//i.test(s)) {
          return {
            title: 'Medical knowledge base',
            url: s,
            content: c.text?.slice(0, 400) || '',
          };
        }
        const url = String(s?.url || '').trim();
        if (!/^https?:\/\//i.test(url)) return null;
        return {
          title: String(s?.title || 'Medical knowledge base').trim(),
          url,
          content: c.text?.slice(0, 400) || '',
        };
      })
      .filter(Boolean),
  );
  const sources = [...kbSources, ...webSources];

  const supportingValue = context.supportingValues[finding.key] || [];
  const kbText = formatKbForPrompt(kbChunks);

  let draft = await writeInsight({
    finding,
    supportingValue,
    profile: context.profile,
    sources,
    kbText,
  });

  let validated = await critiqueInsight(
    draft,
    finding,
    sources,
    kbText,
    supportingValue,
  );

  if (!validated.passesCheck) {
    console.warn(
      `Critic rejected ${finding.key} (attempt 1): ${validated.reason}`,
    );
    draft = await writeInsight({
      finding,
      supportingValue,
      profile: context.profile,
      sources,
      kbText,
      critiqueFeedback: validated.reason,
    });
    validated = await critiqueInsight(
      draft,
      finding,
      sources,
      kbText,
      supportingValue,
    );
    if (!validated.passesCheck) {
      console.warn(
        `Critic rejected ${finding.key} (attempt 2 — dropped): ${validated.reason}`,
      );
      return null;
    }
  }

  if (conflictsWithMedications(validated.insight, context.profile)) {
    console.warn(`Dropped ${finding.key}: medication/allergy conflict`);
    return null;
  }

  const insight = validated.insight;
  return {
    ...insight,
    id: finding.key,
    supportingFindingKeys:
      insight.supportingFindingKeys?.length > 0
        ? insight.supportingFindingKeys
        : [finding.key],
  };
}

async function writeInsight({
  finding,
  supportingValue,
  profile,
  sources,
  kbText,
  critiqueFeedback,
}) {
  const feedbackBlock = critiqueFeedback
    ? `\n\nCRITIC FEEDBACK FROM PREVIOUS DRAFT (must fix):\n${critiqueFeedback}`
    : '';

  const webBlock = sources.length
    ? `\n\nOPTIONAL_WEB_SOURCES (secondary only — do not prefer over MEDICAL_KB):\n${formatSourcesForPrompt(sources)}`
    : '';

  const content = await chatJson({
    system: `You are Nemo Care's insight writer. Produce ONE educational insight as JSON only
(no markdown) with this schema:
{
  "title": "short plain title",
  "body": "2-4 short sentences. Cite the patient's actual lab values and dates when provided. No diagnosis or prescriptions. End with: This is not medical advice.",
  "category": "risk" | "remedy" | "explanation",
  "supportingFindingKeys": ["${finding.key}"],
  "sourceUrls": []
}

Rules:
- PRIMARY grounding is MEDICAL_KB (Nemo Care curated knowledge). Treat it as authoritative.
- Only use facts from FINDING, SUPPORTING VALUES, and MEDICAL_KB.
- Do not invent symptoms, risks, or remedies that are not in MEDICAL_KB.
- Avoid naming specific drugs as prescriptions; lifestyle / follow-up language only.
- Prefer category "explanation" or "risk"; use "remedy" only for general non-drug advice from MEDICAL_KB.
- sourceUrls may be empty; do not invent external URLs.`,
    user: `FINDING:
${JSON.stringify(finding)}

SUPPORTING VALUES:
${JSON.stringify(supportingValue || [], null, 2)}

PROFILE (for tone only — do not invent history):
${JSON.stringify({
  age: profile.age,
  sex: profile.sex || profile.gender,
  medications: profile.medications || [],
  allergies: profile.allergies || [],
})}

MEDICAL_KB (primary knowledge):
${kbText}${webBlock}${feedbackBlock}`,
    maxTokens: 500,
  });

  const insight = normalizeInsight(content, finding, sources);
  if (!insight.title || !insight.body) {
    throw new Error('Insight writer returned empty content');
  }
  return insight;
}

async function critiqueInsight(
  draft,
  finding,
  sources,
  kbText,
  supportingValue = [],
) {
  const content = await chatJson({
    system: `You are a strict medical-content critic for Nemo Care. Decide if a drafted insight
is faithful to the finding, supporting lab values, and MEDICAL_KB. Respond with JSON only:
{
  "passesCheck": boolean,
  "reason": "short reason",
  "title": "optional revised title if passesCheck and a small fix helps",
  "body": "optional revised body if passesCheck and a small fix helps",
  "category": "risk|remedy|explanation",
  "sourceUrls": []
}

Fail (passesCheck=false) if:
- claims risks/effects/remedies not supported by MEDICAL_KB, FINDING, or SUPPORTING VALUES
- invents lab numbers not present in SUPPORTING VALUES
- diagnoses or prescribes medication
- invents external http(s) URLs

OK / do not fail for:
- lab numbers that appear in SUPPORTING VALUES
- educational effects / follow-up tests listed in MEDICAL_KB (associative language)
- sourceOrganizations named in MEDICAL_KB
- empty sourceUrls (KB grounding is enough)

Pass when the insight is conservative and grounded in MEDICAL_KB.`,
    user: `FINDING:
${JSON.stringify(finding)}

SUPPORTING VALUES (patient lab evidence — numbers here are authoritative):
${JSON.stringify(supportingValue || [], null, 2)}

DRAFT INSIGHT:
${JSON.stringify(draft)}

MEDICAL_KB (primary knowledge):
${kbText}`,
    maxTokens: 500,
  });

  const passes = content.passesCheck === true;
  const reason = String(content.reason || '').trim() || 'Failed grounding check.';

  if (!passes) {
    return { passesCheck: false, insight: draft, reason };
  }

  const revised = {
    ...draft,
    title:
      typeof content.title === 'string' && content.title.trim()
        ? content.title.trim()
        : draft.title,
    body:
      typeof content.body === 'string' && content.body.trim()
        ? content.body.trim()
        : draft.body,
    category: normalizeCategory(content.category || draft.category),
    sourceUrls:
      Array.isArray(content.sourceUrls) && content.sourceUrls.length
        ? content.sourceUrls.map((u) => String(u).trim()).filter(Boolean)
        : draft.sourceUrls,
  };

  return { passesCheck: true, insight: revised, reason };
}

function normalizeInsight(content, finding, sources) {
  const urlsFromSources = sources
    .map((s) => String(s.url || '').trim())
    .filter(Boolean);

  return {
    id: finding.key,
    title: String(content.title || '').trim(),
    body: String(content.body || '').trim(),
    category: normalizeCategory(content.category),
    supportingFindingKeys: Array.isArray(content.supportingFindingKeys)
      ? content.supportingFindingKeys.map(String)
      : [finding.key],
    sourceUrls: Array.isArray(content.sourceUrls)
      ? content.sourceUrls.map((u) => String(u).trim()).filter(Boolean)
      : urlsFromSources,
    createdAt: new Date().toISOString(),
  };
}

function normalizeCategory(raw) {
  const text = String(raw || 'explanation').trim().toLowerCase();
  if (text === 'risk' || text === 'remedy' || text === 'explanation') return text;
  return 'explanation';
}

function conflictsWithMedications(insight, profile) {
  const meds = profile.medications || [];
  const allergies = profile.allergies || [];
  const text = `${insight.title} ${insight.body}`.toLowerCase();

  if (insight.category === 'remedy') {
    for (const allergy of allergies) {
      const a = String(allergy).toLowerCase();
      if (a.length >= 3 && text.includes(a)) return true;
    }
  }

  if (insight.category !== 'remedy') return false;
  for (const med of meds) {
    const m = String(med).toLowerCase();
    if (m.length < 3 || !text.includes(m)) continue;
    if (/\b(take|start|add|increase|dose|prescribe|try)\b/i.test(text)) {
      return true;
    }
  }
  return false;
}

function bundleFromDoc(userDoc) {
  const raw = userDoc?.insights;
  if (!raw || typeof raw !== 'object') {
    return { fingerprint: '', cards: [], generatedAt: null };
  }
  return {
    fingerprint: String(raw.fingerprint || ''),
    cards: Array.isArray(raw.cards) ? raw.cards : [],
    generatedAt: raw.generatedAt || null,
  };
}
