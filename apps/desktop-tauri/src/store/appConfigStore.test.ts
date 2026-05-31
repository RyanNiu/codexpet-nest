import { describe, it, expect } from 'vitest';
import { useAppConfigStore } from './appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

describe('useAppConfigStore', () => {
  it('should initialize with fallback config and loading state', () => {
    const state = useAppConfigStore.getState();
    expect(state.config).toEqual(FALLBACK_CONFIG);
    expect(state.isLoading).toBe(true);
    expect(state.error).toBeNull();
  });

  it('should update config and clear loading on setConfig', () => {
    const newConfig = {
      ...FALLBACK_CONFIG,
      version: '0.2.0',
      platform: 'windows',
    };
    useAppConfigStore.getState().setConfig(newConfig);
    const state = useAppConfigStore.getState();
    expect(state.config.version).toBe('0.2.0');
    expect(state.config.platform).toBe('windows');
    expect(state.isLoading).toBe(false);
  });

  it('should set error state', () => {
    useAppConfigStore.getState().setError('Connection failed');
    const state = useAppConfigStore.getState();
    expect(state.error).toBe('Connection failed');
    expect(state.isLoading).toBe(false);
  });
});
