import type {
  CodexPetPackageManifest,
  CodexPetPackageType,
  MetricBand,
  NestElement,
  PackageFileEntry,
  PackageValidationInput,
  ValidationIssue,
  ValidationResult,
} from './types';

export const MAX_PACKAGE_BYTES = 5 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
export const RECOMMENDED_MAX_CANVAS = 512;

const SAFE_RESOURCE_EXTENSIONS = new Set(['png', 'webp', 'gif', 'json', 'md', 'txt']);
const SAFE_LICENSE_NAMES = new Set(['license', 'licence', 'copying', 'notice']);
const SCRIPT_EXTENSIONS = new Set([
  'js',
  'jsx',
  'ts',
  'tsx',
  'mjs',
  'cjs',
  'sh',
  'py',
  'rb',
  'pl',
  'php',
  'command',
]);
const EXECUTABLE_EXTENSIONS = new Set([
  'exe',
  'app',
  'dmg',
  'bat',
  'cmd',
  'ps1',
  'msi',
  'deb',
  'rpm',
  'jar',
]);
const ALLOWED_ELEMENT_TYPES = new Set(['staticImage', 'variantImage', 'metricText', 'metricGauge']);
const ALLOWED_GAUGE_RENDERERS = new Set(['ringStroke', 'linearBar', 'circleFill']);
const ALLOWED_METRICS = new Set([
  'usage.primary.used_percent',
  'usage.primary.remaining_percent',
  'usage.primary.remaining_ratio',
  'usage.primary.remaining_band',
  'usage.primary.reset_after_seconds',
  'usage.primary.reset_label',
  'usage.secondary.used_percent',
  'usage.secondary.remaining_percent',
  'usage.secondary.remaining_ratio',
  'usage.secondary.remaining_band',
  'usage.secondary.reset_after_seconds',
  'usage.secondary.reset_label',
  'usage.allowed',
  'usage.limit_reached',
  'usage.source',
  'usage.plan_type',
  'system.time.hour',
  'system.time.minute',
  'system.time.day_period',
  'system.time.weekday',
  'system.time.is_weekend',
  'system.time.hhmm',
  'system.date.short',
  'pomodoro.state',
  'pomodoro.remaining_ratio',
  'pomodoro.remaining_label',
  'countdown.remaining_label',
  'countdown.state',
]);

export function validatePackage(
  input: PackageValidationInput,
): ValidationResult<CodexPetPackageManifest> {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];
  const fileSet = new Set(input.files.map((file) => normalizePackagePath(file.path)));

  validateFileEntries(input.files, errors);

  if (input.packageSizeBytes > MAX_PACKAGE_BYTES) {
    errors.push({
      code: 'oversized_package',
      message: `Package exceeds ${MAX_PACKAGE_BYTES} bytes limit`,
    });
  }

  for (const file of input.files) {
    if (isImagePath(file.path) && file.sizeBytes > MAX_IMAGE_BYTES) {
      errors.push({
        code: 'oversized_image',
        message: `Image exceeds ${MAX_IMAGE_BYTES} bytes limit`,
        path: file.path,
      });
    }
  }

  if (!input.packageManifest) {
    errors.push({
      code: 'missing_manifest',
      message: 'codexpet-package.json is required',
      path: 'codexpet-package.json',
    });
    return result(errors, warnings);
  }

  const manifest = validatePackageManifest(input.packageManifest, input.expectedType, errors);
  if (!manifest) return result(errors, warnings);

  validateReferencedPath(manifest.preview, 'preview', errors, fileSet);
  if (manifest.type === 'codexpet.pet') {
    validateReferencedPath(manifest.manifest, 'manifest', errors, fileSet);
    validateReferencedPath(manifest.spritesheet, 'spritesheet', errors, fileSet);
    validatePetRuntimeManifest(input.petManifest, errors);
  } else {
    const layoutPath = manifest.layout ?? manifest.theme;
    if (!layoutPath) {
      errors.push({
        code: 'missing_required_field',
        message: 'Nest package requires layout or theme',
      });
    } else {
      validateReferencedPath(layoutPath, 'layout', errors, fileSet);
    }
    validateNestLayout(input.nestLayout, errors, warnings, fileSet);
  }

  return result(errors, warnings, manifest);
}

