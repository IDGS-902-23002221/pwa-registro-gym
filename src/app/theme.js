import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#9c27b0',
      light: '#ce93d8',
      dark: '#6a1b9a',
      contrastText: '#ffffff',
    },
    secondary: {
      main: '#e040fb',
      contrastText: '#000000',
    },
    background: {
      default: '#0d0d0d',
      paper: '#1a1a1a',
    },
    text: {
      primary: '#f5f5f5',
      secondary: '#b39ddb',
    },
  },
  components: {
    MuiAppBar: {
      styleOverrides: {
        root: {
          backgroundColor: '#1a1a1a',
          borderBottom: '2px solid #9c27b0',
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          border: '1px solid rgba(156, 39, 176, 0.35)',
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 600,
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        head: {
          backgroundColor: '#4a148c',
          color: '#ffffff',
          fontWeight: 700,
        },
      },
    },
    MuiTextField: {
      defaultProps: {
        variant: 'outlined',
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          border: '1px solid rgba(156, 39, 176, 0.5)',
        },
      },
    },
  },
});

export default theme;