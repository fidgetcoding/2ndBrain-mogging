#!/usr/bin/env node
/* Vendored from FidgetFlo (fidgetcoding/fidgetflo) — a FidgetFlo-internal build
 * descended from ruvnet/ruflo@v3.5.80 with additional pattern-graph logic
 * extended by <ORG-A>. This file is FidgetFlo-era (not present in the ruflo
 * v3.5.80 public tag). Upstream root: https://github.com/ruvnet/ruflo/tree/v3.5.80
 * License:   MIT (c) 2024-2026 ruvnet, (c) 2026 <ORG-A> / the operator
 * Synced:    2026-04-20
 * See:       docs/CREDITS.md for the full attribution chain + NOTICE for license text.
 */
/**
 * Claude Flow Memory Helper
 * Simple key-value memory for cross-session context
 */

const path = require('path');

const MEMORY_DIR = path.join(process.cwd(), '.claude-flow', 'data');
const MEMORY_FILE = path.join(MEMORY_DIR, 'memory.json');

const { readJSON, writeJSON } = require('./atomic-json.cjs');
const { withStateLock } = require('./state-lock.cjs');
function loadMemory() { return readJSON(MEMORY_FILE, {}); }
function saveMemory(memory) { writeJSON(MEMORY_FILE, memory); }

const commands = {
  get: (key) => {
    const memory = loadMemory();
    const value = key ? memory[key] : memory;
    console.log(JSON.stringify(value, null, 2));
    return value;
  },

  set: (key, value) => {
    if (!key) {
      console.error('Key required');
      return;
    }
    const memory = loadMemory();
    memory[key] = value;
    memory._updated = new Date().toISOString();
    saveMemory(memory);
    console.log(`Set: ${key}`);
  },

  delete: (key) => {
    if (!key) {
      console.error('Key required');
      return;
    }
    const memory = loadMemory();
    delete memory[key];
    saveMemory(memory);
    console.log(`Deleted: ${key}`);
  },

  clear: () => {
    saveMemory({});
    console.log('Memory cleared');
  },

  keys: () => {
    const memory = loadMemory();
    const keys = Object.keys(memory).filter(k => !k.startsWith('_'));
    console.log(keys.join('\n'));
    return keys;
  },
};

for (const name of ['set', 'delete', 'clear']) {
  const mutate = commands[name];
  commands[name] = (...args) => withStateLock(MEMORY_DIR, () => mutate(...args));
}

// CLI (imports have no side effects).
if (require.main === module) {
  const [,, command, key, ...valueParts] = process.argv;
  const value = valueParts.join(' ');

  if (command && commands[command]) {
    commands[command](key, value);
  } else {
    console.log('Usage: memory.js <get|set|delete|clear|keys> [key] [value]');
  }
}

module.exports = commands;
