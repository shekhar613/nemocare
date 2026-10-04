# Nemo Care

Personal health records companion built with Flutter and Firebase Auth.

## Firestore user data shape

Collection: `USERS`  
Document id: user email (lowercase)

```
USERS/{email}
  name, dob, gender, height_cm, weight_kg, bmi, married   // profile (empty strings at signup)
  cbc: {
    "2026-09-14": { docType, labName, values[], ... }
  }
  lipid_profile: {
    "2026-08-01": { ... }
  }
```

Same report type + new date → nested under the same report key with a new date key.

## Groq medical document verification

Uploads are checked with [Groq](https://console.groq.com/keys) before they are
added to the health timeline:

1. You pick a **PDF** or **image** (PNG / JPG).
2. Groq reads the content (vision model) and extracts key text.
3. If the file is **not medical**, it is rejected with a short reason.
4. If it **is medical**, a timeline entry is created from the AI summary.

### Groq API key

1. Create a key at [console.groq.com/keys](https://console.groq.com/keys).
2. Either:
   - Copy `lib/config/groq_secrets.example.dart` → `lib/config/groq_secrets.dart` and paste your key (this file is gitignored), or
   - Pass it at run time:

```bash
flutter run --dart-define=GROQ_API_KEY=gsk_your_key_here
```

## Nemotron health agent (prompt)

The Home prompt (“Ask about your health reports”) is powered by NVIDIA
[Nemotron](https://build.nvidia.com)
(`nvidia/nemotron-3-nano-30b-a3b`). It answers questions using your
uploaded reports from Firestore as context.

### NVIDIA API key

1. Create a key at [build.nvidia.com](https://build.nvidia.com).
2. Either:
   - Copy `lib/config/nvidia_secrets.example.dart` → `lib/config/nvidia_secrets.dart` and paste your key (gitignored), or
   - Pass it at run time:

```bash
flutter run --dart-define=NVIDIA_API_KEY=nvapi_your_key_here
```

## Insights (Tavily + Nemotron)

`InsightsService` turns active findings into grounded educational cards:

1. Build `PatientContext` (profile + findings + supporting lab values)
2. Tavily search per finding
3. Nemotron writes a draft insight
4. Nemotron critic checks grounding against sources
5. Medication / allergy safety filter

### Tavily API key

1. Create a key at [app.tavily.com](https://app.tavily.com).
2. Either:
   - Copy `lib/config/tavily_secrets.example.dart` → `lib/config/tavily_secrets.dart`, or
   - Pass `--dart-define=TAVILY_API_KEY=...`

## Getting started

```bash
flutter pub get
flutter run \
  --dart-define=GROQ_API_KEY=gsk_your_key_here \
  --dart-define=NVIDIA_API_KEY=nvapi_your_key_here \
  --dart-define=TAVILY_API_KEY=tvly_your_key_here
```

## Firestore rules note

Allow authenticated users to read/write only their own `USERS/{email}` document
(email must match `request.auth.token.email`).
