import type { NestRenderModel, RenderElement } from '@codexpet/renderer';

interface Props {
  model: NestRenderModel;
  selectedNestId: string;
  slotContent?: Record<string, string>;
}

export function NestOverlayView({ model, selectedNestId, slotContent = {} }: Props) {
  return (
    <div
      data-testid="nest-render-model"
      style={{
        position: 'relative',
        width: model.canvas.width,
        height: model.canvas.height,
        color: '#fff',
        fontFamily: 'system-ui, sans-serif',
        transform: 'scale(0.9)',
        transformOrigin: 'center',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 18,
          background: 'linear-gradient(135deg, rgba(10,18,34,0.9), rgba(46,71,115,0.78))',
          boxShadow: '0 10px 30px rgba(0,0,0,0.35)',
        }}
      />

      {model.layers.map((layer) => (
        <img
          key={layer.id}
          alt=""
          src={layer.resolvedSrc ?? undefined}
          data-layer-id={layer.id}
          style={{
            position: 'absolute',
            left: layer.frame.x,
            top: layer.frame.y,
            width: layer.frame.width,
            height: layer.frame.height,
            objectFit: 'cover',
            opacity: 0.24,
            borderRadius: 14,
            background: 'rgba(255,255,255,0.12)',
          }}
        />
      ))}

      {model.widgetSlots.map((slot) => (
        <div
          key={slot.id}
          data-testid={`widget-slot-${slot.id}`}
          style={{
            position: 'absolute',
            left: slot.x,
            top: slot.y,
            width: slot.width,
            height: slot.height,
            border: '1px solid rgba(255,255,255,0.35)',
            borderRadius: 8,
            background: 'rgba(0,0,0,0.25)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 10,
            fontWeight: 700,
            letterSpacing: 0.5,
            textTransform: 'uppercase',
          }}
        >
          {slotContent[slot.id] ?? slot.id}
        </div>
      ))}

      {model.elements.map((element) => (
        <RenderElementView key={element.id} element={element} />
      ))}

      <div
        style={{
          position: 'absolute',
          left: 10,
          bottom: 8,
          fontSize: 10,
          opacity: 0.75,
          background: 'rgba(0,0,0,0.35)',
          padding: '2px 6px',
          borderRadius: 6,
        }}
      >
        {selectedNestId}
      </div>
    </div>
  );
}

function RenderElementView({ element }: { element: RenderElement }) {
  if (element.type === 'staticImage' || element.type === 'variantImage') {
    return (
      <img
        alt=""
        src={element.resolvedSrc ?? undefined}
        data-element-id={element.id}
        style={{
          position: 'absolute',
          left: element.frame.x,
          top: element.frame.y,
          width: element.frame.width,
          height: element.frame.height,
          borderRadius: 10,
          background: 'rgba(255,255,255,0.18)',
          border: '1px solid rgba(255,255,255,0.18)',
        }}
      />
    );
  }

  if (element.type === 'metricText') {
    return (
      <div
        data-testid={`metric-text-${element.id}`}
        style={{
          position: 'absolute',
          left: element.frame.x,
          top: element.frame.y,
          width: element.frame.width,
          height: element.frame.height,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: typeof element.style?.fontSize === 'number' ? element.style.fontSize : 12,
          fontWeight: element.style?.fontWeight === 'bold' ? 800 : 600,
          color: typeof element.style?.color === 'string' ? element.style.color : '#ffffff',
          background: 'rgba(0,0,0,0.28)',
          borderRadius: 6,
        }}
      >
        {element.text}
      </div>
    );
  }

  return (
    <div
      data-testid={`metric-gauge-${element.id}`}
      style={{
        position: 'absolute',
        left: element.frame.x,
        top: element.frame.y,
        width: element.frame.width,
        height: element.frame.height,
        borderRadius: element.renderer === 'linearBar' ? 999 : '50%',
        overflow: 'hidden',
        border: '1px solid rgba(255,255,255,0.35)',
        background:
          typeof element.style?.trackColor === 'string'
            ? element.style.trackColor
            : 'rgba(0,0,0,0.35)',
        opacity: element.unavailable ? 0.55 : 1,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 0,
          bottom: 0,
          width: element.renderer === 'linearBar' ? `${Math.round(element.value * 100)}%` : '100%',
          height: element.renderer === 'linearBar' ? '100%' : `${Math.round(element.value * 100)}%`,
          background:
            typeof element.style?.fillColor === 'string' ? element.style.fillColor : '#64d2ff',
          transition: 'height 200ms ease, width 200ms ease',
        }}
      />
    </div>
  );
}
