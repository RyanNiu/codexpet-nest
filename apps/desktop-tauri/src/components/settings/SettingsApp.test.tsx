import { describe, it, expect, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import { createDefaultSettings } from '@codexpet/core';
import { SettingsApp } from './SettingsApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { builtInNestRegistryEntries, useRegistryStore } from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import { FALLBACK_CONFIG } from '@/config';

vi.mock('@/components/debug/DebugPanel', () => ({
  DebugPanel: () => <div data-testid="debug-panel" />,
}));

describe('SettingsApp', () => {
  const registry = { schemaVersion: 1, packages: builtInNestRegistryEntries };

  it('should show loading state', async () => {
    render(<SettingsApp />);
    expect(screen.getByText('Loading configuration...')).toBeInTheDocument();
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('should render config details when loaded', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);
    expect(screen.getByRole('heading', { name: /Settings/i })).toBeInTheDocument();
    expect(screen.getByText(/Version: 0.1.12/)).toBeInTheDocument();
    expect(screen.getByLabelText('Overlay mode')).toHaveValue('follow-codex');
    expect(screen.getByLabelText('Active nest')).toHaveValue('default');
    expect(screen.getByRole('heading', { name: 'Local Packages / Nests' })).toBeInTheDocument();
    expect(screen.getAllByText('Capacity Orbit Nest').length).toBeGreaterThan(0);
    expect(screen.getAllByText('nest').length).toBeGreaterThan(0);
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
    useRegistryStore.setState({ registry, isLoading: false });
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

    fireEvent.change(screen.getByLabelText('Active nest'), {
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

  it('should not save click-through when native command fails', async () => {
    const previous = createDefaultSettings();
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: previous, isLoading: false });
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'set_overlay_click_through') {
        return Promise.reject(new Error('native failed'));
      }
      if (command === 'is_overlay_visible') {
        return Promise.resolve(true);
      }
      if (command === 'save_local_settings') {
        return Promise.resolve(undefined);
      }
      return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    });
    render(<SettingsApp />);

    fireEvent.click(screen.getByRole('checkbox', { name: /Click-through/i }));

    expect(await screen.findByText(/native failed/)).toBeInTheDocument();
    expect(vi.mocked(invoke)).not.toHaveBeenCalledWith(
      'save_local_settings',
      expect.objectContaining({
        settings: expect.objectContaining({ clickThrough: true }),
      }),
    );
    expect(useSettingsStore.getState().settings.clickThrough).toBe(false);
  });
});
