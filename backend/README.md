# Nemo Care Backend

Express API that generates **insights** from:

1. **User lab findings** (Firestore `USERS/{email}`)
2. **Medical knowledge JSON** (`data/insights_knowledge_base.json` / Firestore `MEDICAL_KB`) — **primary grounding**
3. **NVIDIA Nemotron** via LangChain (`ChatOpenAI` + NVIDIA base URL)
4. **Tavily** web search — **optional**, off by default (`USE_TAVILY=false`)

The Flutter app should call this when the evidence fingerprint changes, then keep reading `USERS/{email}.insights` for the Insights screen.

## Setup

```bash
cd backend
cp .env.example .env
# Fill NVIDIA_API_KEY, TAVILY_API_KEY
# Add Firebase service account as ./serviceAccountKey.json

npm install
npm run dev
```

Health check: [http://localhost:8080/health](http://localhost:8080/health)

### Firebase Admin

1. Firebase Console → Project settings → Service accounts → Generate new private key  
2. Save as `backend/serviceAccountKey.json` (gitignored)  
3. Or set `FIREBASE_SERVICE_ACCOUNT_JSON` in `.env`

### Seed medical KB to Firestore

Uses `data/insights_knowledge_base.json` (same as repo root file):

```bash
npm run seed:kb
```

Writes:
- `MEDICAL_KB/{findingKey}` — 23 parameter-state entries
- `MEDICAL_KB_COMBOS/{comboKey}` — combination rules
- `MEDICAL_KB_META/source` — upload metadata

## API

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness + config flags |
| `POST` | `/insights/refresh` | Generate if fingerprint changed; write Firestore |
| `GET` | `/insights/:email` | Read cached insights (no LLM) |
| `GET` | `/insights/kb/all` | List local/Firestore KB keys |
| `GET` | `/insights/kb/lookup/:findingKey` | Preview retrieval for a finding |
| `POST` | `/chat/ask` | Home chat Q&A (KB + labs + NVIDIA) |

### Refresh body

```json
{
  "email": "user@mail.com",
  "force": false,
  "persist": true
}
```

Optional: pass `"userDoc": { ... }` to skip the Firestore read (useful for tests).

### Example

```bash
curl -s -X POST http://localhost:8080/insights/refresh \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@mail.com"}'
```

With auth (`REQUIRE_AUTH=true`):

```bash
curl -s -X POST http://localhost:8080/insights/refresh \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -d '{"email":"you@mail.com"}'
```

## Pipeline

```
active findings
  → fingerprint (keys + value + date)
  → skip if unchanged
  → per finding:
       medical KB retrieve
       + Tavily search
       → NVIDIA write (LangChain)
       → critic (retry once → drop)
       → med/allergy safety filter
  → save USERS/{email}.insights + insights_meta
```

Fingerprint format matches Flutter `InsightsService.computeFingerprint`.

### Chat body

```json
{
  "email": "you@mail.com",
  "question": "Why is my MCV low?",
  "history": [
    { "role": "user", "content": "Hi" },
    { "role": "assistant", "content": "Hello — how can I help?" }
  ]
}
```

## Flutter wiring

- **Insights:** `lib/services/insights_service.dart` → `POST /insights/refresh`
- **Home chat:** `lib/services/health_agent_service.dart` → `POST /chat/ask`

Both use the same Express grounding stack (Firestore labs + MEDICAL_KB + NVIDIA).
Chat history stays on-device; the server answers one question at a time.

Default base URL:
- iOS simulator / desktop: `http://localhost:8080`
- Android emulator: `http://10.0.2.2:8080`
- Physical device:  
  `flutter run --dart-define=BACKEND_BASE_URL=http://<your-lan-ip>:8080`

## Env reference

See `.env.example` for `NVIDIA_*`, `TAVILY_*`, Firebase, `REQUIRE_AUTH`, `CORS_ORIGIN`.
