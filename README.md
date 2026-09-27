# Nemo Care

Personal health records companion built with Flutter and Firebase Auth.

## Groq medical document verification

Uploads are checked with [Groq](https://console.groq.com/keys) before they are
added to the health timeline:

1. You pick a **PDF** or **image** (PNG / JPG).
2. Groq reads the content (vision model) and extracts key text.
3. If the file is **not medical**, it is rejected with a short reason.
4. If it **is medical**, a timeline entry is created from the AI summary.

### API key

1. Create a key at [console.groq.com/keys](https://console.groq.com/keys).
2. Either:
   - Copy `lib/config/groq_secrets.example.dart` → `lib/config/groq_secrets.dart` and paste your key (this file is gitignored), or
   - Pass it at run time:

```bash
flutter run --dart-define=GROQ_API_KEY=gsk_your_key_here
```

## Getting started

```bash
flutter pub get
flutter run --dart-define=GROQ_API_KEY=gsk_your_key_here
```