export function isSafePackagePath(path: string): boolean {
  const normalized = normalizePackagePath(path);
  return (
    normalized.length > 0 &&
    !isRemoteUrl(normalized) &&
    !normalized.startsWith('/') &&
    !/^[a-zA-Z]:\//.test(normalized) &&
    !normalized.split('/').some((part) => part === '..' || part === '')
  );
}

export function isRemoteUrl(value: string): boolean {
  return /^[a-z][a-z0-9+.-]*:/i.test(value) || value.startsWith('//');
}

function validateFileEntries(files: PackageFileEntry[], errors: ValidationIssue[]): void {
  for (const file of files) {
    if (!isSafePackagePath(file.path)) {
      errors.push({
        code: 'unsafe_path',
        message: 'Package file path must be local and relative',
        path: file.path,
      });
      continue;
    }

    const ext = extension(file.path);
    const base = basenameWithoutExtension(file.path).toLowerCase();
    if (SCRIPT_EXTENSIONS.has(ext)) {
      errors.push({
        code: 'unsafe_extension',
        message: 'Script files are not allowed',
        path: file.path,
      });
    } else if (EXECUTABLE_EXTENSIONS.has(ext)) {
      errors.push({
        code: 'unsafe_extension',
        message: 'Executable files are not allowed',
        path: file.path,
      });
    } else if (!SAFE_RESOURCE_EXTENSIONS.has(ext) && !SAFE_LICENSE_NAMES.has(base)) {
      errors.push({
        code: 'unsafe_extension',
        message: 'File extension is not allowed',
        path: file.path,
      });
    }
  }
}

function validatePackageManifest(
  value: unknown,
  expectedType: CodexPetPackageType | undefined,
  errors: ValidationIssue[],
): CodexPetPackageManifest | null {
  if (!isRecord(value)) {
    errors.push({ code: 'invalid_json_shape', message: 'codexpet-package.json must be an object' });
    return null;
  }

  const type = value.type;
  if (type !== 'codexpet.pet' && type !== 'codexpet.nest') {
    errors.push({
      code: 'invalid_package_type',
      message: 'Package type must be codexpet.pet or codexpet.nest',
    });
    return null;
  }
  if (expectedType && type !== expectedType) {
    errors.push({ code: 'invalid_package_type', message: `Expected ${expectedType}, got ${type}` });
  }

  const commonFields = ['schemaVersion', 'id', 'version', 'author', 'description', 'preview'];
  for (const field of commonFields) requireString(value, field, errors);
  if (typeof value.name !== 'string' && typeof value.displayName !== 'string') {
    errors.push({
      code: 'missing_required_field',
      message: 'Package requires name or displayName',
    });
  }
  if (value.tags !== undefined && !isStringArray(value.tags)) {
    errors.push({ code: 'invalid_json_shape', message: 'tags must be a string array' });
  }

  if (type === 'codexpet.pet') {
    requireString(value, 'manifest', errors);
    requireString(value, 'spritesheet', errors);
  }

  if (errors.length > 0) return null;
  return value as unknown as CodexPetPackageManifest;
}

function validatePetRuntimeManifest(value: unknown, errors: ValidationIssue[]): void {
  if (!value) {
    errors.push({ code: 'missing_manifest', message: 'pet.json is required', path: 'pet.json' });
    return;
  }
  if (!isRecord(value)) {
    errors.push({ code: 'invalid_json_shape', message: 'pet.json must be an object' });
    return;
  }
  if (typeof value.name !== 'string' && typeof value.displayName !== 'string') {
    errors.push({
      code: 'missing_required_field',
      message: 'pet.json requires name or displayName',
    });
  }
}

