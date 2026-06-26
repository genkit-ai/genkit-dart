# genkit_google_cloud

Google Cloud integration for [Genkit Dart](https://github.com/genkit-ai/genkit-dart).

Currently this package provides a Firestore-backed
[`SessionStore`](https://pub.dev/documentation/genkit/latest/) for Genkit
agents: `FirestoreSessionStore`.

## Installation

```bash
dart pub add genkit_google_cloud
```

## FirestoreSessionStore

`FirestoreSessionStore` persists session snapshots as incremental
[JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) diffs anchored to
periodic, sharded full-state checkpoints. This keeps reads and document sizes
bounded regardless of how long a session grows, so it scales to arbitrarily
long sessions (long-lived chatbots, coding agents, ...) without any single
document approaching Firestore's 1 MiB per-document limit.

```dart
import 'package:genkit_google_cloud/firestore_session_store.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

final store = FirestoreSessionStore(
  // Defaults to `Firestore()`, which picks up Application Default Credentials
  // and the `FIRESTORE_EMULATOR_HOST` environment variable.
  db: Firestore(),
  collection: 'genkit-sessions',
  checkpointInterval: 25,
);
```

### Storage layout

For a per-tenant `<prefix>` (see `snapshotPathPrefix`, default `"global"`):

- `<collection>/<prefix>/snapshots/<snapshotId>` - one document per snapshot
  (a `diff` holds the patch from its parent; a `checkpoint` holds full state,
  sharded out of band).
- `<collection>-shards/<prefix>/shards/<checkpointId>_<index>` - the sharded
  full state for a checkpoint.
- `<collection>-pointers/<prefix>/pointers/<sessionId>` - one pointer per
  session at the latest leaf snapshot.

### Options

| Option | Default | Description |
| --- | --- | --- |
| `db` | `Firestore()` | The Firestore instance. |
| `collection` | `genkit-sessions` | Root collection for snapshot documents. |
| `checkpointInterval` | `25` | Turns between full-state checkpoints. Lower (e.g. 10) for small-state, read-heavy sessions; raise (e.g. 50-100) for large per-turn state. |
| `shardSize` | `512 KiB` | Max size of a single shard / diff document. |
| `snapshotPathPrefix` | `"global"` | Per-tenant prefix derived from the call `context`, for multi-tenant isolation. |
| `snapshotWatchPollInterval` | `2s` | Polling interval for `onSnapshotStateChange`. |

### Multi-tenant isolation

Provide a `snapshotPathPrefix` to scope all reads and writes to a per-tenant
sub-collection so one tenant can never see (or even address) another's
snapshots, even if they get hold of a `snapshotId`:

```dart
final store = FirestoreSessionStore(
  snapshotPathPrefix: (context) => context?['auth']?['uid'] as String? ?? 'global',
);
```

### Real-time change notifications

The Dart Firestore client has no real-time `onSnapshot` listener, so
`onSnapshotStateChange` is implemented via polling. Tune the latency with the
`snapshotWatchPollInterval` constructor argument (default 2 seconds).

## Testing against the Firestore emulator

The integration tests are gated on the `FIRESTORE_EMULATOR_HOST` environment
variable and are skipped when it is not set, so the default test run needs no
infrastructure.

Start a local Firestore emulator with either tool:

```bash
# Firebase CLI
firebase emulators:start --only firestore

# or the gcloud SDK (requires a JRE)
gcloud emulators firestore start --host-port=localhost:8080
```

Then run the tests pointing at it:

```bash
export FIRESTORE_EMULATOR_HOST=localhost:8080
export GOOGLE_CLOUD_PROJECT=demo-genkit
dart test
```

Alternatively, from the repository root, the Melos `test-firestore` script
starts the emulator and runs the tests in one step (requires `firebase-tools`
and Java 21+):

```bash
melos run test-firestore
```
