import { describe, expect, it } from 'vitest';
import { createDefaultSettings, loadSettings } from './index';

describe('settings schema', () => {
  it('creates default settings', () => {
    const settings = createDefaultSettings();

    expect(settings.schemaVersion).toBe(2);
    expect(settings.overlayMode).toBe('follow-codex');
    expect(settings.activeNestId).toBeNull();
    expect(settings.alwaysOnTop).toBe(true);
    expect(settings.clickThrough).toBe(false);
  });

  it('migrates v1 settings to the current schema', () => {
    const result = loadSettings({
      schemaVersion: 1,
      activeNestId: 'minimal-glass',
      overlayMode: 'standalone-fixed',
      standalonePosition: { x: 20, y: 30 },
      managedNestIds: ['minimal-glass'],
    });

    expect(result.usedFallback).toBe(false);
    expect(result.migrated).toBe(true);
    expect(result.settings.schemaVersion).toBe(2);
    expect(result.settings.activeNestId).toBe('minimal-glass');
    expect(result.settings.locale).toBe('system');
  });

  it('falls back for corrupted settings', () => {
    const result = loadSettings('not-json-object');

    expect(result.usedFallback).toBe(true);
    expect(result.settings).toEqual(createDefaultSettings());
    expect(result.errors.length).toBeGreaterThan(0);
  });
});