function validateNestLayout(
  value: unknown,
  errors: ValidationIssue[],
  warnings: ValidationIssue[],
  fileSet: ReadonlySet<string>,
): void {
  if (!value) {
    errors.push({ code: 'missing_manifest', message: 'nest.json is required', path: 'nest.json' });
    return;
  }
  if (!isRecord(value)) {
    errors.push({ code: 'invalid_json_shape', message: 'nest.json must be an object' });
    return;
  }
  if (value.schemaVersion !== '1.0.0' && value.schemaVersion !== '1.1.0') {
    errors.push({
      code: 'invalid_layout',
      message: 'nest.json schemaVersion must be 1.0.0 or 1.1.0',
    });
  }
  if (
    !isRecord(value.canvas) ||
    !isPositiveFinite(value.canvas.width) ||
    !isPositiveFinite(value.canvas.height)
  ) {
    errors.push({
      code: 'invalid_layout',
      message: 'nest.json requires positive finite canvas width and height',
    });
  } else if (
    value.canvas.width > RECOMMENDED_MAX_CANVAS ||
    value.canvas.height > RECOMMENDED_MAX_CANVAS
  ) {
    warnings.push({
      code: 'canvas_too_large',
      message: 'Canvas is larger than the recommended 512x512 size',
    });
  }
  if (!Array.isArray(value.layers)) {
    errors.push({ code: 'invalid_layout', message: 'nest.json requires layers array' });
  } else {
    validateLayers(value.layers, errors, fileSet);
  }
  if (value.metricBands !== undefined) validateMetricBands(value.metricBands, errors);
  if (value.elements !== undefined) validateElements(value.elements, errors, fileSet);
}

function validateLayers(
  layers: unknown[],
  errors: ValidationIssue[],
  fileSet: ReadonlySet<string>,
): void {
  for (const layer of layers) {
    if (
      !isRecord(layer) ||
      typeof layer.id !== 'string' ||
      layer.type !== 'image' ||
      typeof layer.src !== 'string'
    ) {
      errors.push({ code: 'invalid_layout', message: 'Layer requires id, type=image, and src' });
      continue;
    }
    validateReferencedPath(layer.src, `layer ${layer.id}`, errors, fileSet);
    validateFrame(layer.frame, errors, `layer ${layer.id}`);
  }
}

function validateMetricBands(value: unknown, errors: ValidationIssue[]): void {
  if (!isRecord(value)) {
    errors.push({ code: 'invalid_metric_band', message: 'metricBands must be an object' });
    return;
  }
  for (const [metric, bands] of Object.entries(value)) {
    if (!metric.endsWith('_percent') || !ALLOWED_METRICS.has(metric)) {
      errors.push({
        code: 'invalid_metric_band',
        message: `metricBands may only reference known percent metrics: ${metric}`,
      });
      continue;
    }
    if (!Array.isArray(bands)) {
      errors.push({
        code: 'invalid_metric_band',
        message: `metricBands.${metric} must be an array`,
      });
      continue;
    }
    let previous = -Infinity;
    for (const band of bands as MetricBand[]) {
      if (
        !isRecord(band) ||
        typeof band.id !== 'string' ||
        !Number.isFinite(band.max) ||
        band.max < previous ||
        band.max > 100
      ) {
        errors.push({ code: 'invalid_metric_band', message: `Invalid band in ${metric}` });
        break;
      }
      previous = band.max;
    }
  }
}

