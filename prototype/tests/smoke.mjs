/**
 * Navin Journal Stage 3 UX prototype smoke checks.
 * Run: node prototype/tests/smoke.mjs
 *
 * Tests the demo's JavaScript navigation and copy using a tiny mocked DOM.
 * Does NOT run a real browser, accessibility audit, persistence, or encryption.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const base = path.dirname(fileURLToPath(import.meta.url));
const html = fs.readFileSync(path.join(base, '..', 'stage3-ux-preview.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'inline JavaScript must exist');
const events = {};
const state = { focused: 0, body: {}, extra: {} };
const app = {
  innerHTML: '',
  addEventListener(type, fn) { events[type] = fn; },
  insertAdjacentHTML(_position, content) { this.innerHTML += content; }
};
const doc = {
  body: { setAttribute(key, value) { state.body[key] = value; } },
  getElementById(id) {
    if (id === 'app') return app;
    if (id === 'draftBody') return { focus() { state.focused++; } };
    return state.extra[id] ?? (state.extra[id] = {
      innerHTML: '', focus() { state.focused++; }
    });
  },
  addEventListener(type, fn) { events['document:' + type] = fn; }
};
new Function('document', script)(doc);

const results = [];
const check = (name, value) => { assert.ok(value, name); results.push(name); };
const click = dataset => events.click({ target: { closest: () => ({ dataset }) } });

check('Welcome visible', app.innerHTML.includes('Begin the preview'));
click({ action: 'start' });
check('Setup visible', app.innerHTML.includes('Your first journal'));
click({ action: 'createVault' });
check('Today visible', app.innerHTML.includes('Your pages, your pace'));
click({ view: 'journals' });
check('Journals visible', app.innerHTML.includes('Your journals'));
click({ journal: 'Travel' });
check('Travel journal visible', app.innerHTML.includes('Your collection'));
click({ action: 'write' });
check('Write inherits Travel journal and receives focus',
  app.innerHTML.includes('Travel · 13 Nov 2026') && state.focused > 0);
click({ action: 'closeEditor' });
click({ view: 'memories' });
check('Timeline visible', app.innerHTML.includes('Memories'));
click({ memory: 'calendar' });
check('Calendar visible', app.innerHTML.includes('November 2026'));
click({ memory: 'gallery' });
check('Gallery visible', app.innerHTML.includes('memory-grid'));
click({ entry: '1' });
check('Reader visible', app.innerHTML.includes('The trip I’ll always remember'));
click({ action: 'goBack' });
check('Reader Back returns to Gallery', app.innerHTML.includes('memory-grid'));
click({ view: 'discover' });
check('Search visible', app.innerHTML.includes('Search your sample journal'));
click({ action: 'theme' });
check('Dark mode toggled', state.body['data-theme'] === 'dark');
click({ view: 'settings' });
click({ action: 'backup' });
check('Backup preview visible', app.innerHTML.includes('Backup & restore') && app.innerHTML.includes('Created, not verified'));
click({ backupState: 'failed' });
check('Backup failure preview visible', app.innerHTML.includes('Verification failed'));
click({ action: 'restoreFail' });
check('Restore rejected copy explains unchanged journal', app.innerHTML.includes('Your current journal should remain unchanged'));
click({ action: 'dismiss' });
click({ view: 'settings' });
click({ action: 'privacy' });
check('Privacy page discloses no encryption', app.innerHTML.includes('No encryption, authentication'));
click({ action: 'toggleVault' });
check('Simulated lock state switches', app.innerHTML.includes('Locked appearance selected'));
check('Clearly labelled design preview', html.includes('Not a working diary') && html.includes('Nothing is saved to disk'));
check('Tablet layout CSS present', html.includes('@media(min-width:900px)') && html.includes('reader-layout'));

console.log('Stage 3 mocked-DOM smoke checks passed: ' + results.length);
for (const name of results) console.log('  ✓ ' + name);
