import 'nvidia_secrets.dart';

/// NVIDIA Integrate API settings for the Nemo Care health agent.
///
/// Priority:
/// 1. `--dart-define=NVIDIA_API_KEY=...` at run/build time
/// 2. Local `nvidia_secrets.dart` (gitignored — see `nvidia_secrets.example.dart`)
///
/// Create keys at https://build.nvidia.com
class NvidiaConfig {
  NvidiaConfig._();

  static const String apiKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
    defaultValue: nvidiaApiKeyLocal,
  );

  static const String baseUrl = 'https://integrate.api.nvidia.com/v1';

  /// Fast Nemotron Lightning model for low-latency health Q&A.
  /// (Previous `nemotron-3-nano-30b-a3b` reached EOL on NVIDIA Integrate.)
  static const String chatModel = 'nvidia/nemotron-3.5-lightning-30b-a3b';

  static bool get isConfigured => apiKey.isNotEmpty;
}
