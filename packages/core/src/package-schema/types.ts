export type CodexPetPackageType = 'codexpet.pet' | 'codexpet.nest';

export interface PackageManifestBase {
  type: CodexPetPackageType;
  schemaVersion: string;
  id: string;
  name?: string;
  displayName?: string;
  version: string;
  author: string;
  description: string;
  preview: string;
  tags?: string[];
  license?: string;
}

export interface PetPackageManifest extends PackageManifestBase {
  type: 'codexpet.pet';
  manifest: string;
  spritesheet: string;
}

export interface NestPackageManifest extends PackageManifestBase {
  type: 'codexpet.nest';
  layout?: string;
  theme?: string;
}

export type CodexPetPackageManifest = PetPackageManifest | NestPackageManifest;

export interface PetRuntimeManifest {
  id?: string;
  name?: string;
  displayName?: string;
  spritesheet?: string;
  frameWidth?: number;
  frameHeight?: number;
  frameSize?: { width: number; height: number };
  columns?: number;
  rows?: number;
  animations?: Record<string, unknown>;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface NestLayer {
  id: string;
  type: 'image';
  src: string;
  frame: Rect;
}

export interface WidgetSlot extends Rect {
  widget?: string;
}

export interface MetricBand {
  id: string;
  max: number;
}

export type NestElementType = 'staticImage' | 'variantImage' | 'metricText' | 'metricGauge';

export interface NestElementBase {
  id: string;
  type: NestElementType;
  frame: Rect;
  style?: Record<string, unknown>;
}

export interface StaticImageElement extends NestElementBase {
  type: 'staticImage';
  src: string;
}

export interface VariantImageElement extends NestElementBase {
  type: 'variantImage';
  metric: string;
  variants: Record<string, string>;
  fallback?: string;
}

export interface MetricTextElement extends NestElementBase {
  type: 'metricText';
  metric: string;
}

export interface MetricGaugeElement extends NestElementBase {
  type: 'metricGauge';
  metric: string;
  renderer: 'ringStroke' | 'linearBar' | 'circleFill';
}

export type NestElement =
  | StaticImageElement
  | VariantImageElement
  | MetricTextElement
  | MetricGaugeElement;

export interface NestLayoutManifest {
  schemaVersion: '1.0.0' | '1.1.0';
  canvas: { width: number; height: number };
  layers: NestLayer[];
  widgetSlots?: Record<string, WidgetSlot>;
  metricBands?: Record<string, MetricBand[]>;
  elements?: NestElement[];
}

export interface PackageFileEntry {
  path: string;
  sizeBytes: number;
  imageWidth?: number;
  imageHeight?: number;
}

export type ValidationIssueCode =
  | 'missing_manifest'
  | 'invalid_json_shape'
  | 'invalid_package_type'
  | 'missing_required_field'
  | 'missing_required_file'
  | 'unsafe_path'
  | 'remote_url'
  | 'unsafe_extension'
  | 'oversized_package'
  | 'oversized_image'
  | 'canvas_too_large'
  | 'invalid_layout'
  | 'invalid_metric_band'
  | 'invalid_element';

export interface ValidationIssue {
  code: ValidationIssueCode;
  message: string;
  path?: string;
}

export interface ValidationResult<T = unknown> {
  ok: boolean;
  value?: T;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
}

export interface PackageValidationInput {
  expectedType?: CodexPetPackageType;
  packageSizeBytes: number;
  files: PackageFileEntry[];
  packageManifest?: unknown;
  petManifest?: unknown;
  nestLayout?: unknown;
}
