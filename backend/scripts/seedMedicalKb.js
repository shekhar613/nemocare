/**
 * Upload insights_knowledge_base.json → Firestore
 *
 *   MEDICAL_KB/{findingKey}           — parameter state entries
 *   MEDICAL_KB_COMBOS/{comboKey}      — multi-finding combination rules
 *   MEDICAL_KB_META/source            — readme + upload timestamp
 *
 * Usage (from backend/):
 *   npm run seed:kb
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from '../src/config.js';
import { flattenKnowledgeBase } from '../src/services/medicalKb.js';
import { getDb, initFirebase } from '../src/services/firestore.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function commitInChunks(db, writes, chunkSize = 400) {
  for (let i = 0; i < writes.length; i += chunkSize) {
    const batch = db.batch();
    const slice = writes.slice(i, i + chunkSize);
    for (const { ref, data } of slice) {
      batch.set(ref, data, { merge: true });
    }
    await batch.commit();
  }
}

async function main() {
  initFirebase();
  const db = getDb();

  const filePath = config.medicalKbPath;
  if (!fs.existsSync(filePath)) {
    throw new Error(`Knowledge base not found at ${filePath}`);
  }

  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const { byFindingKey, combos } = flattenKnowledgeBase(raw);
  const now = new Date().toISOString();

  const writes = [];

  for (const [findingKey, entry] of Object.entries(byFindingKey)) {
    writes.push({
      ref: db.collection(config.firebase.medicalKbCollection).doc(findingKey),
      data: {
        ...entry,
        findingKey,
        updatedAt: now,
        source: 'insights_knowledge_base.json',
      },
    });
  }

  for (const combo of combos) {
    const comboKey = String(combo.comboKey || '').trim();
    if (!comboKey) continue;
    writes.push({
      ref: db
        .collection(config.firebase.medicalKbCombosCollection)
        .doc(comboKey),
      data: {
        ...combo,
        comboKey,
        updatedAt: now,
        source: 'insights_knowledge_base.json',
      },
    });
  }

  writes.push({
    ref: db.collection('MEDICAL_KB_META').doc('source'),
    data: {
      file: 'insights_knowledge_base.json',
      readme: typeof raw._readme === 'string' ? raw._readme : '',
      findingCount: Object.keys(byFindingKey).length,
      comboCount: combos.length,
      uploadedAt: now,
    },
  });

  await commitInChunks(db, writes);

  console.log(`Seeded ${Object.keys(byFindingKey).length} findings → ${config.firebase.medicalKbCollection}`);
  console.log(`Seeded ${combos.length} combinations → ${config.firebase.medicalKbCombosCollection}`);
  console.log('Meta → MEDICAL_KB_META/source');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
