import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/secrets/keyring_secret_store.dart';
import '../../infra/ssh/dartssh2_connector.dart';
import '../ports/secret_store.dart';
import '../ports/session_prompts.dart';
import '../ports/ssh_transport.dart';

/// Реализации портов. UI переопределяет [sessionPromptsProvider] в main.dart.
final sshConnectorProvider = Provider<SshConnector>((ref) => const DartSsh2Connector());
final secretStoreProvider = Provider<SecretStore>((ref) => KeyringSecretStore());
final sessionPromptsProvider = Provider<SessionPrompts>(
  (ref) => throw UnimplementedError('sessionPromptsProvider должен быть переопределён'),
);

