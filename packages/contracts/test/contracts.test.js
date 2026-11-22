import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import {
  validateEvent,
  validateRegister,
  validateBatch,
  validateIdentify,
  MAX_BATCH_SIZE,
} from '../index.js';

const fixtures = (kind) => {
  const dir = new URL(`../fixtures/${kind}/`, import.meta.url);
  return readdirSync(dir).map((file) => ({
    file,
    value: JSON.parse(readFileSync(new URL(file, dir), 'utf8')),
  }));
};

const validatorFor = (file) => {
  if (file.startsWith('event_')) return validateEvent;
  if (file.startsWith('register_')) return validateRegister;
  if (file.startsWith('identify_')) return validateIdentify;
  return validateBatch;
};

for (const { file, value } of fixtures('valid')) {
  test(`valid fixture passes: ${file}`, () => {
    const result = validatorFor(file)(value);
    assert.deepEqual(result.errors, []);
    assert.equal(result.valid, true);
  });
}

for (const { file, value } of fixtures('invalid')) {
  test(`invalid fixture is rejected: ${file}`, () => {
    const result = validatorFor(file)(value);
    assert.equal(result.valid, false);
    assert.ok(result.errors.length > 0);
  });
}

test('every financial-looking key token is rejected', () => {
  const tokens = ['amount', 'fee', 'fees', 'rate', 'price', 'balance', 'revenue', 'volume', 'usd', 'total'];
  for (const token of tokens) {
    for (const key of [token, `sent_${token}`, `${token}_value`, `a_${token}_b`]) {
      const event = {
        eventId: 'evt_00000010',
        name: 'x.y',
        installId: 'inst_00000001',
        at: '2026-11-22T10:00:00Z',
        props: { [key]: 1 },
      };
      assert.equal(validateEvent(event).valid, false, `key ${key} must be rejected`);
    }
  }
});

test('keys that merely contain a token inside a word are allowed', () => {
  for (const key of ['migrated', 'feedback', 'separate', 'unit_name']) {
    const event = {
      eventId: 'evt_00000011',
      name: 'x.y',
      installId: 'inst_00000001',
      at: '2026-11-22T10:00:00Z',
      props: { [key]: 'ok' },
    };
    assert.equal(validateEvent(event).valid, true, `key ${key} should be allowed`);
  }
});

test('batch size limit is enforced by the envelope', () => {
  const events = Array.from({ length: MAX_BATCH_SIZE + 1 }, () => ({}));
  assert.equal(validateBatch({ events }).valid, false);
  assert.equal(validateBatch({ events: events.slice(0, MAX_BATCH_SIZE) }).valid, true);
});
