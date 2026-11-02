/* Optional GA4, basic consent mode: no Google request before explicit opt-in. */
(() => {
  'use strict';
  if (window.FlowerAnalytics) return;
  const id = window.FLOWER_GA4_ID || '';
  const valid = /^G-[A-Z0-9]+$/.test(id);
  const started = performance.now();
  let enabled = false, configured = false, ended = false, snapshot = null;
  const once = new Set();
  const allowed = new Set(['game_load_start', 'game_files_loaded', 'game_engine_started',
    'game_load_complete', 'game_start', 'level_start', 'level_complete', 'level_fail',
    'game_end', 'playtime_checkpoint', 'game_load_error']);
  function event(name, params = {}) {
    if (!enabled || !allowed.has(name)) return;
    try {
      // Only fixed, numeric and enum game parameters cross this boundary.
      const clean = {};
      for (const key of ['level_number', 'duration_seconds', 'load_seconds', 'play_seconds', 'play_delta_seconds']) {
        if (Number.isFinite(params[key])) clean[key] = Math.max(0, params[key]);
      }
      if (params.game_mode === 'story') clean.game_mode = 'story';
      if (['fall', 'restart'].includes(params.failure_type)) clean.failure_type = params.failure_type;
      if (['engine', 'features', 'network'].includes(params.error_type)) clean.error_type = params.error_type;
      if (name === 'game_start') ended = false;
      if (name === 'game_end') { if (ended) return; ended = true; }
      if (name === 'playtime_checkpoint' && snapshot) {
        snapshot = {play_seconds: clean.play_seconds, play_delta_seconds: 0, level_number: clean.level_number};
      }
      window.gtag('event', name, {...clean, transport_type: 'beacon'});
    } catch (_) { /* Telemetry never blocks the game. */ }
  }
  function mark(name, params = {}) {
    if (once.has(name)) return;
    once.add(name);
    event(name, params);
  }
  function consent(value) {
    enabled = valid && value;
    try { localStorage.setItem('flower_analytics_consent', value ? 'yes' : 'no'); } catch (_) {}
    window['ga-disable-' + id] = !enabled;
    if (!enabled) {
      if (configured) window.gtag('consent', 'update', {analytics_storage: 'denied'});
      // Remove this path's standard GA cookies after withdrawal.
      for (const cookie of document.cookie.split(';')) {
        const name = cookie.trim().split('=')[0];
        if (/^_ga(?:_|$)/.test(name)) document.cookie = name + '=; Max-Age=0; path=/FlowerOfYeon/';
      }
      return;
    }
    if (configured) { window.gtag('consent', 'update', {analytics_storage: 'granted'}); return; }
    configured = true;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('consent', 'default', {analytics_storage: 'granted', ad_storage: 'denied',
      ad_user_data: 'denied', ad_personalization: 'denied'});
    window.gtag('js', new Date());
    // Strip URL query/hash and referrer paths to avoid arbitrary personal input.
    let referrer = '';
    try { if (document.referrer) referrer = new URL(document.referrer).origin; } catch (_) {}
    window.gtag('config', id, {send_page_view: true, page_location: location.origin + location.pathname,
      page_referrer: referrer, page_title: 'FlowerOfYeon', allow_google_signals: false,
      allow_ad_personalization_signals: false, cookie_path: '/FlowerOfYeon/'});
    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
    script.onerror = () => { enabled = false; };
    document.head.appendChild(script);
    // Do not replay pre-consent milestones or invent historical observations.
  }
  window.FlowerAnalytics = {
    event, mark,
    initialized: () => mark('game_load_complete', {load_seconds: (performance.now() - started) / 1000}),
    snapshot: value => { snapshot = value; },
    consent
  };
  // Restore prior opt-in before the HTML loader starts, not after DOMContentLoaded.
  if (valid) {
    try { if (localStorage.getItem('flower_analytics_consent') === 'yes') consent(true); } catch (_) {}
  }
  addEventListener('pagehide', e => {
    if (!e.persisted && snapshot) event('game_end', snapshot);
  });
  // bfcache navigation is a suspension; do not manufacture another game session.
  if (valid) addEventListener('DOMContentLoaded', () => {
    const panel = document.createElement('aside');
    panel.id = 'analytics-consent';
    panel.style.cssText = 'position:fixed;bottom:8px;left:8px;z-index:100;color:#39372d;background:#f3e7ce;padding:8px 12px;border-radius:6px;font:13px sans-serif;max-width:340px';
    panel.append('선택적 방문·플레이 통계(Google Analytics). 동의 전에는 수집하지 않습니다. ');
    const accept = document.createElement('button'); accept.textContent = '동의';
    const reject = document.createElement('button'); reject.textContent = '거부';
    const settings = document.createElement('button'); settings.textContent = '분석 설정';
    const description = panel.firstChild;
    const collapse = () => { description.textContent = ''; accept.hidden = reject.hidden = true; settings.hidden = false; };
    accept.onclick = () => { consent(true); collapse(); };
    reject.onclick = () => { consent(false); collapse(); };
    settings.onclick = () => {
      description.textContent = '방문·기기·지역·참여시간·게임 이벤트가 Google로 전달될 수 있습니다. 동의를 철회하려면 거부를 선택하세요. ';
      accept.hidden = reject.hidden = false; settings.hidden = true;
    };
    settings.hidden = true;
    panel.append(accept, reject, settings); document.body.appendChild(panel);
    try {
      const saved = localStorage.getItem('flower_analytics_consent');
      if (saved === 'yes') { consent(true); collapse(); }
      else if (saved === 'no') collapse();
    } catch (_) {}
  });
})();
