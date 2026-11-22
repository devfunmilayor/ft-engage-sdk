export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

export interface EngageEvent {
  eventId: string;
  name: string;
  installId: string;
  userId?: string;
  screen?: string;
  at: string;
  props?: Record<string, string | number | boolean | null>;
}

export interface RegisterPayload {
  installId: string;
  platform: 'ios' | 'android' | 'web';
  appVersion?: string;
  sdkVersion?: string;
  timezone?: string;
  locale?: string;
  pushStatus?: 'granted' | 'denied' | 'unknown';
  pushToken?: string;
}

export interface BatchPayload {
  sentAt?: string;
  events: unknown[];
}

export type TraitValue = string | number | boolean | null;
export type ConsentChannel = 'email' | 'whatsapp' | 'sms';

export interface IdentifyPayload {
  installId: string;
  userId: string;
  email?: string;
  phone?: string;
  traits?: Record<string, TraitValue>;
  consent?: Partial<Record<ConsentChannel, 'granted' | 'denied'>>;
}

export const validateEvent: (value: unknown) => ValidationResult;
export const validateRegister: (value: unknown) => ValidationResult;
export const validateBatch: (value: unknown) => ValidationResult;
export const validateIdentify: (value: unknown) => ValidationResult;
export const MAX_BATCH_SIZE: number;
