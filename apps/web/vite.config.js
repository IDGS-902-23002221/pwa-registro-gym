import react, { reactCompilerPreset } from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  // Escucha en toda la red local para probar desde el celular (misma Wi-Fi):
  // http://<tu-ip-lan>:5173
  server: {
    host: true,
  },
  plugins: [
    react(),
     VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'Registro Gym',
        short_name: 'Gym',
        description: 'Registro de socios y membresias',
        theme_color: '#12101f',
        background_color: '#0a0912',
        lang: 'es',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
    }),
  ],
})
