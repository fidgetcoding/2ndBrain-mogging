"""Process-level regressions. Only disposable project/HOME and local fake bridges."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

REPO = Path(os.environ.get('HELPER_TEST_REPO', Path(__file__).resolve().parents[1]))


class HelperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='mogging-helper-', dir='/tmp')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.project = self.root / 'project'
        self.data = self.project / '.claude-flow/data'
        self.data.mkdir(parents=True)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), CLAUDE_HOME=str(self.home / '.claude'),
                        CLAUDE_PROJECT_DIR=str(self.project))
        self.env.pop('NODE_OPTIONS', None)
        self.children = []
        self.addCleanup(self.cleanup_children)

    def cleanup_children(self):
        for child in self.children:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=5)

    def write(self, name, data):
        p = self.data / name
        p.write_text(json.dumps(data))
        return p

    def read(self, name):
        return json.loads((self.data / name).read_text())

    def session(self):
        p = self.project / '.claude-flow/sessions/current.json'
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps({'id': 'fixture', 'startedAt': '2026-01-01', 'context': {
            'lastMatchedPatterns': ['base']}, 'metrics': {'edits': 0}}))
        return p

    def seed(self):
        self.write('auto-memory-store.json', [{'id': 'base', 'content': 'base pattern',
                                              'metadata': {}, 'createdAt': int(time.time()*1000)}])
        self.write('ranked-context.json', {'entries': [{'id': 'base', 'confidence': .5,
                    'accessCount': 0, 'words': ['pattern'], 'pageRank': 1}]})
        self.write('graph-state.json', {'nodes': {'base': {'id': 'base', 'confidence': .5,
                    'accessCount': 0, 'createdAt': int(time.time()*1000)}}, 'edges': []})
        self.session()

    def edits(self, file, count=3):
        return ''.join(json.dumps({'type': 'edit', 'file': file, 'timestamp': 1}) + '\n'
                       for _ in range(count))

    def call(self, module, method, *args):
        return 'require(' + json.dumps(str(REPO / 'helpers' / module)) + ').' + method + '(' + ','.join(map(json.dumps, args)) + ');'

    def start(self, code):
        p = subprocess.Popen(['node', '-e', code], cwd=self.project, env=self.env,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.children.append(p)
        return p

    def finish(self, child, ok=0):
        out, err = child.communicate(timeout=15)
        if ok is not None:
            self.assertEqual(child.returncode, ok, out + err)
        return child.returncode

    def run_js(self, code, ok=0):
        return self.finish(self.start(code), ok)

    def wait_file(self, path):
        end = time.monotonic() + 8
        while not path.exists() and time.monotonic() < end:
            time.sleep(.01)
        self.assertTrue(path.exists(), f'child did not reach barrier {path.name}')

    def compete(self, target, first, second):
        ready, release, started, observed = [self.root / n for n in ('ready', 'release', 'started', 'observed')]
        prefix = 'const fs=require("fs"); const read=fs.readFileSync;'
        pause = prefix + '''let paused=false; fs.readFileSync=function(p,...args){
          const data=read.call(fs,p,...args);
          if(!paused && String(p)===TARGET){paused=true;fs.writeFileSync(READY,'');
            const until=Date.now()+10000; while(!fs.existsSync(RELEASE)){
              if(Date.now()>until)throw Error('barrier timeout');
              Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10);
            }} return data;};'''
        for key, val in [('TARGET', target), ('READY', ready), ('RELEASE', release)]:
            pause = pause.replace(key, json.dumps(str(val)))
        a = self.start(pause + first)
        self.wait_file(ready)
        probe = prefix + 'fs.writeFileSync(' + json.dumps(str(started)) + ',"");'
        probe += 'fs.readFileSync=function(p,...args){const d=read.call(fs,p,...args);if(String(p)===' + json.dumps(str(target)) + ')fs.writeFileSync(' + json.dumps(str(observed)) + ',"");return d;};'
        b = self.start(probe + second)
        self.wait_file(started)
        # Old code reaches the competing read; coordinated code blocks before it.
        end = time.monotonic() + .4
        while not observed.exists() and time.monotonic() < end:
            time.sleep(.01)
        if observed.exists():
            self.finish(b)
        release.touch()
        self.finish(a)
        self.finish(b)

    def test_competing_memory_sets(self):
        p = self.write('memory.json', {})
        self.compete(p, self.call('memory.js', 'set', 'a', 'A'), self.call('memory.js', 'set', 'b', 'B'))
        self.assertEqual({k:v for k,v in self.read('memory.json').items() if k != '_updated'}, {'a':'A','b':'B'})

    def test_memory_delete_preserves_concurrent_set(self):
        p = self.write('memory.json', {'old': 'remove'})
        self.compete(p, self.call('memory.js', 'delete', 'old'), self.call('memory.js', 'set', 'b', 'B'))
        self.assertNotIn('old', self.read('memory.json'))
        self.assertEqual(self.read('memory.json').get('b'), 'B')

    def test_session_updates_share_lock_with_intelligence(self):
        self.seed()
        p = self.project / '.claude-flow/sessions/current.json'
        initial = json.loads(p.read_text())
        initial['context']['lastMatchedPatterns'] = ['previous']
        p.write_text(json.dumps(initial))
        self.compete(p, self.call('session.js', 'update', 'user', 'keep'),
                     self.call('intelligence.cjs', 'getContext', 'pattern'))
        data = json.loads(p.read_text())
        self.assertEqual(data['context'].get('user'), 'keep')
        self.assertIn('updatedAt', data)
        # Intelligence and the session helper must both retain each other's keys.
        self.assertEqual(data['context']['lastMatchedPatterns'], ['base'])

    def test_competing_session_metrics(self):
        p = self.session()
        self.compete(p, self.call('session.js', 'metric', 'edits'), self.call('session.js', 'metric', 'edits'))
        self.assertEqual(json.loads(p.read_text())['metrics']['edits'], 2)

    def test_competing_feedback(self):
        self.seed()
        self.compete(self.data / 'ranked-context.json', self.call('intelligence.cjs', 'feedback', True),
                     self.call('intelligence.cjs', 'feedback', True))
        self.assertEqual(self.read('ranked-context.json')['entries'][0]['accessCount'], 2)
        self.assertEqual(self.read('graph-state.json')['nodes']['base']['accessCount'], 2)

    def test_append_during_consolidation_survives_next_run(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        pending.write_text(self.edits('first'))
        inject = '''const fs=require('fs');const read=fs.readFileSync;let fired=false;
          fs.readFileSync=function(p,...args){const data=read.call(fs,p,...args);
          if(!fired && String(p).endsWith('/pending-insights.jsonl')){
            fired=true;fs.appendFileSync(p,APPEND);}return data;};'''.replace('APPEND', json.dumps(self.edits('later')))
        self.run_js(inject + self.call('intelligence.cjs', 'consolidate'))
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        files = [e.get('metadata', {}).get('sourceFile') for e in self.read('auto-memory-store.json')]
        self.assertIn('first', files)
        self.assertIn('later', files)
        self.assertEqual(len(files), len(set(files)))

    def test_publication_failure_preserves_pending_for_retry(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        original = self.edits('first')
        pending.write_text(original)
        fail = '''const fs=require('fs');const rename=fs.renameSync;
          fs.renameSync=function(a,b){if(String(b).endsWith('/auto-memory-store.json'))throw Error('fixture failure');return rename.call(fs,a,b);};'''
        self.assertNotEqual(self.run_js(fail + self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
        self.assertEqual(pending.read_text(), original)
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        entries = [e for e in self.read('auto-memory-store.json') if e.get('metadata', {}).get('sourceFile') == 'first']
        self.assertEqual(len(entries), 1)

    def test_parse_failure_preserves_pending(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        original = self.edits('first')
        pending.write_text(original)
        (self.data / 'graph-state.json').write_text('{malformed')
        self.assertNotEqual(self.run_js(self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
        self.assertEqual(pending.read_text(), original)
        self.assertEqual((self.data / 'graph-state.json').read_bytes(), b'{malformed')

    def test_two_consolidators_keep_store_and_graph_consistent(self):
        self.seed()
        (self.data / 'pending-insights.jsonl').write_text(self.edits('first'))
        self.compete(self.data / 'auto-memory-store.json', self.call('intelligence.cjs', 'consolidate'),
                     self.call('intelligence.cjs', 'consolidate'))
        entries = self.read('auto-memory-store.json')
        self.assertEqual(len(entries), 2)
        self.assertEqual(set(self.read('graph-state.json')['nodes']), {e['id'] for e in entries})
        self.assertEqual({e['id'] for e in self.read('ranked-context.json')['entries']}, {e['id'] for e in entries})

    def test_bridge_does_not_overwrite_newer_store_on_shutdown(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        pending.write_text(self.edits('first'))
        ready, release = self.root / 'ready', self.root / 'release'
        pkg = self.project / 'v3/@claude-flow/memory/dist/index.js'
        pkg.parent.mkdir(parents=True)
        pkg.write_text('''const fs=require('fs');exports.AutoMemoryBridge=class {
          constructor(backend){this.backend=backend;}
          async importFromAutoMemory(){fs.writeFileSync(READY,'');
            while(!fs.existsSync(RELEASE))await new Promise(r=>setTimeout(r,10));
            await this.backend.store({id:'bridge',content:'bridge entry',metadata:{}});
            return {imported:1,skipped:0};}};'''.replace('READY', json.dumps(str(ready))).replace('RELEASE', json.dumps(str(release))))
        bridge = subprocess.Popen(['node', str(REPO / 'helpers/auto-memory-hook.mjs'), 'import'],
                    cwd=self.project, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.children.append(bridge)
        self.wait_file(ready)
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        release.touch()
        self.finish(bridge)
        entries = self.read('auto-memory-store.json')
        self.assertIn('bridge', [e['id'] for e in entries])
        self.assertEqual(len([e for e in entries if e.get('metadata', {}).get('sourceFile') == 'first']), 1)

    def test_session_end_does_not_resurrect_stale_session(self):
        p = self.session()
        self.compete(p, self.call('session.js', 'metric', 'edits'), self.call('session.js', 'end'))
        self.assertFalse(p.exists())
        archived = json.loads((p.parent / 'fixture.json').read_text())
        self.assertEqual(archived['metrics']['edits'], 1)

    def test_interrupted_publication_rolls_forward_once(self):
        for stage in ('.intelligence-transaction.json', 'auto-memory-store.json',
                      'ranked-context.json', 'pending-insights-checkpoint.json'):
            with self.subTest(stage=stage):
                self.seed()
                pending = self.data / 'pending-insights.jsonl'
                original = self.edits(stage)
                checkpoint = self.data / 'pending-insights-checkpoint.json'
                if checkpoint.exists(): checkpoint.unlink()
                pending.write_text(original)
                crash = '''const fs=require('fs');const rename=fs.renameSync;
                  fs.renameSync=function(a,b){const r=rename.call(fs,a,b);
                    if(require('path').basename(String(b))===STAGE)process.kill(process.pid,'SIGKILL');return r;};'''.replace('STAGE', json.dumps(stage))
                self.assertNotEqual(self.run_js(crash + self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
                self.assertEqual(pending.read_text(), original)
                plan = self.read('.intelligence-transaction.json')
                planned = next(x['data'] for x in plan['files'] if x['name'] == 'auto-memory-store.json')
                self.run_js(self.call('intelligence.cjs', 'consolidate'))
                self.assertEqual(self.read('auto-memory-store.json'), planned)
                self.assertFalse((self.data / '.intelligence-transaction.json').exists())
                self.assertFalse(os.path.lexists(self.data / '.helper-state.lock'))
                self.run_js(self.call('intelligence.cjs', 'consolidate'))
                self.assertEqual(self.read('auto-memory-store.json'), planned)

    def test_each_output_failure_retains_replayable_commit(self):
        for stage in ('graph-state.json', 'ranked-context.json', 'intelligence-snapshot.json',
                      'pending-insights-checkpoint.json'):
            with self.subTest(stage=stage):
                self.seed()
                pending = self.data / 'pending-insights.jsonl'
                original = self.edits(stage)
                checkpoint = self.data / 'pending-insights-checkpoint.json'
                if checkpoint.exists(): checkpoint.unlink()
                pending.write_text(original)
                fail = '''const fs=require('fs');const rename=fs.renameSync;
                  fs.renameSync=function(a,b){if(require('path').basename(String(b))===STAGE)throw Error('fixture failure');return rename.call(fs,a,b);};'''.replace('STAGE', json.dumps(stage))
                self.assertNotEqual(self.run_js(fail + self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
                self.assertEqual(pending.read_text(), original)
                self.assertFalse(os.path.lexists(self.data / '.helper-state.lock'))
                with pending.open('a') as stream: stream.write(self.edits('arrival-' + stage))
                self.run_js(self.call('intelligence.cjs', 'consolidate'))
                self.assertEqual(self.read('pending-insights-checkpoint.json')['offset'], len(original.encode()))
                self.run_js(self.call('intelligence.cjs', 'consolidate'))
                files = [e.get('metadata', {}).get('sourceFile') for e in self.read('auto-memory-store.json')]
                self.assertEqual(files.count(stage), 1)
                self.assertEqual(files.count('arrival-' + stage), 1)

    def test_malformed_and_incomplete_pending_bytes_are_retained(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        original = self.edits('frequent').encode() + b'not-json\xff\n' + b'{"file":"partial"'
        pending.write_bytes(original)
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        self.assertEqual(pending.read_bytes(), original)
        self.assertEqual(self.read('pending-insights-checkpoint.json')['offset'], original.rfind(b'\n') + 1)
        self.assertEqual(len(self.read('auto-memory-store.json')), 2)
        self.assertNotEqual(self.run_js(self.call('intelligence.cjs', 'recordEdit', 'new'), ok=None), 0)
        self.assertEqual(pending.read_bytes(), original)
        with pending.open('ab') as stream:
            stream.write(b'}\n' + self.edits('partial', 2).encode())
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        entries = self.read('auto-memory-store.json')
        self.assertEqual(len([e for e in entries if e.get('metadata', {}).get('sourceFile') == 'partial']), 1)

    def test_thresholds_and_acknowledged_records_are_unchanged(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        pending.write_text(self.edits('below', 2) + self.edits('threshold', 3))
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        entries = self.read('auto-memory-store.json')
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[-1]['metadata']['editCount'], 3)
        with pending.open('a') as stream: stream.write(self.edits('below', 1))
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        self.assertEqual(self.read('auto-memory-store.json'), entries)

    def test_checkpoint_detects_external_log_replacement(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        pending.write_text(self.edits('first'))
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        before = (self.data / 'auto-memory-store.json').read_bytes()
        pending.write_text(self.edits('other'))
        self.assertNotEqual(self.run_js(self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
        self.assertEqual((self.data / 'auto-memory-store.json').read_bytes(), before)
        self.assertEqual(pending.read_text(), self.edits('other'))

    def test_malformed_transaction_blocks_later_writers(self):
        for raw in (b'{bad', b'null', b'{"version":1,"files":[]}'):
            with self.subTest(raw=raw):
                self.write('memory.json', {'keep': True})
                (self.data / '.intelligence-transaction.json').write_bytes(raw)
                self.assertNotEqual(self.run_js(self.call('memory.js', 'set', 'new', 'bad'), ok=None), 0)
                self.assertEqual(self.read('memory.json'), {'keep': True})
                self.assertEqual((self.data / '.intelligence-transaction.json').read_bytes(), raw)
                self.assertFalse(os.path.lexists(self.data / '.helper-state.lock'))

    def test_lock_timeout_cleanup_and_dead_owner_recovery(self):
        lock_module = json.dumps(str(REPO / 'helpers/state-lock.cjs'))
        directory = json.dumps(str(self.data))
        ready, release = self.root / 'ready', self.root / 'release'
        holder = self.start('const fs=require("fs");require(' + lock_module + ').withStateLock(' + directory + ',()=>{fs.writeFileSync(' + json.dumps(str(ready)) + ',"");while(!fs.existsSync(' + json.dumps(str(release)) + '))Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10);});')
        self.wait_file(ready)
        self.assertNotEqual(self.run_js('require(' + lock_module + ').withStateLock(' + directory + ',()=>{}, {timeoutMs:60});', ok=None), 0)
        self.assertIsNone(holder.poll())
        holder.kill()
        self.finish(holder, ok=None)
        self.run_js(self.call('memory.js', 'set', 'recovered', 'yes'))
        self.assertEqual(self.read('memory.json')['recovered'], 'yes')
        self.assertFalse(os.path.lexists(self.data / '.helper-state.lock'))
        self.assertNotEqual(self.run_js('require(' + lock_module + ').withStateLock(' + directory + ',()=>{throw Error("fixture")});', ok=None), 0)
        self.assertFalse(os.path.lexists(self.data / '.helper-state.lock'))

    def test_two_writers_recover_one_dead_lock_without_lost_update(self):
        lock_module = json.dumps(str(REPO / 'helpers/state-lock.cjs'))
        self.run_js('require(' + lock_module + ').withStateLock(' + json.dumps(str(self.data)) + ',()=>process.exit(87));', ok=87)
        go = self.root / 'go'
        barrier = 'const fs=require("fs");while(!fs.existsSync(' + json.dumps(str(go)) + '))Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10);'
        a = self.start(barrier + self.call('memory.js', 'set', 'a', 'A'))
        b = self.start(barrier + self.call('memory.js', 'set', 'b', 'B'))
        go.touch()
        self.finish(a)
        self.finish(b)
        self.assertEqual({k:v for k,v in self.read('memory.json').items() if k != '_updated'}, {'a':'A','b':'B'})

    def test_record_edit_during_consolidation_is_not_acknowledged_early(self):
        self.seed()
        pending = self.data / 'pending-insights.jsonl'
        original = self.edits('first')
        pending.write_text(original)
        self.compete(pending, self.call('intelligence.cjs', 'consolidate'),
                     self.call('intelligence.cjs', 'recordEdit', 'later'))
        self.assertEqual(self.read('pending-insights-checkpoint.json')['offset'], len(original.encode()))
        self.run_js(self.call('intelligence.cjs', 'recordEdit', 'later') * 2)
        self.run_js(self.call('intelligence.cjs', 'consolidate'))
        entries = self.read('auto-memory-store.json')
        self.assertEqual(len([e for e in entries if e.get('metadata', {}).get('sourceFile') == 'later']), 1)

    def test_unverifiable_lock_owner_is_not_stolen(self):
        lock = self.data / '.helper-state.lock'
        lock.symlink_to('unrecognized-owner')
        code = 'require(' + json.dumps(str(REPO / 'helpers/state-lock.cjs')) + ').withStateLock(' + json.dumps(str(self.data)) + ',()=>{}, {timeoutMs:60});'
        self.assertNotEqual(self.run_js(code, ok=None), 0)
        self.assertEqual(os.readlink(lock), 'unrecognized-owner')

    def test_competing_appenders_keep_complete_records(self):
        go = self.root / 'go'
        barrier = 'const fs=require("fs");while(!fs.existsSync(' + json.dumps(str(go)) + '))Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10);'
        a = self.start(barrier + self.call('intelligence.cjs', 'recordEdit', 'first') * 12)
        b = self.start(barrier + self.call('intelligence.cjs', 'recordEdit', 'second') * 12)
        go.touch()
        self.finish(a)
        self.finish(b)
        rows = [json.loads(line) for line in (self.data / 'pending-insights.jsonl').read_text().splitlines()]
        self.assertEqual(len(rows), 24)
        self.assertEqual(sum(row['file'] == 'first' for row in rows), 12)
        self.assertFalse(os.path.lexists(self.data / '.pending-writers/.helper-state.lock'))

    def test_later_memory_writer_recovers_prepared_consolidation_first(self):
        self.seed()
        (self.data / 'pending-insights.jsonl').write_text(self.edits('first'))
        fail = '''const fs=require('fs');const rename=fs.renameSync;
          fs.renameSync=function(a,b){if(String(b).endsWith('/graph-state.json'))throw Error('fixture failure');return rename.call(fs,a,b);};'''
        self.assertNotEqual(self.run_js(fail + self.call('intelligence.cjs', 'consolidate'), ok=None), 0)
        self.run_js(self.call('memory.js', 'set', 'later', 'preserve'))
        self.assertFalse((self.data / '.intelligence-transaction.json').exists())
        self.assertEqual(self.read('memory.json')['later'], 'preserve')
        entries = self.read('auto-memory-store.json')
        self.assertEqual(set(self.read('graph-state.json')['nodes']), {e['id'] for e in entries})
        self.assertEqual(len(entries), 2)


    def test_same_timestamp_sessions_keep_distinct_archives(self):
        script = 'Date.now=()=>123456789;'
        for value in ('first', 'second'):
            script += self.call('session.js', 'start')
            script += self.call('session.js', 'update', 'value', value)
            script += self.call('session.js', 'end')
        self.run_js(script)
        archives = list((self.project / '.claude-flow/sessions').glob('session-*.json'))
        self.assertEqual(len(archives), 2)
        self.assertEqual({json.loads(p.read_text())['context']['value'] for p in archives}, {'first', 'second'})


if __name__ == '__main__':
    unittest.main(verbosity=2)
