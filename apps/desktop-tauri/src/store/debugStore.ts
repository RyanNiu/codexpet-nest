import { create } from 'zustand';

export interface Mascot {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface OverlayBounds {
  x: number;
  y: number;
  width: number;
  height: number;
  display_x: number;
  display_y: number;
  display_width: number;
  display_height: number;
  display_id: number | null;
  mascot: Mascot | null;
}

export interface CodexStateDebug {
  avatar_overlay_open: boolean;
  overlay_bounds: OverlayBounds | null;
  state_available: boolean;
  diagnostic: string;
  codex_home: string;
}

export interface ScreenInfo {
  x: number;
  y: number;
  width: number;
  height: number;
  scale_factor: number;
  is_primary: boolean;
}

export interface ConvertedPosition {
  x: number;
  y: number;
  scale_factor: number;
  display_index: number;
}

interface DebugState {
  codexState: CodexStateDebug | null;
  codexStateLoading: boolean;
  codexStateError: string | null;

  screens: ScreenInfo[];
  screensLoading: boolean;
  screensError: string | null;

  convertedPosition: ConvertedPosition | null;

  clickThrough: boolean;

  setCodexState: (state: CodexStateDebug) => void;
  setCodexStateError: (err: string) => void;
  setScreens: (screens: ScreenInfo[]) => void;
  setScreensError: (err: string) => void;
  setConvertedPosition: (pos: ConvertedPosition) => void;
  setClickThrough: (enabled: boolean) => void;
}

export const useDebugStore = create<DebugState>((set) => ({
  codexState: null,
  codexStateLoading: false,
  codexStateError: null,

  screens: [],
  screensLoading: false,
  screensError: null,

  convertedPosition: null,

  clickThrough: false,

  setCodexState: (state) =>
    set({ codexState: state, codexStateLoading: false, codexStateError: null }),
  setCodexStateError: (err) => set({ codexStateError: err, codexStateLoading: false }),
  setScreens: (screens) => set({ screens, screensLoading: false, screensError: null }),
  setScreensError: (err) => set({ screensError: err, screensLoading: false }),
  setConvertedPosition: (pos) => set({ convertedPosition: pos }),
  setClickThrough: (enabled) => set({ clickThrough: enabled }),
}));
