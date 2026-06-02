import { describe, expect, it, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { createDefaultSettings } from '@codexpet/core';
import { useSettingsStore } from './settingsStore';

describe('useSettingsStore', () => {
  it('should update settings after save succeeds', async () => {
    useSettingsStore.setState({
      settings: createDefaultSettings(),
      isLoading: false,
      isSaving: false,
      error: null,
    });

    await useSettingsStore.getState().update({ overlayMode: 'standalone-fixed' });

    const state = useSettingsStore.getState();
    expect(state.settings.overlayMode).toBe('standalone-fixed');
    expect(state.isSaving).toBe(false);
    expect(state.error).toBeNull();
  });

  it('should keep previous settings when save fails', async () => {
    const previous = createDefaultSettings();
    useSettingsStore.setState({
      settings: previous,
      isLoading: false,
      isSaving: false,
      error: null,
    });
    vi.mocked(invoke).mockImplementationOnce(() => Promise.reject(new Error('disk full')));

    await expect(
      useSettingsStore.getState().update({ overlayMode: 'standalone-fixed' }),
    ).rejects.toThrow('disk full');

    const state = useSettingsStore.getState();
    expect(state.settings).toEqual(previous);
    expect(state.isSaving).toBe(false);
    expect(state.error).toContain('disk full');
  });
});
