// Persist whole JSON documents without exposing a truncated file to readers.
const fs = require('fs');
const path = require('path');
const { randomBytes } = require('crypto');

function readJSON(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    // Never turn malformed or unreadable existing state into an empty store.
    throw new Error(`Cannot read JSON state: ${file}`, { cause: error });
  }
}

function writeJSON(file, data) {
  const serialized = JSON.stringify(data, null, 2);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${process.pid}.${randomBytes(8).toString('hex')}.tmp`;
  try {
    const fd = fs.openSync(temporary, 'wx', 0o600);
    try { fs.writeFileSync(fd, serialized, 'utf8'); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
    fs.renameSync(temporary, file);
    syncDirectory(path.dirname(file));
  } finally {
    try { fs.unlinkSync(temporary); } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
}

function syncDirectory(directory) {
  const fd = fs.openSync(directory, 'r');
  try { fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
}

const TRANSACTION = '.intelligence-transaction.json';
const OUTPUTS = new Set(['auto-memory-store.json', 'graph-state.json', 'ranked-context.json',
  'intelligence-snapshot.json', 'pending-insights-checkpoint.json']);

function validateBatch(plan) {
  if (!plan || plan.version !== 1 || !Array.isArray(plan.files) || plan.files.length !== OUTPUTS.size
      || new Set(plan.files.map(item => item && item.name)).size !== OUTPUTS.size
      || !plan.files.every(item => item && OUTPUTS.has(item.name) && Object.hasOwn(item, 'data')
        && (['auto-memory-store.json', 'intelligence-snapshot.json'].includes(item.name)
          ? Array.isArray(item.data)
          : item.data && typeof item.data === 'object' && !Array.isArray(item.data)))) {
    throw new Error('Invalid intelligence transaction; preserve it for recovery');
  }
}

// Caller must hold the project-state lock. A durable plan is the commit
// decision; publication can then be retried without regenerating insight IDs.
function recoverJSONBatch(directory) {
  const journal = path.join(directory, TRANSACTION);
  const plan = readJSON(journal);
  if (plan === null) {
    if (fs.existsSync(journal)) throw new Error('Invalid null intelligence transaction; preserve it for recovery');
    return null;
  }
  validateBatch(plan);
  for (const item of plan.files) writeJSON(path.join(directory, item.name), item.data);
  fs.unlinkSync(journal);
  syncDirectory(directory);
  return plan.result;
}

function commitJSONBatch(directory, files, result) {
  const plan = { version: 1, files, result };
  validateBatch(plan);
  if (fs.existsSync(path.join(directory, TRANSACTION))) throw new Error('Recover pending transaction before committing');
  writeJSON(path.join(directory, TRANSACTION), plan);
  return recoverJSONBatch(directory);
}

module.exports = { readJSON, writeJSON, commitJSONBatch, recoverJSONBatch };
