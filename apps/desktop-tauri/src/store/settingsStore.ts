import { invoke } from '@tauri-apps/api/core';
import { create } from 'zustand';
import { createDefaultSettings, loadSettings } from '@codexpet/core';
import type { CodexPetSettings } from '@codexpet/core';

interface SettingsState {
  settings: CodexPetSettings;
  isLoading: boolean;
  isSaving: boolean;
  error: string | null;
  load: () => Promise<void>;
  update: (patch: Partial<CodexPetSettings>) => Promise<void>;
}

export const useSettingsStore = create<SettingsState>((set, get) => ({
  settings: createDefaultSettings(),
  isLoading: true,
  isSaving: false,
  error: null,
  load: async () => {
    set({ isLoading: true, error: null });
    try {
      const raw = await invoke<unknown | null>('load_local_settings');
      const result = raw === null ? loadSettings(createDefaultSettings()) : loadSettings(raw);
      set({ settings: result.settings, isLoading: false, error: null });

      if (raw === null || result.migrated || result.usedFallback) {
        await invoke('save_local_settings', { settings: result.settings });
      }
    } catch (error) {
      set({ settings: createDefaultSettings(), isLoading: false, error: String(error) });
    }
  },
  update: async (patch) => {
    const next = loadSettings({ ...get().settings, ...patch }).settings;
    set({ isSaving: true, error: null });
    try {
      await invoke('save_local_settings', { settings: next });
      set({ settings: next, isSaving: false, error: null });
    } catch (error) {
      set({ isSaving: false, error: String(error) });
      throw error;
    }
  },
}));
