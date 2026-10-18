import {
  buildPatientContext,
  fetchUserDoc,
  latestReportsSummary,
} from './firestore.js';
import {
  formatKbForPrompt,
  loadMedicalKb,
  retrieveForFinding,
} from './medicalKb.js';
import { chatText } from './nvidia.js';

const SYSTEM = `You are Nemo Care, a personal health records companion.
Answer the user's question using ONLY the data blocks in the message:
- LATEST LAB REPORTS (full values from the newest report of each type)
- ACTIVE FINDINGS (abnormal patterns derived from those labs)
- PATIENT PROFILE (onboarding: name, age/DOB, sex, height, weight, BMI, blood group, conditions, allergies, medications, lifestyle, pregnancy)
- MEDICAL_KB (curated educational notes)
- short chat history

Rules:
- Profile / medical-history questions (name, age, height, weight, BMI, blood group, conditions, allergies, meds, smoking, alcohol, diet, activity, pregnancy): answer from PATIENT PROFILE. Quote the saved fields plainly. If a field is empty, say it was not provided during onboarding.
- When asked for a specific lab (e.g. platelets, hemoglobin), read LATEST LAB REPORTS and quote value, unit, date, and reference range if present.
- Prefer the newest date shown for that report type.
- Respect drug allergies and current medications — never suggest a drug that conflicts.
- If height/weight are marked approximate, say the value is approximate.
- If the value is not in LATEST LAB REPORTS or PATIENT PROFILE as relevant, say you do not see that in the saved profile or uploaded reports — do NOT invent numbers and do NOT talk about "provided data" or system instructions.
- No diagnosis and no prescriptions.
- Keep under 140 words.
- End with: Not medical advice—ask your clinician.`;

/**
 * Answer a home-chat question with the same grounding stack as Insights.
 *
 * @param {{
 *   email: string,
 *   question: string,
 *   history?: Array<{ role: string, content: string }>,
 *   comparisonContext?: object | null,
 * }} opts
 */
