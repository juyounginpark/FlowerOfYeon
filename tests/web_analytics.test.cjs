const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('web/analytics.js', 'utf8');
function setup(id = '', savedConsent = null) {
  const listeners = {}, scripts = [];
  const context = {window: {}, performance: {now: () => 100}, location: {origin: 'https://example.test', pathname: '/FlowerOfYeon/'},
    localStorage: {setItem() {}, getItem() {return savedConsent;}},
    document: {cookie: '', referrer: '', head: {appendChild: s => scripts.push(s)}, createElement: () => ({})},
    addEventListener: (name, cb) => {listeners[name] = cb;}};
  context.window.FLOWER_GA4_ID = id;
  vm.createContext(context); vm.runInContext(source, context);
  return {context, api: context.window.FlowerAnalytics, listeners, scripts};
}
test('absent or malformed measurement IDs never load Google', () => {
  for (const id of ['', '<script>', 'G-bad']) {
    const {api, scripts, context} = setup(id);
    api.consent(true); api.event('game_start');
    assert.equal(scripts.length, 0); assert.equal(context.window.gtag, undefined);
  }
});
test('automatic startup, fixed parameter allowlist, duplicate completion and withdrawal', () => {
  const {api, scripts, context, listeners} = setup('G-EXAMPLE123');
  api.event('game_start'); assert.equal(scripts.length, 1);
  api.consent(true); api.consent(true); assert.equal(scripts.length, 1);
  api.mark('game_load_complete'); api.mark('game_load_complete');
  api.event('game_start', {game_mode: 'story', email: 'never@example.test'});
  api.snapshot({play_seconds: 60, play_delta_seconds: 5, level_number: 4});
  listeners.pagehide({persisted: false}); listeners.pagehide({persisted: false});
  const events = context.window.dataLayer.filter(a => a[0] === 'event');
  assert.equal(events.filter(a => a[1] === 'game_load_complete').length, 1);
  assert.equal(events.filter(a => a[1] === 'game_end').length, 1);
  assert.equal(events.find(a => a[1] === 'game_start')[2].email, undefined);
  const before = events.length; api.consent(false); api.event('level_start');
  assert.equal(context.window.dataLayer.filter(a => a[0] === 'event').length, before);
});
test('Google script errors do not escape to game', () => {
  const {api, scripts} = setup('G-EXAMPLE123');
  api.consent(true); scripts[0].onerror();
  assert.doesNotThrow(() => api.event('level_complete', {duration_seconds: 12}));
});
test('saved opt-in captures loading before DOMContentLoaded', () => {
  const {api, scripts, context} = setup('G-EXAMPLE123', 'yes');
  assert.equal(scripts.length, 1);
  api.mark('game_load_start');
  assert.equal(context.window.dataLayer.filter(a => a[0] === 'event' && a[1] === 'game_load_start').length, 1);
});
test('page exit immediately after checkpoint does not count the same minute twice', () => {
  const {api, context, listeners} = setup('G-EXAMPLE123', 'yes');
  api.event('game_start');
  api.snapshot({play_seconds: 60, play_delta_seconds: 60, level_number: 4});
  api.event('playtime_checkpoint', {play_seconds: 60, play_delta_seconds: 60, level_number: 4});
  listeners.pagehide({persisted: false});
  const end = context.window.dataLayer.find(a => a[0] === 'event' && a[1] === 'game_end');
  assert.equal(end[2].play_delta_seconds, 0);
});

test('new visitor starts automatically but saved opt-out prevents requests', () => {
  const fresh = setup('G-EXAMPLE123');
  assert.equal(fresh.scripts.length, 1);
  fresh.api.mark('game_load_start');
  assert.equal(fresh.context.window.dataLayer.filter(a => a[0] === 'event' && a[1] === 'game_load_start').length, 1);
  const declined = setup('G-EXAMPLE123', 'no');
  assert.equal(declined.scripts.length, 0);
  declined.api.event('game_start');
  assert.equal(declined.context.window.gtag, undefined);
});
