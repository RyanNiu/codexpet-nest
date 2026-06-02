import { describe, expect, it } from 'vitest';
import {
  BUILT_IN_QUICK_ACTIONS,
  createDefaultSettings,
  loadSettings,
  validateActionTarget,
  validateWidgetActionConfig,
} from './index';

describe('settings schema', () => {
  it('creates default settings', () => {
    const settings = createDefaultSettings();

    expect(settings.schemaVersion).toBe(3);
    expect(settings.overlayMode).toBe('follow-codex');
    expect(settings.activeNestId).toBeNull();
    expect(settings.alwaysOnTop).toBe(true);
    expect(settings.clickThrough).toBe(false);
    expect(settings.widgets.length).toBeGreaterThan(0);
    expect(settings.quickActions.length).toBeGreaterThan(0);
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
    expect(result.settings.schemaVersion).toBe(3);
    expect(result.settings.activeNestId).toBe('minimal-glass');
    expect(result.settings.locale).toBe('system');
  });

  it('preserves standalone position when switching overlay modes', () => {
    const result = loadSettings({
      ...createDefaultSettings(),
      overlayMode: 'follow-codex',
      standalonePosition: { x: 320, y: 180, displayId: 'retina-main' },
    });

    const switched = loadSettings({ ...result.settings, overlayMode: 'standalone-fixed' });

    expect(switched.settings.overlayMode).toBe('standalone-fixed');
    expect(switched.settings.standalonePosition).toEqual({
      x: 320,
      y: 180,
      displayId: 'retina-main',
    });
  });

  it('falls back for corrupted settings', () => {
    const result = loadSettings('not-json-object');

    expect(result.usedFallback).toBe(true);
    expect(result.settings).toEqual(createDefaultSettings());
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('validates widget/action config and target allowlist', () => {
    const result = validateWidgetActionConfig(
      [
        {
          id: 'actions-widget',
          type: 'action-list',
          enabled: true,
          slot: 'actions',
          actionIds: ['missing-action'],
          platform: 'all',
        },
      ],
      [
        ...BUILT_IN_QUICK_ACTIONS,
        {
          id: 'bad-url',
          name: 'Bad URL',
          kind: 'url',
          target: 'file:///tmp/secret',
          enabled: true,
          requireConfirm: false,
          platform: 'all',
        },
      ],
      'macos',
    );

    expect(result.errors).toContain(
      'Widget actions-widget references missing action missing-action',
    );
    expect(result.errors).toContain('bad-url: URL target is not allowlisted: file:///tmp/secret');
  });

  it('validates URL actions against the local action allowlist', () => {
    expect(
      validateActionTarget({
        id: 'docs',
        name: 'Docs',
        kind: 'url',
        target: 'https://codexpet.xyz/docs',
        enabled: true,
        requireConfirm: false,
        platform: 'all',
      }),
    ).toBeNull();
    expect(
      validateActionTarget({
        id: 'local',
        name: 'Localhost',
        kind: 'url',
        target: 'http://localhost:1420/debug',
        enabled: true,
        requireConfirm: false,
        platform: 'all',
      }),
    ).toBeNull();
    expect(
      validateActionTarget({
        id: 'evil',
        name: 'Evil',
        kind: 'url',
        target: 'https://evil.com/phishing',
        enabled: true,
        requireConfirm: false,
        platform: 'all',
      }),
    ).toBe('URL target is not allowlisted: https://evil.com/phishing');
    expect(
      validateActionTarget({
        id: 'plain-http',
        name: 'Plain HTTP',
        kind: 'url',
        target: 'http://example.com',
        enabled: true,
        requireConfirm: false,
        platform: 'all',
      }),
    ).toBe('URL target is not allowlisted: http://example.com');
  });

  it('disables actions on unsupported platform', () => {
    const result = validateWidgetActionConfig(
      [],
      [
        {
          id: 'mac-only',
          name: 'Mac Only',
          kind: 'url',
          target: 'https://codexpet.xyz/docs',
          enabled: true,
          requireConfirm: false,
          platform: 'macos',
        },
      ],
      'linux',
    );

    expect(result.quickActions.find((action) => action.id === 'mac-only')?.enabled).toBe(false);
  });
});
