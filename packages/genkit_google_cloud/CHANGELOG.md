## 0.1.0

- Initial release.
- Add `FirestoreSessionStore`: a Firestore-backed `SessionStore` that persists
  session snapshots as incremental JSON Patch diffs anchored to periodic,
  sharded full-state checkpoints (ported from the Genkit JS
  `FirestoreSessionStore`).
