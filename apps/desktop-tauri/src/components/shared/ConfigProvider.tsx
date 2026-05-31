import { useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useAppConfigStore } from '@/store/appConfigStore';
import type { AppConfig } from '@/config';
import type { ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

export function ConfigProvider({ children }: Props) {
  const { setConfig, setError } = useAppConfigStore();

  useEffect(() => {
    invoke<AppConfig>('get_app_config')
      .then(setConfig)
      .catch((err) => {
        console.error('Failed to load app config:', err);
        setError(String(err));
      });
  }, [setConfig, setError]);

  return <>{children}</>;
}
