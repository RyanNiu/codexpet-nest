import { create } from 'zustand';
import type { AppConfig } from '@/config';
import { FALLBACK_CONFIG } from '@/config';

interface AppConfigState {
  config: AppConfig;
  isLoading: boolean;
  error: string | null;
  setConfig: (config: AppConfig) => void;
  setError: (error: string) => void;
}

export const useAppConfigStore = create<AppConfigState>((set) => ({
  config: FALLBACK_CONFIG,
  isLoading: true,
  error: null,
  setConfig: (config: AppConfig) => set({ config, isLoading: false, error: null }),
  setError: (error: string) => set({ error, isLoading: false }),
}));
