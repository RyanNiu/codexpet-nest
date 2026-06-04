import { afterEach, describe, it, expect, vi } from 'vitest';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
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

  afterEach(() => {
    vi.useRealTimers();
  });

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
    expect(screen.getAllByText('Follow Codex').length).toBeGreaterThan(0);
    expect(screen.getByLabelText('Active nest')).toHaveValue('default');
    expect(screen.getByRole('heading', { name: 'Local Packages / Nests' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Follow Status' })).toBeInTheDocument();
    expect(screen.getByText(/Runtime diagnostics stay here/)).toBeInTheDocument();
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

  it('should keep overlay mode, click-through, and show-hide controls usable', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);

    fireEvent.click(screen.getByRole('button', { name: 'Hide Overlay' }));
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('hide_overlay'));

    fireEvent.click(screen.getByRole('button', { name: 'Show Overlay' }));
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('show_overlay'));

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

    fireEvent.click(screen.getByRole('checkbox', { name: /Click-through/i }));
    await waitFor(() => {
      expect(vi.mocked(invoke)).toHaveBeenCalledWith('set_overlay_click_through', {
        enabled: true,
      });
    });
  });

  it('keeps development diagnostics collapsed outside normal settings rendering', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);

    expect(screen.getByRole('heading', { name: 'Overlay' })).toBeInTheDocument();
    expect(screen.getByText('Development Diagnostics')).toBeInTheDocument();
    expect(screen.getByTestId('debug-panel')).toBeInTheDocument();
    expect(screen.getByText(/Developer-only tools/)).toBeInTheDocument();
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('refreshes follow diagnostics while settings stays open', async () => {
    vi.useFakeTimers();
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<SettingsApp />);

    expect(screen.getByText('Not recorded yet')).toBeInTheDocument();

    window.localStorage.setItem(
      'codexpet.overlay.followDiagnostics',
      JSON.stringify({
        runtimeMode: 'follow-codex',
        lastCodexStateReadAt: '2026-06-03T12:00:00.000Z',
        lastTargetPosition: 'x=120, y=140',
        followLoopActive: true,
        lastMoveFailure: null,
      }),
    );

    await act(async () => {
      vi.advanceTimersByTime(1_000);
    });

    expect(screen.getByText('Active')).toBeInTheDocument();
    expect(screen.getByText('2026-06-03T12:00:00.000Z')).toBeInTheDocument();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible');
  });

  it('should display widgets/actions and toggle action enabled', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });

    render(<SettingsApp />);

    expect(screen.getByRole('heading', { name: 'Widgets / Actions' })).toBeInTheDocument();
    expect(screen.getByText('clock-widget')).toBeInTheDocument();
    expect(screen.getByText('Open Docs')).toBeInTheDocument();
    expect(screen.getAllByText('platform: all').length).toBeGreaterThan(0);
    expect(screen.getAllByText('confirm: false').length).toBeGreaterThan(0);

    const openDocsToggle = screen.getByRole('checkbox', { name: 'Enable Open Docs' });
    await waitFor(() => expect(openDocsToggle).not.toBeDisabled());
    fireEvent.click(openDocsToggle);

    await waitFor(() => {
      expect(vi.mocked(invoke)).toHaveBeenCalledWith(
        'save_local_settings',
        expect.objectContaining({
          settings: expect.objectContaining({
            quickActions: expect.arrayContaining([
              expect.objectContaining({ id: 'open-codexpet-docs', enabled: false }),
            ]),
          }),
        }),
      );
    });
  });

  it('should show imported and disabled nests but only select enabled nests', async () => {
    const importedNest = {
      ...builtInNestRegistryEntries[0]!,
      id: 'imported-nest',
      name: 'Imported Nest',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
    };
    const disabledNest = {
      ...builtInNestRegistryEntries[0]!,
      id: 'disabled-nest',
      name: 'Disabled Nest',
      enabled: false,
    };
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({
      registry: {
        schemaVersion: 1,
        packages: [...builtInNestRegistryEntries, importedNest, disabledNest],
      },
      isLoading: false,
    });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });

    render(<SettingsApp />);

    expect(screen.getAllByText('Imported Nest').length).toBeGreaterThan(0);
    expect(screen.getByText('Disabled Nest')).toBeInTheDocument();
    expect(screen.getAllByText('disabled').length).toBeGreaterThan(0);
    expect(screen.getByLabelText('Active nest')).toHaveValue('default');
    expect(screen.getByRole('option', { name: 'Imported Nest' })).toBeInTheDocument();
    expect(screen.queryByRole('option', { name: 'Disabled Nest' })).not.toBeInTheDocument();
    await waitFor(() => expect(vi.mocked(invoke)).toHaveBeenCalledWith('is_overlay_visible'));
  });

  it('should import local package by directory path', async () => {
    const importedRegistry = {
      schemaVersion: 1,
      packages: [
        ...builtInNestRegistryEntries,
        {
          ...builtInNestRegistryEntries[0]!,
          id: 'imported-nest',
          name: 'Imported Nest',
          manifestPath: '/tmp/imported/codexpet-package.json',
          assetRoot: '/tmp/imported',
        },
      ],
    };
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false, isSaving: false, error: null });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'import_local_package') return Promise.resolve(importedRegistry);
      if (command === 'is_overlay_visible') return Promise.resolve(true);
      return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    });

    render(<SettingsApp />);
    fireEvent.change(screen.getByLabelText('Local package directory'), {
      target: { value: '/tmp/imported' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Import' }));

    await waitFor(() => expect(screen.getAllByText('Imported Nest').length).toBeGreaterThan(0));
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('import_local_package', {
      importPath: '/tmp/imported',
    });
  });

  it('should export local settings and registry snapshot', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false, isSaving: false, error: null });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });

    render(<SettingsApp />);
    fireEvent.change(screen.getByLabelText('Local snapshot export path'), {
      target: { value: '/tmp/codexpet-nest-snapshot.json' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Export Snapshot' }));

    expect(await screen.findByRole('status')).toHaveTextContent(/Exported local snapshot/);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('export_local_snapshot', {
      exportPath: '/tmp/codexpet-nest-snapshot.json',
      settings: expect.objectContaining({ schemaVersion: 3 }),
      registry: expect.objectContaining({ schemaVersion: 1 }),
    });
  });

  it('should import local snapshot and reload local stores', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false, isSaving: false, error: null });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });

    render(<SettingsApp />);
    fireEvent.change(screen.getByLabelText('Local snapshot import path'), {
      target: { value: '/tmp/codexpet-nest-snapshot.json' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Import Snapshot' }));

    expect(await screen.findByRole('status')).toHaveTextContent(/Imported local snapshot/);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('import_local_snapshot', {
      importPath: '/tmp/codexpet-nest-snapshot.json',
    });
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('load_local_settings');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('load_local_registry');
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
