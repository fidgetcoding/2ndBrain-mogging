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
 * Claude Flow Agent Router
 * Routes tasks to optimal agents based on learned patterns
 */

const AGENT_CAPABILITIES = {
  coder: ['code-generation', 'refactoring', 'debugging', 'implementation'],
  tester: ['unit-testing', 'integration-testing', 'coverage', 'test-generation'],
  reviewer: ['code-review', 'security-audit', 'quality-check', 'best-practices'],
  researcher: ['web-search', 'documentation', 'analysis', 'summarization'],
  architect: ['system-design', 'architecture', 'patterns', 'scalability'],
  'backend-dev': ['api', 'database', 'server', 'authentication'],
  'frontend-dev': ['ui', 'react', 'css', 'components'],
  devops: ['ci-cd', 'docker', 'deployment', 'infrastructure'],
};

const TASK_PATTERNS = {
  // Code patterns
  'implement|create|build|add|write code': 'coder',
  'test|spec|coverage|unit test|integration': 'tester',
  'review|audit|check|validate|security': 'reviewer',
  'research|find|search|documentation|explore': 'researcher',
  'design|architect|structure|plan': 'architect',

  // Domain patterns
  'api|endpoint|server|backend|database': 'backend-dev',
  'ui|frontend|component|react|css|style': 'frontend-dev',
  'deploy|docker|ci|cd|pipeline|infrastructure': 'devops',
};

function routeTask(task) {
  const taskLower = task.toLowerCase();

  // Check patterns
  for (const [pattern, agent] of Object.entries(TASK_PATTERNS)) {
    const regex = new RegExp(pattern, 'i');
    if (regex.test(taskLower)) {
      return {
        agent,
        confidence: 0.8,
        reason: `Matched pattern: ${pattern}`,
      };
    }
  }

  // Default to coder for unknown tasks
  return {
    agent: 'coder',
    confidence: 0.5,
    reason: 'Default routing - no specific pattern matched',
  };
}

// CLI
const task = process.argv.slice(2).join(' ');

if (task) {
  const result = routeTask(task);
  console.log(JSON.stringify(result, null, 2));
} else {
  console.log('Usage: router.js <task description>');
  console.log('\nAvailable agents:', Object.keys(AGENT_CAPABILITIES).join(', '));
}

module.exports = { routeTask, AGENT_CAPABILITIES, TASK_PATTERNS };
