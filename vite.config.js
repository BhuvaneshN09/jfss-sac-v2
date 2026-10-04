import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const DEV_PROXY_ORIGIN = 'https://www.johnfrasersac.com'

const supabaseProxy = {
  '/api/sf/go': {
    target: DEV_PROXY_ORIGIN,
    changeOrigin: true,
  },
  '/api/x': {
    target: DEV_PROXY_ORIGIN,
    changeOrigin: true,
  },
}

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: supabaseProxy,
  },
  preview: {
    proxy: supabaseProxy,
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.js'],
  },
})
