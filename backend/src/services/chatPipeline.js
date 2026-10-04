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
- MEDICAL_KB (curated educational notes)
- short chat history

Rules:
- When asked for a specific lab (e.g. platelets, hemoglobin), read LATEST LAB REPORTS and quote value, unit, date, and reference range if present.
- Prefer the newest date shown for that report type.
- If the value is not in LATEST LAB REPORTS, say you do not see that parameter in the uploaded reports — do NOT invent numbers and do NOT talk about "provided data" or system instructions.
- No diagnosis and no prescriptions.
- Keep under 120 words.
- End with: Not medical advice—ask your clinician.`;

/**
 * Answer a home-chat question with the same grounding stack as Insights.
 *
 * @param {{ email: string, question: string, history?: Array<{ role: string, content: string }> }} opts
 */
export async function answerQuestion({ email, question, history = [] }) {
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

  const userPayload = `LATEST LAB REPORTS (use these for specific counts like platelets, hemoglobin, etc.):
${labsBlock}

ACTIVE FINDINGS:
${findingsBlock}

MEDICAL_KB:
${kbText}

QUESTION:
${trimmed}`;

  let reply = await chatText({
    system: SYSTEM,
    messages: [...recent, { role: 'user', content: userPayload }],
    maxTokens: 220,
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
