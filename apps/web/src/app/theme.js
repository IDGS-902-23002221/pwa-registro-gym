import { createTheme } from '@mui/material/styles'
import { color, gradient, shape, elevation, motion, typography } from './tokens'

// El theme se arma sólo con los tokens (app/tokens.js): aquí no hay colores
// sueltos. Identidad fría violeta→cian con degradados, formas por escala y
// hover/foco suaves. Mobile-first: toques cómodos y transiciones baratas.

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: color.brand.main,
      light: color.brand.light,
      dark: color.brand.dark,
      contrastText: color.brand.contrast,
    },
    secondary: {
      main: color.cool.main,
      dark: color.cool.dark,
      contrastText: color.cool.contrast,
    },
    success: { main: color.success.main, contrastText: color.success.contrast },
    warning: { main: color.warning.main, contrastText: color.warning.contrast },
    error: { main: color.danger.main, dark: color.danger.dark, contrastText: color.danger.contrast },
    info: { main: color.info.main, contrastText: color.info.contrast },
    background: { default: color.bg.base, paper: color.bg.panel },
    divider: color.line,
    text: {
      primary: color.text.primary,
      secondary: color.text.secondary,
      disabled: color.text.muted,
    },
  },
  shape: { borderRadius: shape.radius.md },
  typography: {
    fontFamily: typography.family,
    h1: { fontWeight: typography.weights.black, letterSpacing: '-0.03em' },
    h2: { fontWeight: typography.weights.black, letterSpacing: '-0.03em' },
    h3: { fontWeight: typography.weights.bold, letterSpacing: '-0.02em' },
    h4: { fontWeight: typography.weights.bold, letterSpacing: '-0.02em' },
    h5: { fontWeight: typography.weights.bold, letterSpacing: '-0.01em' },
    h6: { fontWeight: typography.weights.semibold },
    button: { textTransform: 'none', fontWeight: typography.weights.bold, letterSpacing: '0.01em' },
    subtitle2: { letterSpacing: '0.02em' },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          minHeight: '100dvh',
          // Brillos fríos tenues: profundidad sin degradado pesado.
          backgroundImage: [
            'radial-gradient(900px 520px at 100% -10%, rgba(139,92,246,0.16), transparent 60%)',
            'radial-gradient(760px 520px at -10% 110%, rgba(34,211,238,0.10), transparent 60%)',
          ].join(','),
          backgroundAttachment: 'fixed',
        },
      },
    },
    MuiAppBar: {
      defaultProps: { elevation: 0, color: 'transparent' },
      styleOverrides: {
        root: {
          backgroundImage: gradient.header,
          borderBottom: `1px solid ${color.lineStrong}`,
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: gradient.surface,
          border: `1px solid ${color.line}`,
          borderRadius: shape.radius.lg,
        },
      },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: {
          borderRadius: shape.radius.sm,
          minHeight: 42,
          paddingInline: 18,
          transition: `transform ${motion.fast}, box-shadow ${motion.fast}`,
        },
        containedPrimary: {
          backgroundImage: gradient.brand,
          color: '#0b0716',
          '&:hover': { backgroundImage: gradient.brand, transform: motion.lift, boxShadow: elevation.glow },
        },
        outlinedPrimary: {
          borderColor: color.brand.main,
          '&:hover': { borderColor: color.brand.light, backgroundColor: color.brand.soft },
        },
      },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          borderRadius: shape.radius.sm,
          backgroundColor: color.bg.sunken,
          '& fieldset': { borderColor: color.line },
          '&:hover fieldset': { borderColor: color.lineStrong },
          '&.Mui-focused fieldset': { borderColor: color.brand.main },
        },
      },
    },
    MuiTableContainer: {
      styleOverrides: {
        root: {
          border: `1px solid ${color.line}`,
          borderRadius: shape.radius.lg,
          overflow: 'hidden',
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: { borderBottom: `1px solid ${color.line}` },
        head: {
          backgroundImage: 'none',
          backgroundColor: color.bg.sunken,
          color: color.text.secondary,
          fontSize: 11,
          fontWeight: typography.weights.bold,
          textTransform: 'uppercase',
          letterSpacing: '0.08em',
          borderBottom: `1px solid ${color.lineStrong}`,
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: { '&:hover': { backgroundColor: color.brand.soft } },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: { borderRadius: shape.radius.pill, fontWeight: typography.weights.semibold },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          border: `1px solid ${color.lineStrong}`,
          borderRadius: shape.radius.lg,
          boxShadow: elevation.pop,
          backgroundImage: gradient.surface,
        },
      },
    },
    MuiIconButton: {
      styleOverrides: {
        root: {
          borderRadius: shape.radius.sm,
          transition: `background-color ${motion.fast}`,
          '&:hover': { backgroundColor: color.brand.soft },
        },
      },
    },
    MuiAlert: {
      styleOverrides: {
        root: { borderRadius: shape.radius.sm, border: `1px solid ${color.line}` },
      },
    },
    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          backgroundColor: color.bg.raised,
          border: `1px solid ${color.line}`,
          borderRadius: shape.radius.xs,
          fontWeight: typography.weights.medium,
        },
      },
    },
  },
})

export default theme
