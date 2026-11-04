#!/usr/bin/env node
/* Vendored from FidgetFlo (fidgetcoding/fidgetflo) — a FidgetFlo-internal build
 * descended from ruvnet/ruflo@v3.5.80 with additional pattern-graph logic
 * extended by <ORG-A>. Upstream: https://github.com/ruvnet/ruflo/tree/v3.5.80
 * License:   MIT (c) 2024-2026 ruvnet, (c) 2026 <ORG-A> / the operator
 * Synced:    2026-04-20
 * See:       docs/CREDITS.md for the full attribution chain + NOTICE for license text.
 */
/**
 * Claude Flow Hook Handler (Cross-Platform)
 * Dispatches hook events to the appropriate helper modules.
 *
 * Usage: node hook-handler.cjs <command> [args...]
 *
 * Commands:
 *   route          - Route a task to optimal agent (reads PROMPT from env/stdin)
 *   pre-bash       - Validate command safety before execution
 *   post-edit      - Record edit outcome for learning
 *   session-restore - Restore previous session state
 *   session-end    - End session and persist state
 */

const path = require('path');
const fs = require('fs');

const helpersDir = __dirname;

// Safe require with stdout suppression - the helper modules have CLI
// sections that run unconditionally on require(), so we mute console
// during the require to prevent noisy output.
function safeRequire(modulePath) {
  try {
    if (fs.existsSync(modulePath)) {
      const origLog = console.log;
      const origError = console.error;
      console.log = () => {};
      console.error = () => {};
      try {
        const mod = require(modulePath);
        return mod;
      } finally {
        console.log = origLog;
        console.error = origError;
      }
    }
  } catch (e) {
    // silently fail
  }
  return null;
}

// Resolve modules only for the event that uses them.
let router, session, intelligence;

// Get the command from argv
const [,, command, ...args] = process.argv;

// Read stdin with timeout — Claude Code sends hook data as JSON via stdin.
// Timeout prevents hanging when stdin is not properly closed (common on Windows).
async function readStdin() {
  if (process.stdin.isTTY) return '';
  return new Promise((resolve) => {
    let data = '';
    const timer = setTimeout(() => {
      process.stdin.removeAllListeners();
      process.stdin.pause();
      resolve(data);
    }, 500);
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => { clearTimeout(timer); resolve(data); });
    process.stdin.on('error', () => { clearTimeout(timer); resolve(data); });
    process.stdin.resume();
  });
}

