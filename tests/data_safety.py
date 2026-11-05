"""Integration regressions using only the standard library and fixture homes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile
import stat

REPO = Path(__file__).resolve().parents[1]


class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='mogging-safety-', dir='/tmp')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.vault = self.home / 'vault with spaces'
        self.vault.mkdir(parents=True)
        self.config = self.home / '.claude'
        self.config.mkdir()
        self.mocks = self.root / 'bin'
        self.mocks.mkdir()
        for name in ('claude', 'git', 'npm', 'npx', 'brew', 'launchctl', 'curl'):
            self.shim(name, 'if [ "$1" = --version ]; then echo "2.1.0"; exit 0; fi\nexit 91\n')
        self.env = dict(os.environ, HOME=str(self.home), CLAUDE_HOME=str(self.config),
                        VAULT_DIR=str(self.vault), PATH=str(self.mocks) + ':' + os.environ['PATH'])

    def shim(self, name, body):
        path = self.mocks / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    def run_cmd(self, *args, ok=None, **kw):
        result = subprocess.run([str(a) for a in args], cwd=REPO, env=self.env,
                                capture_output=True, text=True, timeout=30, **kw)
        if ok is not None:
            self.assertEqual(result.returncode, ok, result.stdout + result.stderr)
        return result

    def install(self, *flags):
        return self.run_cmd('bash', REPO / 'install.sh', '--vault', self.vault,
                            '--apply', '--no-launchd', '--no-obsidian-app',
                            '--no-obsidian-mcp', '--no-statusline-brain',
                            '--no-shell-shortcuts', '--no-skill-packs', '--skip-tests', *flags, ok=0)

    def note(self, rel, content):
        path = self.vault / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_empty_before_rejects_minted_id(self):
        before = self.root / 'empty'
        before.touch()
        after = self.root / 'after'
        after.write_text('- [ ] New task 🆔 m-12345678\n')
        result = self.run_cmd('bash', REPO / 'bin/save', 'check-tasks', '--before', before,
                              '--after', after, ok=1)
        self.assertIn('self-minted:', result.stdout)

    def test_empty_before_accepts_unidentified_task(self):
        before = self.root / 'empty'
        before.touch()
        after = self.root / 'after'
        after.write_text('- [ ] New task\n')
        self.run_cmd('bash', REPO / 'bin/save', 'check-tasks', '--before', before,
                     '--after', after, ok=0)

    def test_missing_argument_exits_promptly(self):
        for command in [('bin/save', 'check-tasks', '--before'), ('bin/wiki', 'add', '--title'),
                        ('bin/aliases', '--vault'), ('bin/memory', 'status', '--today')]:
            with self.subTest(command=command):
                try:
                    self.run_cmd('bash', REPO / command[0], *command[1:], ok=2)
                except subprocess.TimeoutExpired:
                    self.fail(f'{command} hangs on missing argument')

    def test_installer_preserves_existing_memory(self):
        self.note('Claude-Memory/aliases.yaml', 'custom aliases\n')
        self.note('Claude-Memory/important.md', 'irreplaceable\n')
        self.install()
        self.assertEqual((self.vault / 'Claude-Memory/important.md').read_text(), 'irreplaceable\n')
        self.assertEqual((self.vault / 'Claude-Memory/aliases.yaml').read_text(), 'custom aliases\n')

    def test_installer_keeps_memory_conflicts(self):
        self.note('Claude-Memory/important.md', 'vault version\n')
        memory = self.config / 'projects' / str(self.vault.resolve()).replace('/', '-') / 'memory'
        memory.mkdir(parents=True)
        (memory / 'important.md').write_text('claude version\n')
        self.install()
        self.assertEqual((self.vault / 'Claude-Memory/important.md').read_text(), 'vault version\n')
        self.assertEqual((memory / 'important.md').read_text(), 'claude version\n')

    def test_installer_preserves_foreign_skill(self):
        skill = self.config / 'skills/save'
        skill.mkdir(parents=True)
        (skill / 'SKILL.md').write_text('user skill')
        self.install()
        self.assertEqual((skill / 'SKILL.md').read_text(), 'user skill')
        self.assertFalse(skill.is_symlink())

    def test_uninstall_preserves_current_settings_and_backups(self):
        self.install('--with-guard')
        settings = self.config / 'settings.json'
        current = json.loads(settings.read_text())
        current['userSettingAddedLater'] = 'preserve'
        current['hooks']['PreToolUse'][0]['hooks'].append({'type': 'command', 'command': 'echo user-hook'})
        settings.write_text(json.dumps(current))
        backup = self.config / '.backups/2099-01-01/settings.json'
        backup.parent.mkdir(parents=True)
        backup.write_text('{"stale": true}')
        self.run_cmd('bash', REPO / 'uninstall.sh', '--vault', self.vault, ok=0)
        after = json.loads(settings.read_text())
        self.assertEqual(after.get('userSettingAddedLater'), 'preserve')
        self.assertIn('echo user-hook', settings.read_text())
        self.assertNotIn('hooks/vault-guard.sh', settings.read_text())
        self.assertNotIn('hooks/stop-save.sh', settings.read_text())
        self.assertTrue(backup.exists())

    def test_uninstall_preserves_foreign_packs_and_launchers(self):
        skill = self.config / 'skills/obsidian-markdown'
        skill.mkdir(parents=True)
        (skill / 'SKILL.md').write_text('independent install')
        launcher = self.home / '.local/bin/cbrain'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('#!/bin/sh\necho custom\n')
        self.run_cmd('bash', REPO / 'uninstall.sh', ok=0)
        self.assertTrue((skill / 'SKILL.md').exists())
        self.assertTrue(launcher.exists())

    def test_backup_keeps_multiple_versions(self):
        self.note('02-Library/sources/a.md', 'first')
        self.shim('date', 'echo 2026-11-04\n')
        script = '. bin/lib/vault-gate.sh; gate_backup "$VAULT_DIR" 02-Library/sources/a.md'
        self.run_cmd('bash', '-c', script, ok=0)
        self.note('02-Library/sources/a.md', 'second')
        self.run_cmd('bash', '-c', script, ok=0)
        contents = sorted(p.read_text() for p in (self.vault / 'Claude-Memory/backups').rglob('*') if p.is_file())
        self.assertEqual(contents, ['first', 'second'])

    def test_wiki_serializes_source_metadata(self):
        self.run_cmd('bash', REPO / 'bin/wiki', 'add', '--title', 'test', '--body', 'body',
                     '--source-of-truth', 'a"\nowner: human\n#', '--target', '02-Library/sources/test.md', '--yes', ok=0)
        content = (self.vault / '02-Library/sources/test.md').read_text()
        self.assertNotIn('\nowner: human\n', content)
        self.assertIn('owner: wiki', content)

    def test_wiki_write_failure_is_nonzero(self):
        self.note('02-Library/sources', 'not a directory')
        result = self.run_cmd('bash', REPO / 'bin/wiki', 'add', '--title', 'test',
                              '--body', 'body', '--target', '02-Library/sources/test.md', '--yes')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Wrote ', result.stdout)

    def test_memory_skips_forbidden_subtrees(self):
        self.note('Claude-Memory/memory-tier.yaml', 'stale_days: 60\n')
        body = '---\ntype: concept\nowner: wiki\nasof: 2020-01-01\n---\nbody\n'
        path = self.note('02-Library/ideas/node_modules/package/note.md', body)
        self.run_cmd('bash', REPO / 'bin/memory', 'decay', '--today', '2026-11-04', '--apply', ok=0)
        self.assertEqual(path.read_text(), body)

    def test_memory_confirm_preserves_body_bytes_and_clears_review(self):
        self.note('Claude-Memory/memory-tier.yaml', 'stale_days: 60\n')
        path = self.note('02-Library/ideas/note.md', '---\ntype: concept\nowner: wiki\nneeds_review: true\nmemory_state: stale\n---\nbody without final newline')
        self.run_cmd('bash', REPO / 'bin/memory', 'confirm', '02-Library/ideas/note.md', '--apply', ok=0)
        content = path.read_bytes()
        self.assertTrue(content.endswith(b'---\nbody without final newline'))
        self.assertNotIn(b'needs_review: true', content)

    def test_memory_rejects_impossible_dates(self):
        self.note('Claude-Memory/memory-tier.yaml', 'stale_days: 60\n')
        self.run_cmd('bash', REPO / 'bin/memory', 'status', '--today', '2026-02-31', ok=2)


    def test_archives_reject_traversal_and_symlinks(self):
        for name in ('../escape', '/absolute', 'C:/drive', 'link'):
            archive = self.root / 'bad.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                entry = zipfile.ZipInfo(name)
                if name == 'link':
                    entry.create_system = 3
                    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                z.writestr(entry, '../outside')
            self.run_cmd('python3', REPO / 'scripts/stage-export.py', archive, self.vault, ok=1)
        self.assertFalse((self.vault / '.import-staging').exists())

    def test_archive_staging_is_unique(self):
        archive = self.root / 'data.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('folder/conversations.json', '{"text":"hello"}')
        first = self.run_cmd('python3', REPO / 'scripts/stage-export.py', archive, self.vault, ok=0).stdout.strip()
        second = self.run_cmd('python3', REPO / 'scripts/stage-export.py', archive, self.vault, ok=0).stdout.strip()
        self.assertNotEqual(first, second)
        self.assertEqual((Path(first) / 'folder/conversations.json').read_text(), '{"text":"hello"}')

    def test_archive_refuses_staging_symlink(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.vault / '.import-staging').symlink_to(outside)
        archive = self.root / 'data.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('data.json', '{}')
        self.run_cmd('python3', REPO / 'scripts/stage-export.py', archive, self.vault, ok=1)
        self.assertEqual(list(outside.iterdir()), [])

    def test_backup_archive_failure_leaves_no_finished_archive(self):
        self.shim('tar', 'exit 1\n')
        self.run_cmd('bash', REPO / 'bin/backup-vault.sh', self.vault, ok=1)
        self.assertEqual(list((self.home / 'WORK').rglob('*.tar.gz')), [])

    def test_backup_archive_roundtrip_and_unique_names(self):
        self.note('note.md', 'precious bytes')
        self.shim('date', 'echo fixed\n')
        one = self.run_cmd('bash', REPO / 'bin/backup-vault.sh', self.vault, ok=0).stdout.strip()
        two = self.run_cmd('bash', REPO / 'bin/backup-vault.sh', self.vault, ok=0).stdout.strip()
        self.assertNotEqual(one, two)
        import tarfile
        with tarfile.open(one) as archive:
            self.assertEqual(archive.extractfile(self.vault.name + '/note.md').read(), b'precious bytes')

    def test_memory_promotion_ignores_backup_and_dependency_links(self):
        self.note('Claude-Memory/memory-tier.yaml', 'promote_inbound: 3\n')
        note = self.note('02-Library/ideas/target.md', '---\ntype: concept\nowner: wiki\nasof: 2020-01-01\nseenat: 2026-11-01\n---\nbody')
        for rel in ('01-Projects/a/node_modules/dep/a.md', 'Claude-Memory/backups/b.md', 'nested/.git/c.md'):
            self.note(rel, '[[target]]')
        self.run_cmd('bash', REPO / 'bin/memory', 'promote', '--today', '2026-11-04', '--apply', ok=0)
        self.assertNotIn('durability: durable', note.read_text())

    def test_hook_reads_actual_tool_input(self):
        result = self.run_cmd('node', REPO / 'helpers/hook-handler.cjs', 'pre-bash',
                              input=json.dumps({'tool_input': {'command': 'rm -rf /'}}))
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.run_cmd('node', REPO / 'helpers/hook-handler.cjs', 'pre-bash',
                     input=json.dumps({'tool_input': {'command': 'echo safe'}}), ok=0)

    def test_helper_import_has_no_cli_side_effects(self):
        script = 'process.argv = ["node", "test", "clear"]; require(process.argv[3]);'
        # Use a fixture working directory; module paths remain absolute.
        memory = self.vault / '.claude-flow/data/memory.json'
        memory.parent.mkdir(parents=True)
        memory.write_text('{"important":"keep"}')
        script = 'process.argv = ["node", "test", "clear"]; require(' + json.dumps(str(REPO / 'helpers/memory.js')) + ');'
        result = subprocess.run(['node', '-e', script], cwd=self.vault, env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(memory.read_text(), '{"important":"keep"}')
        self.assertEqual(result.stdout, '')

    def test_update_download_failure_is_not_success(self):
        result = self.run_cmd('bash', REPO / 'update.sh', '--vault', self.vault)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Update complete', result.stdout)

    def test_installer_dry_run_with_intelligence_has_no_writes(self):
        self.run_cmd('bash', REPO / 'install.sh', '--vault', self.vault,
                     '--with-intelligence', '--no-launchd', '--no-obsidian-app',
                     '--no-obsidian-mcp', '--no-skill-packs', ok=0)
        self.assertEqual(list(self.vault.iterdir()), [])
        self.assertEqual(list(self.config.iterdir()), [])



    def test_alias_proposals_keep_previous_review(self):
        self.note('Claude-Memory/aliases.yaml', 'version: 1\n')
        pending = self.note('Claude-Memory/aliases-pending.md', 'Human pending proposal\n')
        self.run_cmd('bash', REPO / 'bin/aliases', '--bootstrap', ok=0)
        self.assertIn('Human pending proposal', pending.read_text())
        self.assertTrue(any((self.vault / 'Claude-Memory/backups').rglob('*.bak')))

    def test_installer_preserves_unbalanced_contract(self):
        original = '# My rules\n<!-- 2ndbrain-mogging:start -->\nDo not delete these notes.\n'
        path = self.note('CLAUDE.md', original)
        result = self.run_cmd('bash', REPO / 'install.sh', '--vault', self.vault, '--apply',
                              '--no-launchd', '--no-obsidian-app', '--no-obsidian-mcp',
                              '--no-skill-packs', '--no-shell-shortcuts', '--skip-tests')
        self.assertEqual(result.returncode, 41, result.stderr)
        self.assertEqual(path.read_text(), original)

    def test_invalid_settings_fail_before_vault_changes(self):
        (self.config / 'settings.json').write_text('{broken')
        result = self.run_cmd('bash', REPO / 'install.sh', '--vault', self.vault,
                              '--apply', '--no-obsidian-app')
        self.assertEqual(result.returncode, 40)
        self.assertEqual(list(self.vault.iterdir()), [])

    def assert_invalid_settings_refused(self, operation):
        cases = {
            'empty': b'',
            'whitespace': b' \n\t',
            'two-objects': b'{"first": true}\n{"second": true}\n',
            'scalar-then-object': b'42\n{}\n',
            'object-then-scalar': b'{}\nfalse\n',
            'scalar': b'42',
            'array-root': b'[]',
            'null-root': b'null',
            'malformed-json': b'{broken',
            'hooks-array': b'{"hooks": []}',
            'hooks-null': b'{"hooks": null}',
            'event-object': b'{"hooks": {"Stop": {}}}',
            'event-null': b'{"hooks": {"Stop": null}}',
            'group-scalar': b'{"hooks": {"Stop": [false]}}',
            'group-missing-hooks': b'{"hooks": {"Stop": [{}]}}',
            'group-hooks-object': b'{"hooks": {"Stop": [{"hooks": {}}]}}',
            'group-hooks-null': b'{"hooks": {"Stop": [{"hooks": null}]}}',
            'hook-scalar': b'{"hooks": {"Stop": [{"hooks": ["echo user"]}]}}',
            'matcher-number': b'{"hooks": {"Stop": [{"matcher": 1, "hooks": []}]}}',
            'command-number': b'{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": 1}]}]}}',
            'command-missing': b'{"hooks": {"Stop": [{"hooks": [{"type": "command"}]}]}}',
            'type-missing': b'{"hooks": {"Stop": [{"hooks": [{"command": "echo user"}]}]}}',
        }

        def snapshot(home):
            result = {}
            for path in sorted(home.rglob('*')):
                mode = stat.S_IMODE(path.lstat().st_mode)
                value = ('link', os.readlink(path)) if path.is_symlink() else (
                    ('dir',) if path.is_dir() else ('file', path.read_bytes()))
                result[str(path.relative_to(home))] = (mode, value)
            return result

        for name, content in cases.items():
            with self.subTest(operation=operation, settings=name), tempfile.TemporaryDirectory(
                    prefix='settings-case-', dir=self.root) as td:
                home = Path(td) / 'home'
                config = home / '.claude'
                vault = home / 'vault'
                config.mkdir(parents=True)
                vault.mkdir()
                settings = config / 'settings.json'
                settings.write_bytes(content)
                settings.chmod(0o640)
                # Real uninstall targets inside this fixture detect later side effects.
                (config / '.mogging-guard').write_text(str(vault))
                (config / '.mogging-vault').write_text(str(vault))
                (config / 'skills').mkdir()
                (config / 'skills/save').symlink_to(REPO / 'skills/save')
                (vault / 'keep.md').write_text('keep original bytes\n')
                before = snapshot(home)
                env = dict(self.env, HOME=str(home), CLAUDE_HOME=str(config), VAULT_DIR=str(vault))
                args = ['bash', str(REPO / (operation + '.sh')), '--vault', str(vault)]
                if operation == 'install':
                    args += ['--apply', '--no-launchd', '--no-obsidian-app', '--no-obsidian-mcp',
                             '--no-statusline-brain', '--no-shell-shortcuts', '--no-skill-packs',
                             '--skip-tests', '--with-guard', '--with-intelligence']
                result = subprocess.run(args, cwd=REPO, env=env, capture_output=True,
                                        text=True, timeout=30)
                # One assertion checks all guarantees even when reproducing multiple failures.
                self.assertEqual((result.returncode, settings.read_bytes() == content,
                                  snapshot(home) == before),
                                 (40 if operation == 'install' else 1, True, True),
                                 f'{operation} must refuse invalid settings without side effects')

    def test_install_rejects_invalid_settings_without_side_effects(self):
        self.assert_invalid_settings_refused('install')

    def test_uninstall_rejects_invalid_settings_without_side_effects(self):
        self.assert_invalid_settings_refused('uninstall')

    def test_valid_mixed_settings_survive_install_and_uninstall(self):
        user_hooks = [
            {'type': 'command', 'command': 'echo user-hook', 'timeout': 7},
            {'type': 'prompt', 'prompt': 'Check the work', 'timeout': 30},
            {'type': 'agent', 'prompt': 'Review changes', 'model': 'custom'},
        ]
        original = {
            'permissions': {'allow': ['Read'], 'deny': ['Bash(rm *)']},
            'custom': {'nested': [1, False, None]},
            'hooks': {
                'Stop': [{'hooks': user_hooks}],
                'PreToolUse': [{'matcher': 'Read', 'hooks': user_hooks}],
                'SessionStart': [{'matcher': '', 'hooks': user_hooks}],
                'CustomEvent': [{'hooks': []}],
            },
        }
        settings = self.config / 'settings.json'
        settings.write_text(json.dumps(original))
        self.install('--with-guard', '--with-intelligence')
        installed = json.loads(settings.read_text())
        for key in ('permissions', 'custom'):
            self.assertEqual(installed[key], original[key])
        for event in original['hooks']:
            self.assertEqual(installed['hooks'][event][0], original['hooks'][event][0])
        self.run_cmd('bash', REPO / 'uninstall.sh', '--vault', self.vault, ok=0)
        after = json.loads(settings.read_text())
        for key in ('permissions', 'custom'):
            self.assertEqual(after[key], original[key])
        for event in original['hooks']:
            self.assertEqual(after['hooks'][event], original['hooks'][event])
        for event in set(after['hooks']) - set(original['hooks']):
            self.assertEqual(after['hooks'][event], [])

    def test_scheduler_templates_render_escaped_paths(self):
        import plistlib
        self.vault = self.home / 'vault & "quoted" $(echo unsafe)'
        self.vault.mkdir()
        self.env['VAULT_DIR'] = str(self.vault)
        self.shim('launchctl', 'exit 0\n')
        self.run_cmd('bash', REPO / 'install.sh', '--vault', self.vault, '--apply',
                     '--no-obsidian-app', '--no-obsidian-mcp', '--no-skill-packs',
                     '--no-shell-shortcuts', '--skip-tests', ok=0)
        for path in (self.home / 'Library/LaunchAgents').glob('*.plist'):
            data = plistlib.loads(path.read_bytes())
            self.assertEqual(data['Label'], path.stem)
            self.assertEqual(data['EnvironmentVariables']['VAULT_ROOT'], str(self.vault.resolve()))
            self.assertIn('${VAULT_ROOT}', data['ProgramArguments'][2])
            self.assertIn('${REPO_ROOT}/agents/', data['ProgramArguments'][2])
        plugin = json.loads((REPO / '.claude-plugin/plugin.json').read_text())
        for agent in plugin['scheduled']:
            self.assertTrue((REPO / agent['plist']).is_file())

    def test_installed_hooks_work_from_special_checkout_path(self):
        checkout = self.root / 'repo space & "quoted"'
        shutil.copytree(REPO, checkout, ignore=shutil.ignore_patterns('.git', '__pycache__'))
        self.shim('launchctl', 'exit 0\n')
        self.run_cmd('bash', checkout / 'install.sh', '--vault', self.vault, '--apply',
                     '--with-guard', '--no-obsidian-app', '--no-obsidian-mcp',
                     '--no-skill-packs', '--no-shell-shortcuts', '--skip-tests', ok=0)
        settings = json.loads((self.config / 'settings.json').read_text())
        stop = settings['hooks']['Stop'][0]['hooks'][0]['command']
        self.run_cmd('bash', '-c', stop, ok=0)
        guard = settings['hooks']['PreToolUse'][0]['hooks'][0]['command']
        target = self.note('04-Tasks/fixture.md', '- [ ] Existing 🆔 m-12345678\n')
        self.run_cmd('bash', '-c', guard, input=json.dumps({'tool_name': 'Write',
                     'tool_input': {'file_path': str(target), 'content': '- [ ] Existing\n'}}), ok=2)
        self.run_cmd('bash', checkout / 'uninstall.sh', '--vault', self.vault, ok=0)
        self.assertEqual(list((self.home / 'Library/LaunchAgents').glob('*.plist')), [])

    def test_update_installs_from_persistent_complete_checkout(self):
        self.shim('git', '''if [ "$1" = clone ]; then
  for arg; do dest="$arg"; done
  mkdir -p "$dest/skills" "$dest/.git"
  cat > "$dest/install.sh" <<'SH'
#!/bin/bash
test -d "$(dirname "$0")/skills" || exit 1
printf ok > "$(dirname "$0")/installed"
SH
  exit 0
fi
exit 92
''')
        self.run_cmd('bash', REPO / 'update.sh', '--vault', self.vault, ok=0)
        self.assertTrue((self.config / '2ndbrain-mogging/installed').exists())
        self.assertTrue((self.config / '2ndbrain-mogging/install.sh').exists())



    def test_intelligence_uninstall_preserves_unrelated_hooks(self):
        self.install('--with-intelligence')
        settings = self.config / 'settings.json'
        data = json.loads(settings.read_text())
        data['hooks']['SessionStart'][0]['hooks'].append({'type':'command', 'command':'echo custom-start'})
        settings.write_text(json.dumps(data))
        self.run_cmd('bash', REPO / 'uninstall.sh', '--vault', self.vault, ok=0)
        after = settings.read_text()
        self.assertIn('echo custom-start', after)
        self.assertNotIn('hook-handler.cjs', after)
        self.assertNotIn('auto-memory-hook.mjs', after)



    def test_corrupt_helper_memory_is_not_overwritten(self):
        memory = self.vault / '.claude-flow/data/memory.json'
        memory.parent.mkdir(parents=True)
        memory.write_text('{ damaged state')
        result = subprocess.run(['node', str(REPO / 'helpers/memory.js'), 'set', 'key', 'value'],
                                cwd=self.vault, env=self.env, capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(memory.read_text(), '{ damaged state')

    def test_json_publish_failure_keeps_previous_state(self):
        target = self.root / 'state.json'
        target.write_text('{"old":true}')
        script = ('const fs=require("fs"); const io=require(' + json.dumps(str(REPO / 'helpers/atomic-json.cjs')) + ');'
                  'fs.renameSync=()=>{throw new Error("fixture failure")};'
                  'try {io.writeJSON(' + json.dumps(str(target)) + ', {new:true}); process.exit(1)} catch {}')
        self.run_cmd('node', '-e', script, ok=0)
        self.assertEqual(target.read_text(), '{"old":true}')
        self.assertEqual(list(self.root.glob('state.json.*.tmp')), [])



    def test_task_edit_refuses_changes_after_preview(self):
        import select
        import time
        target = self.note('04-Tasks/fixture.md', '- [ ] Original 🆔 m-12345678\n')
        proposal = self.root / 'proposal.md'
        proposal.write_text('- [ ] Proposed 🆔 m-12345678\n')
        process = subprocess.Popen(['bash', str(REPO / 'bin/save'), 'write-tasks',
                                    '--target', str(target), '--from', str(proposal)],
                                   cwd=REPO, env=self.env, stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            output = b''
            deadline = time.monotonic() + 10
            while b'Proceed? (y/n)' not in output:
                self.assertLess(time.monotonic(), deadline, 'preview prompt timed out')
                if select.select([process.stdout], [], [], 1)[0]:
                    chunk = os.read(process.stdout.fileno(), 4096)
                    self.assertTrue(chunk, output)
                    output += chunk
            target.write_text('- [ ] Concurrent change 🆔 m-12345678\n')
            process.communicate(b'y\n', timeout=10)
            self.assertEqual(process.returncode, 1)
            self.assertIn('Concurrent change', target.read_text())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()



    def test_auto_memory_uses_vault_root_from_symlink_install(self):
        source = self.root / 'checkout/helpers'
        shutil.copytree(REPO / 'helpers', source)
        installed = self.vault / '.claude/helpers'
        installed.parent.mkdir(parents=True)
        installed.symlink_to(source)
        env = dict(self.env, CLAUDE_PROJECT_DIR=str(self.vault))
        result = subprocess.run(['node', str(installed / 'auto-memory-hook.mjs'), 'status'],
                                cwd=self.vault, env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('Error (non-critical)', result.stdout)
        self.assertTrue((self.vault / '.claude-flow/data').is_dir())
        self.assertFalse((self.root / '.claude-flow').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
