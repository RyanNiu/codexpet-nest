import { useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useAppConfigStore } from '@/store/appConfigStore';
import { useRegistryStore } from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import type { AppConfig } from '@/config';
import type { ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

export function ConfigProvider({ children }: Props) {
  const { setConfig, setError } = useAppConfigStore();
  const loadRegistry = useRegistryStore((state) => state.load);
  const loadSettings = useSettingsStore((state) => state.load);

  useEffect(() => {
    invoke<AppConfig>('get_app_config')
      .then(setConfig)
      .catch((err) => {
        console.error('Failed to load app config:', err);
        setError(String(err));
      });
  }, [setConfig, setError]);

  useEffect(() => {
    void loadRegistry();
    void loadSettings();
  }, [loadRegistry, loadSettings]);

  return <>{children}</>;
}
