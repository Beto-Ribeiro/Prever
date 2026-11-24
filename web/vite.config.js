import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2022',
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('node_modules')) return undefined
          if (id.includes('@supabase/')) return 'vendor-supabase'
          if (id.includes('@vis.gl/react-google-maps')) return 'vendor-maps'
          if (id.includes('firebase/') || id.includes('@firebase/')) return 'vendor-firebase'
          if (id.includes('html2canvas')) return 'vendor-canvas'
          if (id.includes('jspdf') || id.includes('dompurify')) return 'vendor-jspdf'
          return undefined
        },
      },
    },
  },
})
