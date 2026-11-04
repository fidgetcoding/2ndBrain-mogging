// Cooperative, bounded locks for repository-owned helper mutations.
// No lease expiry: a slow/live owner must never lose its lock.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { performance } = require('perf_hooks');
const { randomUUID, createHash } = require('crypto');
const { recoverJSONBatch } = require('./atomic-json.cjs');
const held = new Set();
const sleeper = new Int32Array(new SharedArrayBuffer(4));

function deadOwner(token) {
  try {
    const owner = JSON.parse(token);
    if (owner.host !== os.hostname() || !Number.isSafeInteger(owner.pid) || owner.pid < 1) return false;
    try { process.kill(owner.pid, 0); } catch (error) { return error.code === 'ESRCH'; }
  } catch { /* Unknown ownership is never grounds to steal a lock. */ }
  return false;
}

function reapDeadOwner(lock, token, claimant) {
  if (!deadOwner(token)) return;
  // One retained claim per dead owner prevents competing reapers from
  // unlinking a newly acquired lock. An interrupted reaper fails closed;
  // its claim and lock can be inspected/recovered with all helpers stopped.
  const claim = `${lock}.reaped-${createHash('sha256').update(token).digest('hex')}`;
  try { fs.symlinkSync(claimant, claim); } catch (error) {
    if (error.code === 'EEXIST') return;
    throw error;
  }
  try {
    if (fs.readlinkSync(lock) === token) fs.unlinkSync(lock);
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
}

function synchronous(action, recovered) {
  const result = action(recovered);
  if (result && typeof result.then === 'function') throw new Error('State lock callbacks must be synchronous');
  return result;
}

function withStateLock(directory, action, { timeoutMs = 5000 } = {}) {
  fs.mkdirSync(directory, { recursive: true });
  // Resolve symlinked project roots so participating writers share one lock.
  const canonical = fs.realpathSync(directory);
  if (held.has(canonical)) return synchronous(action, null);
  const lock = path.join(canonical, '.helper-state.lock');
  const token = JSON.stringify({ host: os.hostname(), pid: process.pid, nonce: randomUUID() });
  const deadline = performance.now() + timeoutMs;
  while (true) {
    try { fs.symlinkSync(token, lock); break; } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      try { reapDeadOwner(lock, fs.readlinkSync(lock), token); } catch (readError) {
        if (readError.code !== 'ENOENT' && readError.code !== 'EINVAL') throw readError;
      }
      if (performance.now() >= deadline) throw new Error(`Timed out waiting for helper state lock: ${lock}`);
      Atomics.wait(sleeper, 0, 0, 10);
    }
  }
  held.add(canonical);
  try {
    // Roll forward a prepared consolidation before any later mutation can
    // be overwritten by recovery. Never reset a malformed transaction.
    return synchronous(action, recoverJSONBatch(canonical));
  } finally {
    held.delete(canonical);
    if (fs.readlinkSync(lock) === token) fs.unlinkSync(lock);
  }
}

module.exports = { withStateLock };
