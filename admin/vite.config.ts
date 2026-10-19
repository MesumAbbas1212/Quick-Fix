import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        // Split the single ~838 kB vendor chunk so no one chunk trips the
        // 500 kB size warning. Firebase is split per product (firestore is
        // the large one), React runtime separately, everything else together.
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('/@firebase/firestore') || id.includes('/firebase/firestore')) {
            return 'firebase-firestore'
          }
          if (id.includes('/@firebase/auth') || id.includes('/firebase/auth')) {
            return 'firebase-auth'
          }
          if (id.includes('/@firebase/') || id.includes('/firebase/')) {
            return 'firebase-core'
          }
          if (
            id.includes('/react-dom/') ||
            id.includes('/react/') ||
            id.includes('/scheduler/') ||
            id.includes('/react-router') ||
            id.includes('/@remix-run/')
          ) {
            return 'react-vendor'
          }
          return 'vendor'
        },
      },
    },
  },
})
