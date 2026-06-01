import { describe, it, expect, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import { createDefaultSettings } from '@codexpet/core';
import { SettingsApp } from './SettingsApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { useSettingsStore } from '@/store/settingsStore';
import { FALLBACK_CONFIG } from '@/config';

vi.mock('@/components/debug/DebugPanel', () => ({
  DebugPanel: () => <div data-testid="debug-panel" />,
}));

describe('SettingsApp', () => {
  it('should show loading state', async () => {
    render(<SettingsApp />);
    expect(screen.getByText('Loading configuration...')).toBeInTheDocument();
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('should render config details when loaded', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);
    expect(screen.getByRole('heading', { name: /Settings/i })).toBeInTheDocument();
    expect(screen.getByText(/Version: 0.1.12/)).toBeInTheDocument();
    expect(screen.getByLabelText('Overlay mode')).toHaveValue('follow-codex');
    expect(screen.getByLabelText('Built-in nest')).toHaveValue('default');
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('should show error state', async () => {
    useAppConfigStore.getState().setError('Test error');
    render(<SettingsApp />);
    expect(screen.getByText(/Test error/)).toBeInTheDocument();
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('should save settings when nest and mode are changed', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);

    fireEvent.change(screen.getByLabelText('Overlay mode'), {
      target: { value: 'standalone-fixed' },
    });
    await waitFor(() => {
      expect(vi.mocked(invoke)).toHaveBeenCalledWith(
        'save_local_settings',
        expect.objectContaining({
          settings: expect.objectContaining({ overlayMode: 'standalone-fixed' }),
        }),
      );
    });

    fireEvent.change(screen.getByLabelText('Built-in nest'), {
      target: { value: 'basket-pomodoro-nest' },
    });
    await waitFor(() => {
      expect(vi.mocked(invoke)).toHaveBeenCalledWith(
        'save_local_settings',
        expect.objectContaining({
          settings: expect.objectContaining({ activeNestId: 'basket-pomodoro-nest' }),
        }),
      );
    });
  });
});
