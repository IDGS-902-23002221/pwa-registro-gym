// app/tokens.js
//
// Base de diseño estable: color, degradados, formas, elevación y movimiento en
// un solo lugar. El theme (app/theme.js) se arma a partir de esto, así que
// cambiar la identidad es editar este archivo y nada más.
//
// Dirección: paleta FRÍA (violeta → cian) con degradados, sobre fondos
// índigo-negro. Pensada mobile-first: buen contraste, toques grandes, hover y
// foco suaves (sólo transform/opacity/box-shadow, que los pinta la GPU: no
// disparan reflow y no frenan el render).

export const color = {
  // Neutros fríos con tinte índigo, por capas (base < panel < elevado).
  bg: {
    base: '#0a0912',
    panel: '#12101f',
    raised: '#1a1729',
    sunken: '#070611',
  },
  line: 'rgba(255, 255, 255, 0.08)',
  lineStrong: 'rgba(255, 255, 255, 0.16)',
  text: {
    primary: '#eceaf6',
    secondary: '#a9a3c4',
    muted: '#6f6a8a',
    inverse: '#0e0720',
  },
  // Violeta: acento principal.
  brand: {
    main: '#8b5cf6',
    light: '#a78bfa',
    dark: '#6d28d9',
    soft: 'rgba(139, 92, 246, 0.16)',
    contrast: '#150a2e',
  },
  // Cian: acento frío secundario.
  cool: {
    main: '#22d3ee',
    dark: '#0e7490',
    soft: 'rgba(34, 211, 238, 0.16)',
    contrast: '#062a31',
  },
  // Éxito en teal (frío, coherente con la paleta).
  success: { main: '#2dd4bf', soft: 'rgba(45, 212, 191, 0.16)', contrast: '#042a25' },
  // Aviso/vencido: rosa frío, no ámbar cálido.
  warning: { main: '#fb7185', soft: 'rgba(251, 113, 133, 0.16)', contrast: '#2a0812' },
  danger: { main: '#f43f5e', dark: '#9f1239', soft: 'rgba(244, 63, 94, 0.16)', contrast: '#2a0710' },
  info: { main: '#60a5fa', soft: 'rgba(96, 165, 250, 0.16)', contrast: '#08203d' },
  estado: {
    activo: '#2dd4bf',
    vencido: '#fb7185',
    pausado: '#94a3b8',
  },
}

// Degradados: la firma visual. Se usan en marca, cabecera y superficies.
export const gradient = {
  brand: 'linear-gradient(135deg, #8b5cf6 0%, #6366f1 45%, #22d3ee 100%)',
  brandSoft: 'linear-gradient(135deg, rgba(139,92,246,0.22), rgba(34,211,238,0.10))',
  header: 'linear-gradient(120deg, #171226 0%, #241b3d 55%, #14303d 100%)',
  surface: 'linear-gradient(160deg, rgba(139,92,246,0.10), rgba(34,211,238,0.04))',
}

export const shape = {
  radius: {
    xs: 6,
    sm: 10,
    md: 14,
    lg: 20,
    pill: 999,
  },
  border: {
    hair: '1px',
    bold: '2px',
  },
}

export const elevation = {
  card: '0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.4)',
  pop: '0 16px 48px rgba(0,0,0,0.55)',
  glow: '0 10px 30px rgba(139, 92, 246, 0.35)',
  focus: '0 0 0 3px rgba(139, 92, 246, 0.30)',
}

// Movimiento: corto y sólo sobre transform/opacity (barato de pintar).
export const motion = {
  fast: '120ms ease',
  base: '180ms ease',
  lift: 'translateY(-2px)',
}

export const typography = {
  // Sin fuentes externas: el PWA debe abrir sin red (ADR-007).
  family: [
    '"Inter"',
    'system-ui',
    '-apple-system',
    '"Segoe UI"',
    'Roboto',
    'Helvetica',
    'Arial',
    'sans-serif',
  ].join(','),
  weights: { regular: 400, medium: 500, semibold: 600, bold: 700, black: 800 },
}

export const tokens = { color, gradient, shape, elevation, motion, typography }

export default tokens