function validateElements(
  value: unknown,
  errors: ValidationIssue[],
  fileSet: ReadonlySet<string>,
): void {
  if (!Array.isArray(value)) {
    errors.push({ code: 'invalid_element', message: 'elements must be an array' });
    return;
  }
  const ids = new Set<string>();
  for (const element of value as NestElement[]) {
    if (!isRecord(element) || typeof element.id !== 'string' || typeof element.type !== 'string') {
      errors.push({ code: 'invalid_element', message: 'Element requires id and type' });
      continue;
    }
    if (ids.has(element.id))
      errors.push({ code: 'invalid_element', message: `Duplicate element id: ${element.id}` });
    ids.add(element.id);
    if (!ALLOWED_ELEMENT_TYPES.has(element.type)) {
      errors.push({
        code: 'invalid_element',
        message: `Unsupported element type: ${element.type}`,
      });
    }
    validateFrame(element.frame, errors, `element ${element.id}`);
    if (element.type === 'staticImage')
      validateReferencedPath(
        (element as { src?: unknown }).src,
        `element ${element.id}`,
        errors,
        fileSet,
      );
    if (
      'metric' in element &&
      typeof element.metric === 'string' &&
      !ALLOWED_METRICS.has(element.metric)
    ) {
      errors.push({ code: 'invalid_element', message: `Unknown metric: ${element.metric}` });
    }
    if (
      element.type === 'metricGauge' &&
      !ALLOWED_GAUGE_RENDERERS.has((element as { renderer?: string }).renderer ?? '')
    ) {
      errors.push({
        code: 'invalid_element',
        message: `Unsupported gauge renderer on ${element.id}`,
      });
    }
    if (element.type === 'variantImage') {
      const variant = element as { variants?: unknown; fallback?: unknown };
      if (!isRecord(variant.variants))
        errors.push({
          code: 'invalid_element',
          message: `variantImage ${element.id} requires variants`,
        });
      else
        Object.values(variant.variants).forEach((path) =>
          validateReferencedPath(path, `element ${element.id} variant`, errors, fileSet),
        );
      if (variant.fallback !== undefined)
        validateReferencedPath(variant.fallback, `element ${element.id} fallback`, errors, fileSet);
    }
  }
}

function validateReferencedPath(
  value: unknown,
  label: string,
  errors: ValidationIssue[],
  fileSet: ReadonlySet<string>,
): void {
  if (typeof value !== 'string') {
    errors.push({ code: 'missing_required_field', message: `${label} path is required` });
    return;
  }
  if (isRemoteUrl(value)) {
    errors.push({
      code: 'remote_url',
      message: `${label} must be a local package resource`,
      path: value,
    });
  } else if (!isSafePackagePath(value)) {
    errors.push({
      code: 'unsafe_path',
      message: `${label} must be a safe relative path`,
      path: value,
    });
  } else if (!fileSet.has(normalizePackagePath(value))) {
    errors.push({
      code: 'missing_required_file',
      message: `${label} references missing package file: ${value}`,
      path: value,
    });
  }
}

function validateFrame(value: unknown, errors: ValidationIssue[], label: string): void {
  if (
    !isRecord(value) ||
    !Number.isFinite(value.x) ||
    !Number.isFinite(value.y) ||
    !isPositiveFinite(value.width) ||
    !isPositiveFinite(value.height)
  ) {
    errors.push({
      code: 'invalid_layout',
      message: `${label} frame must contain finite x/y and positive width/height`,
    });
  }
}

function requireString(
  value: Record<string, unknown>,
  field: string,
  errors: ValidationIssue[],
): void {
  if (typeof value[field] !== 'string' || value[field].length === 0) {
    errors.push({ code: 'missing_required_field', message: `Package manifest requires ${field}` });
  }
}

function result<T>(
  errors: ValidationIssue[],
  warnings: ValidationIssue[],
  value?: T,
): ValidationResult<T> {
  return {
    ok: errors.length === 0,
    value: errors.length === 0 ? value : undefined,
    errors,
    warnings,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string');
}

function isPositiveFinite(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0;
}

function extension(path: string): string {
  const file = path.split('/').at(-1) ?? '';
  const parts = file.split('.');
  return parts.length > 1 ? (parts.at(-1) ?? '').toLowerCase() : '';
}

function basenameWithoutExtension(path: string): string {
  const file = path.split('/').at(-1) ?? path;
  return file.split('.')[0] ?? file;
}

function isImagePath(path: string): boolean {
  return ['png', 'webp', 'gif'].includes(extension(path));
}

function normalizePackagePath(path: string): string {
  return path.replaceAll('\\', '/');
}