export async function answerQuestion({
  email,
  question,
  history = [],
  comparisonContext = null,
}) {
  const trimmed = String(question || '').trim();
  if (!trimmed) {
    throw new Error('question is required');
  }

  const userDoc = await fetchUserDoc(email);
  if (!userDoc) {
    throw new Error(`User document not found for ${email}`);
  }

  const context = buildPatientContext(userDoc);
  const latestReports = latestReportsSummary(userDoc, {
    maxReports: 3,
    maxValues: 50,
  });
  const activeFindingKeys = context.activeFindings.map((f) => f.key);
  const age =
    typeof context.profile?.age === 'number' ? context.profile.age : null;

  const hasComparison =
    comparisonContext &&
    typeof comparisonContext === 'object' &&
    (Array.isArray(comparisonContext.increased) ||
      Array.isArray(comparisonContext.decreased) ||
      Array.isArray(comparisonContext.unchanged));

  const relevantKeys = selectRelevantFindingKeys(trimmed, activeFindingKeys);
  const kbChunks = [];
  const seen = new Set();

  for (const key of relevantKeys) {
    const chunks = await retrieveForFinding(key, {
      activeFindingKeys,
      age,
    });
    for (const chunk of chunks) {
      const id = chunk.findingKey || chunk.title;
      if (seen.has(id)) continue;
      seen.add(id);
      kbChunks.push(chunk);
    }
  }

  if (!kbChunks.length) {
    const { byFindingKey } = await loadMedicalKb();
    const q = trimmed.toLowerCase();
    for (const [key, entry] of Object.entries(byFindingKey)) {
      const hay = `${key} ${entry.title || ''} ${entry.displayName || ''} ${entry.parameterKey || ''}`.toLowerCase();
      if (q.split(/\s+/).some((w) => w.length > 3 && hay.includes(w))) {
        const chunks = await retrieveForFinding(key, { activeFindingKeys, age });
        kbChunks.push(...chunks.slice(0, 1));
        if (kbChunks.length >= 3) break;
      }
    }
  }

  const findingsBlock = context.activeFindings.length
    ? context.activeFindings
        .map(
          (f) =>
            `- ${f.key} (since ${f.sinceDate}; from ${(f.derivedFrom || []).join(', ')})`,
        )
        .join('\n')
    : '(none)';

  const labsBlock = latestReports.length
    ? JSON.stringify(latestReports, null, 2)
    : '(no uploaded lab reports)';

  const kbText = formatKbForPrompt(kbChunks.slice(0, 6));

  const recent = (Array.isArray(history) ? history : [])
    .filter((h) => h && (h.role === 'user' || h.role === 'assistant'))
    .slice(-4)
    .map((h) => ({
      role: h.role,
      content: String(h.content || '').slice(0, 600),
    }));

  const p = context.profile || {};
  const profileBlock = JSON.stringify(
    {
      name: p.name || '',
      dob: p.dob || '',
      age: p.age ?? null,
      ageRange: p.ageRange || '',
      ageApproximate: p.ageApproximate === true,
      sex: p.sex || '',
      genderIdentity: p.genderIdentity || '',
      height_cm: p.height_cm || '',
      weight_kg: p.weight_kg || '',
      bmi: p.bmi || '',
      heightApproximate: p.heightApproximate === true,
      weightApproximate: p.weightApproximate === true,
      bloodGroup: p.bloodGroup || '',
      knownConditions: p.knownConditions || [],
      onDialysis: p.onDialysis === true,
      eyeConditions: p.eyeConditions || [],
      skinConditions: p.skinConditions || [],
      foodIntolerances: p.foodIntolerances || [],
      medications: p.medications || [],
      currentMedications: p.currentMedications || [],
      drugAllergies: p.drugAllergies || [],
      otherAllergies: p.otherAllergies || [],
      allergies: p.allergies || [],
      smokingStatus: p.smokingStatus || '',
      alcoholUse: p.alcoholUse || '',
      dietPreference: p.dietPreference || '',
      activityLevel: p.activityLevel || '',
      pregnancyStatus: p.pregnancyStatus || '',
    },
    null,
    2,
  );

  const comparisonBlock = hasComparison
    ? JSON.stringify(comparisonContext, null, 2)
    : '';

  const system = hasComparison
    ? `${SYSTEM}

When REPORT COMPARISON is present, write ONLY a short "What this means" insight (2-3 sentences) grounded in those deltas and MEDICAL_KB / reference ranges. Do not re-list every metric — the app already shows Increased/Decreased/Unchanged cards. No diagnosis or prescriptions.`
    : SYSTEM;

  const userPayload = hasComparison
    ? `REPORT COMPARISON (already shown as cards in the app — write the insight only):
${comparisonBlock}

LATEST LAB REPORTS:
${labsBlock}

ACTIVE FINDINGS:
${findingsBlock}

PATIENT PROFILE:
${profileBlock}

MEDICAL_KB:
${kbText}

QUESTION:
${trimmed}`
    : `LATEST LAB REPORTS (use these for specific counts like platelets, hemoglobin, etc.):
${labsBlock}

ACTIVE FINDINGS:
${findingsBlock}

PATIENT PROFILE:
${profileBlock}

MEDICAL_KB:
${kbText}

QUESTION:
${trimmed}`;

  let reply = await chatText({
    system,
    messages: [...recent, { role: 'user', content: userPayload }],
    maxTokens: hasComparison ? 160 : 220,
    temperature: 0.2,
  });

  reply = sanitizeReply(reply);

  if (!reply) {
    throw new Error('Model returned an empty reply');
  }

  return {
    reply,
    activeFindings: activeFindingKeys,
    kbKeys: kbChunks.map((c) => c.findingKey).filter(Boolean),
    reportDates: latestReports.map((r) => `${r.reportType}/${r.date}`),
    comparison: hasComparison ? comparisonContext : null,
  };
}

function sanitizeReply(text) {
  let out = String(text || '').trim();
  // Drop leaked meta / instruction-style lines.
  const bad = [
    /your response should be seen in the provided data/i,
    /only use the (provided )?data/i,
    /as an ai language model/i,
  ];
  for (const re of bad) {
    if (re.test(out) && out.length < 180) {
      return 'I could not form a clear answer from your uploaded reports. Try asking again with the test name (for example: platelets on my latest CBC). Not medical advice—ask your clinician.';
    }
  }
  return out;
}

function selectRelevantFindingKeys(question, activeFindingKeys) {
  if (!activeFindingKeys.length) return [];
  const q = question.toLowerCase();
  const matched = activeFindingKeys.filter((key) => {
    const parts = key.toLowerCase().split('_');
    return parts.some((p) => p.length > 2 && q.includes(p));
  });
  if (!matched.length) return activeFindingKeys.slice(0, 5);
  return matched.slice(0, 5);
}
