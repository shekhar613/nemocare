import fs from 'fs/promises';
import { config } from '../config.js';
import { getDb } from './firestore.js';

let localIndex = null; // { byFindingKey, combos }

/**
 * Flatten insights_knowledge_base.json → findingKey map + combinations.
 */
export function flattenKnowledgeBase(raw) {
  const byFindingKey = {};
  const parameters = Array.isArray(raw?.parameters) ? raw.parameters : [];

  for (const param of parameters) {
    const parameterKey = String(param.parameterKey || '').trim();
    const displayName = String(param.displayName || parameterKey);
    const states = param.states && typeof param.states === 'object' ? param.states : {};

    for (const [state, body] of Object.entries(states)) {
      if (!body || typeof body !== 'object') continue;
      const findingKey = String(body.findingKey || '').trim();
      if (!findingKey) continue;
      byFindingKey[findingKey] = {
        ...body,
        findingKey,
        parameterKey,
        displayName,
        state,
        title: `${displayName} (${state})`,
        source: 'local',
      };
    }
  }

  // Legacy flat map format (old medical_kb.json)
  if (!parameters.length && raw && typeof raw === 'object' && !raw._readme) {
    for (const [key, value] of Object.entries(raw)) {
      if (key.startsWith('_')) continue;
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        byFindingKey[key] = {
          ...value,
          findingKey: value.findingKey || key,
          source: 'local',
        };
      }
    }
  }

  const combos = Array.isArray(raw?.combinations) ? raw.combinations : [];
  return { byFindingKey, combos };
}

async function loadLocalIndex() {
  if (localIndex) return localIndex;
  try {
    const text = await fs.readFile(config.medicalKbPath, 'utf8');
    localIndex = flattenKnowledgeBase(JSON.parse(text));
  } catch (err) {
    console.warn('insights_knowledge_base.json not loaded:', err.message);
    localIndex = { byFindingKey: {}, combos: [] };
  }
  return localIndex;
}

/**
 * Merge local JSON with Firestore MEDICAL_KB + MEDICAL_KB_COMBOS.
 */
export async function loadMedicalKb() {
  const local = await loadLocalIndex();
  const merged = { ...local.byFindingKey };
  let combos = [...local.combos];

  try {
    const db = getDb();
    const snap = await db.collection(config.firebase.medicalKbCollection).get();
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const key = String(data.findingKey || doc.id).trim();
      if (!key) continue;
      merged[key] = {
        ...(merged[key] || {}),
        ...data,
        findingKey: key,
        source: data.source || 'firestore',
      };
    }

    const comboSnap = await db
      .collection(config.firebase.medicalKbCombosCollection)
      .get();
    if (!comboSnap.empty) {
      combos = comboSnap.docs.map((d) => ({
        ...(d.data() || {}),
        comboKey: d.id,
        source: 'firestore',
      }));
    }
  } catch (err) {
    console.warn('MEDICAL_KB Firestore skip:', err.message);
  }

  return { byFindingKey: merged, combos };
}

/**
 * Retrieve KB entry for a finding (+ matching combination rules).
 *
 * @param {string} findingKey
 * @param {{ activeFindingKeys?: string[], age?: number|null }} [ctx]
 */
export async function retrieveForFinding(findingKey, ctx = {}) {
  const { byFindingKey, combos } = await loadMedicalKb();
  const chunks = [];

  const direct = byFindingKey[findingKey];
  if (direct) {
    chunks.push(toChunk(direct));
  } else {
    const keyLower = findingKey.toLowerCase();
    const tagged = Object.values(byFindingKey).filter((entry) => {
      const tags = Array.isArray(entry.tags) ? entry.tags : [];
      return tags.some((t) => String(t).toLowerCase().includes(keyLower));
    });
    chunks.push(...tagged.slice(0, 3).map(toChunk));
  }

  const active = new Set(
    (ctx.activeFindingKeys || [findingKey]).map((k) => String(k)),
  );
  const age = typeof ctx.age === 'number' ? ctx.age : null;

  for (const combo of combos) {
    const required = Array.isArray(combo.requiredFindings)
      ? combo.requiredFindings
      : [];
    if (!required.length) continue;
    if (!required.every((k) => active.has(k))) continue;
    if (!required.includes(findingKey)) continue;

    const profile = combo.requiredProfile || {};
    if (profile.minAge != null && (age == null || age < profile.minAge)) {
      continue;
    }
    chunks.push(toComboChunk(combo));
  }

  return chunks;
}

function toChunk(entry) {
  const lines = [
    entry.title || entry.displayName || entry.findingKey,
    entry.severityNote ? `Severity note: ${entry.severityNote}` : '',
    entry.summary || '',
    listBlock('Common causes', entry.commonCauses),
    listBlock('Possible effects', entry.possibleEffects || entry.risks),
    ageBlock(entry.ageConsiderations),
    listBlock('Recommended follow-up tests', entry.recommendedFollowUpTests),
    listBlock(
      'Lifestyle notes',
      entry.generalLifestyleNotes || entry.remedies,
    ),
    entry.evidenceLevel ? `Evidence level: ${entry.evidenceLevel}` : '',
  ].filter(Boolean);

  const orgs = Array.isArray(entry.sourceOrganizations)
    ? entry.sourceOrganizations
    : [];
  const sources = Array.isArray(entry.sources) ? entry.sources : [];

  return {
    findingKey: entry.findingKey,
    title: entry.title || entry.findingKey,
    text: lines.join('\n'),
    sources: [
      ...sources,
      ...orgs.map((name) => ({ title: name, url: '' })),
    ],
    raw: entry,
  };
}

function toComboChunk(combo) {
  const lines = [
    `COMBINATION: ${combo.title || combo.comboKey}`,
    combo.combinedRisk ? `Combined risk: ${combo.combinedRisk}` : '',
    listBlock('Possible effects', combo.possibleEffects),
    listBlock('Recommended follow-up tests', combo.recommendedFollowUpTests),
    combo.evidenceLevel ? `Evidence level: ${combo.evidenceLevel}` : '',
  ].filter(Boolean);

  const orgs = Array.isArray(combo.sourceOrganizations)
    ? combo.sourceOrganizations
    : [];

  return {
    findingKey: combo.comboKey,
    title: combo.title || combo.comboKey,
    text: lines.join('\n'),
    sources: orgs.map((name) => ({ title: name, url: '' })),
    raw: combo,
  };
}

function listBlock(label, items) {
  if (!Array.isArray(items) || !items.length) return '';
  return `${label}:\n${items.map((i) => `- ${i}`).join('\n')}`;
}

function ageBlock(items) {
  if (!Array.isArray(items) || !items.length) return '';
  return `Age considerations:\n${items
    .map((a) => `- [${a.ageRange || 'n/a'}] ${a.note || ''}`)
    .join('\n')}`;
}

export function formatKbForPrompt(chunks) {
  if (!chunks?.length) return '(no medical KB entries for this finding)';
  return chunks
    .map((c, i) => {
      const orgs = (c.sources || [])
        .map((s) => (typeof s === 'string' ? s : s.title || s.url))
        .filter(Boolean)
        .join(', ');
      return `${i + 1}. ${c.title}\n${c.text}${orgs ? `\nKB orgs/sources: ${orgs}` : ''}`;
    })
    .join('\n\n');
}