async function main() {
  let stdinData = '';
  try { stdinData = await readStdin(); } catch (e) { /* ignore stdin errors */ }

  let hookInput = {};
  if (stdinData.trim()) {
    try { hookInput = JSON.parse(stdinData); } catch (e) { /* ignore parse errors */ }
  }

  const toolInput = hookInput.tool_input || hookInput.toolInput || {};
  const promptValue = hookInput.prompt || hookInput.command || toolInput.command
    || process.env.PROMPT || process.env.TOOL_INPUT_command || args.join(' ') || '';
  const prompt = typeof promptValue === 'string' ? promptValue : '';
  if (['route', 'pre-task'].includes(command)) router = safeRequire(path.join(helpersDir, 'router.js'));
  if (['post-edit', 'session-restore', 'session-end', 'pre-task'].includes(command)) session = safeRequire(path.join(helpersDir, 'session.js'));
  if (['route', 'post-edit', 'session-restore', 'session-end', 'post-task', 'stats'].includes(command)) intelligence = safeRequire(path.join(helpersDir, 'intelligence.cjs'));

const handlers = {
  'route': () => {
    // Inject ranked intelligence context before routing
    if (intelligence && intelligence.getContext) {
      try {
        const ctx = intelligence.getContext(prompt);
        if (ctx) console.log(ctx);
      } catch (e) { /* non-fatal */ }
    }
    if (router && router.routeTask) {
      const result = router.routeTask(prompt);
      console.log(`[INFO] Agent: ${result.agent}; rule score: ${result.confidence}; ${result.reason}`);
    } else {
      console.log('[INFO] Router not available, using default routing');
    }
  },

  'pre-bash': () => {
    // Basic command safety check — prefer stdin command data from Claude Code
    const cmd = prompt.toLowerCase();
    const dangerous = ['rm -rf /', 'format c:', 'del /s /q c:\\', ':(){:|:&};:'];
    for (const d of dangerous) {
      if (cmd.includes(d)) {
        console.error(`[BLOCKED] Dangerous command detected: ${d}`);
        process.exit(2);
      }
    }
    console.log('[OK] Command validated');
  },

  'post-edit': () => {
    // Record edit for session metrics
    if (session && session.metric) {
      try { session.metric('edits'); } catch (e) { /* no active session */ }
    }
    // Record edit for intelligence consolidation — prefer stdin data from Claude Code
    if (intelligence && intelligence.recordEdit) {
      try {
        const file = toolInput.file_path || hookInput.file_path
          || process.env.TOOL_INPUT_file_path || args[0] || '';
        intelligence.recordEdit(file);
      } catch (e) { /* non-fatal */ }
    }
    console.log('[OK] Edit recorded');
  },

  'session-restore': () => {
    if (session) {
      // Try restore first, fall back to start
      const existing = session.restore && session.restore();
      if (!existing) {
        session.start && session.start();
      }
    } else {
      // Minimal session restore output
      const sessionId = `session-${Date.now()}`;
      console.log(`[INFO] Restoring session: %SESSION_ID%`);
      console.log('');
      console.log(`[OK] Session restored from %SESSION_ID%`);
      console.log(`New session ID: ${sessionId}`);
      console.log('');
      console.log('Restored State');
      console.log('+----------------+-------+');
      console.log('| Item           | Count |');
      console.log('+----------------+-------+');
      console.log('| Tasks          |     0 |');
      console.log('| Agents         |     0 |');
      console.log('| Memory Entries |     0 |');
      console.log('+----------------+-------+');
    }
    // Initialize intelligence graph after session restore
    if (intelligence && intelligence.init) {
      try {
        const result = intelligence.init();
        if (result && result.nodes > 0) {
          console.log(`[INTELLIGENCE] Loaded ${result.nodes} patterns, ${result.edges} edges`);
        }
      } catch (e) { /* non-fatal */ }
    }
  },

  'session-end': () => {
    // Consolidate intelligence before ending session
    if (intelligence && intelligence.consolidate) {
      try {
        const result = intelligence.consolidate();
        if (result && result.entries > 0) {
          console.log(`[INTELLIGENCE] Consolidated: ${result.entries} entries, ${result.edges} edges${result.newEntries > 0 ? `, ${result.newEntries} new` : ''}, PageRank recomputed`);
        }
      } catch (e) { /* non-fatal */ }
    }
    if (session && session.end) {
      session.end();
    } else {
      console.log('[OK] Session ended');
    }
  },

  'pre-task': () => {
    if (session && session.metric) {
      try { session.metric('tasks'); } catch (e) { /* no active session */ }
    }
    // Route the task if router is available
    if (router && router.routeTask && prompt) {
      const result = router.routeTask(prompt);
      console.log(`[INFO] Task routed to: ${result.agent} (confidence: ${result.confidence})`);
    } else {
      console.log('[OK] Task started');
    }
  },

  'post-task': () => {
    // Implicit success feedback for intelligence
    if (intelligence && intelligence.feedback) {
      try {
        intelligence.feedback(true);
      } catch (e) { /* non-fatal */ }
    }
    console.log('[OK] Task completed');
  },

  'stats': () => {
    if (intelligence && intelligence.stats) {
      intelligence.stats(args.includes('--json'));
    } else {
      console.log('[WARN] Intelligence module not available. Run session-restore first.');
    }
  },
};

  // Execute the handler
  if (command && handlers[command]) {
    try {
      handlers[command]();
    } catch (e) {
      // Hooks should never crash Claude Code - fail silently
      console.log(`[WARN] Hook ${command} encountered an error: ${e.message}`);
    }
  } else if (command) {
    // Unknown command - pass through without error
    console.log(`[OK] Hook: ${command}`);
  } else {
    console.log('Usage: hook-handler.cjs <route|pre-bash|post-edit|session-restore|session-end|pre-task|post-task|stats>');
  }
}

// Ordinary errors stay non-blocking; explicit safety refusals exit 2 above.
process.exitCode = 0;
main().catch((e) => {
  try { console.log(`[WARN] Hook handler error: ${e.message}`); } catch (_) {}
}).finally(() => {
  process.exit(0);
});
