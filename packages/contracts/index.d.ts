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

export interface UnlinkPayload {
  installId: string;
}

export interface IdentifyPayload {
  installId: string;
  userId: string;
  userHash?: string;
  email?: string;
  phone?: string;
  traits?: Record<string, TraitValue>;
  consent?: Partial<Record<ConsentChannel, 'granted' | 'denied'>>;
}

export const validateEvent: (value: unknown) => ValidationResult;
export const validateRegister: (value: unknown) => ValidationResult;
export const validateBatch: (value: unknown) => ValidationResult;
export const validateIdentify: (value: unknown) => ValidationResult;
export const validateUnlink: (value: unknown) => ValidationResult;
export const MAX_BATCH_SIZE: number;

export type ReplayNodeKind = 't' | 'i' | 'b' | 'f' | 'x' | 'm';
export type ReplayNode = [ReplayNodeKind, number, number, number, number] | [ReplayNodeKind, number, number, number, number, number];

export type ReplayEvent =
  | { t: number; k: 'snap'; w: number; h: number; so?: number; n: ReplayNode[] }
  | { t: number; k: 'tap'; x: number; y: number; dead?: true; rage?: true }
  | { t: number; k: 'scroll'; so: number; ch?: number }
  | { t: number; k: 'screen'; name: string }
  | { t: number; k: 'bg' | 'fg' | 'focus' };

export interface ReplayChunk {
  installId: string;
  sid: string;
  seq: number;
  startedAt: string;
  platform?: 'ios' | 'android' | 'web';
  end?: boolean;
  events: ReplayEvent[];
}

export const validateReplay: (value: unknown) => ValidationResult;
