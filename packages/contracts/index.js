import { readFileSync } from 'node:fs';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';

const load = (name) =>
  JSON.parse(readFileSync(new URL(`./schemas/${name}.schema.json`, import.meta.url), 'utf8'));

const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });
addFormats.default(ajv);

const compile = (name) => {
  const validate = ajv.compile(load(name));
  return (value) => {
    const valid = validate(value);
    return valid
      ? { valid: true, errors: [] }
      : {
          valid: false,
          errors: (validate.errors ?? []).map((e) => `${e.instancePath || '/'} ${e.message}`),
        };
  };
};

export const validateEvent = compile('event');
export const validateRegister = compile('register');
export const validateBatch = compile('batch');
export const MAX_BATCH_SIZE = 50;
