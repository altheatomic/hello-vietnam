import test from 'node:test';
import assert from 'node:assert/strict';

import {
  escapeHtml,
  extractShareToken,
  normalizePublicTrip,
} from './app.js';

test('extractShareToken reads and decodes only /trip/<token>', () => {
  assert.equal(extractShareToken('/trip/abc_123-XYZ'), 'abc_123-XYZ');
  assert.equal(extractShareToken('/trip/a%20b'), 'a b');
  assert.equal(extractShareToken('/other/abc'), null);
  assert.equal(extractShareToken('/trip/'), null);
});

test('escapeHtml neutralizes markup from remote content', () => {
  assert.equal(
    escapeHtml('<img src=x onerror="alert(1)">&'),
    '&lt;img src=x onerror=&quot;alert(1)&quot;&gt;&amp;',
  );
});

test('normalizePublicTrip accepts the public DTO and rejects malformed days', () => {
  const trip = normalizePublicTrip({
    title: 'Hanoi weekend',
    allow_copy: true,
    expires_at: '2026-08-31T00:00:00Z',
    days: [{ day: 1, date: '2026-08-10', places: [{ name: 'Lake' }] }],
  });
  assert.equal(trip.title, 'Hanoi weekend');
  assert.equal(trip.days[0].places[0].name, 'Lake');
  assert.throws(() => normalizePublicTrip({ days: 'invalid' }), /Invalid shared trip/);
});
