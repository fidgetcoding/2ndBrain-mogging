# Helper state coordination and recovery

The memory, session and intelligence helpers coordinate local mutations without installing a database or runtime package. This protocol applies to copies containing `state-lock.cjs` and the updated writers. Older copies and external tools that write these files directly do not participate.

## Mutation boundaries

`memory.js` locks set/delete/clear from the read through publication. `session.js` locks start/restore/update/metric/end, including archive publication and current-session removal. Session IDs include a UUID to keep same-timestamp archives distinct. Intelligence locks initialization, context/session changes, confidence feedback, consolidation and diagnostic reads. The auto-memory JSON backend reloads current entries under the same lock for each store/update/delete/bulk/namespace mutation; shutdown never republishes a cached snapshot.

These operations use the canonical project data directory's `.helper-state.lock`. Resolving the directory's real path coordinates symlinked project paths too. Locks are synchronous and reentrant within one module instance; they must never span an asynchronous callback. Acquisition waits at most five seconds, then fails without entering the mutation. A live owner is never evicted because of age. Lock waits and durable I/O are additional to the helpers' historical compute-budget comments.

Pending-log appenders use a separate short lock in `data/.pending-writers/`. This serializes complete append records and tail checks with other repository appenders, while allowing arrivals during graph computation. Consolidation never rewrites or truncates that log. A partially written trailing record is retained, and new repository appends refuse to join onto it until it is repaired/completed.

Ordinary exceptions release locks in `finally`. After process death, a waiter verifies the same-host owner PID is absent and makes one exclusive, retained recovery claim for that owner token before unlinking the stale lock. This prevents two reclaimers from removing a new owner's lock. PID reuse, unknown/foreign ownership, or a process dying after claiming recovery but before releasing the stale lock results in a bounded refusal. Recovery claim symlinks are retained as small forensic records. They are not expiring leases.

## Pending insight acknowledgement

`pending-insights.jsonl` remains append-only. `pending-insights-checkpoint.json` records an acknowledged byte offset and SHA-256 digest of that prefix. Consolidation reads complete newline-terminated records after the offset. Arrivals after its read remain after the next checkpoint and are processed by a later run. The existing three-edit threshold and source-file deduplication remain unchanged; below-threshold records are acknowledged per consolidation, as before.

Malformed complete records are counted in the consolidation result and remain byte-for-byte in the journal. They are acknowledged without producing an insight. An incomplete trailing record is not acknowledged. Unexpected external truncation or replacement of an acknowledged prefix fails validation instead of silently resetting the offset. No automatic log compaction is performed: the journal grows, and consolidation reads/hashes its prefix. This favors recoverability over bounded history size.

Consolidation prepares `.intelligence-transaction.json` containing the exact intended store, graph, ranked context, snapshot history and checkpoint. Atomic JSON publication flushes the temporary file, renames it, then flushes its directory. The transaction is durable before output publication begins. Every subsequent coordinated state mutation first replays any prepared transaction, then removes and flushes the transaction marker. Append-only arrivals can continue independently.

A failure before preparation leaves existing state and pending bytes unchanged. A failure or process interruption during publication leaves a replayable plan with stable insight IDs and acknowledgement. Retrying consolidation finishes that plan rather than regenerating its insights. Another writer recovers the plan before applying its own update, so recovery cannot overwrite that later update. Readers bypassing the lock can still observe a partial multi-file publication until recovery completes; individual JSON files remain complete. This transaction protocol covers consolidation, not every multi-file operation in the repository.

## Recovery boundaries

Use the next updated helper invocation for ordinary dead-owner recovery or replay of a valid prepared transaction. No integration needs to be activated to perform repository fixture verification.

For a malformed transaction, unknown lock owner, interrupted lock reclamation or altered journal prefix, stop all writers for that project and copy the complete state directory before investigation. Preserve the journal, checkpoint, transaction marker and recovery claims together. Confirm no owner remains active before moving a stale lock/claim aside. Repair malformed transaction/state data from a known consistent backup; do not delete a transaction or reset a checkpoint to make the error disappear, because that can discard an intended commit or reprocess acknowledged records.

This is cooperative local-filesystem coordination for the JSON/session files listed above. Metrics services and SQLite-based learning services use separate stores and are outside this protocol. External packages that bypass the supplied backend, manually edited files, old helper copies, remote hosts sharing a volume, and cloud/network filesystem locking/durability are outside the guarantee. Failures are surfaced by direct helper calls; existing hook wrappers may treat helper errors as nonfatal. Optional real bridge/corpus integrations were not activated or verified.

## Verification

`tests/helper_concurrency.py` uses disposable HOME, CLAUDE_HOME and project cwd, at most two child processes, synchronized barriers and a local fake bridge package. It covers competing key updates/deletes, session metrics/lifecycle and intelligence session changes, confidence updates, bridge stale snapshots, arrivals during consolidation, two consolidators, publication failures, process termination, restart/retry, retained malformed bytes, thresholds and lock refusal/recovery. Run through the shared heavy-job gate; the strict shell harness includes this suite.

The final gated run passed 24/24 targeted tests (38.439 seconds), static checks, and 13/13 strict suites with zero skips/failures (347.653 seconds). The strict run repeated all 24 helper tests (35.916 seconds) alongside 38 data-safety tests and the original 357 assertions. Source hashes matched before and after verification; subsequent edits only recorded results in documentation. Crash tests used forced process termination and injected publication failures, not physical power loss.
