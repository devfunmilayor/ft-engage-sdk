import { execFileSync } from 'node:child_process';
import { validateBatch, validateEvent, validateIdentify, validateRegister, validateReplay } from '@ft-engage/contracts';

const output = execFileSync('dart', ['run', 'tool/emit_samples.dart'], {
  cwd: new URL('../../core/', import.meta.url),
  encoding: 'utf8',
});

let checked = 0;
for (const line of output.split('\n').filter(Boolean)) {
  const { kind, payload } = JSON.parse(line);
  const results = [];
  if (kind === 'register') results.push(validateRegister(payload));
  else if (kind === 'identify') results.push(validateIdentify(payload));
  else if (kind === 'replay') results.push(validateReplay(payload));
  else {
    results.push(validateBatch(payload));
    for (const event of payload.events) results.push(validateEvent(event));
  }
  for (const result of results) {
    if (!result.valid) {
      console.error(`SDK output does not match the contract (${kind}):`, result.errors, payload);
      process.exit(1);
    }
    checked += 1;
  }
}
if (checked === 0) {
  console.error('no samples were produced');
  process.exit(1);
}
console.log(`wire check: ${checked} SDK payloads match the contracts`);
