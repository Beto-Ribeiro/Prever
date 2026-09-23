/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['K2D', 'system-ui', 'sans-serif'],
      },
      colors: {
        'bg-main': 'rgb(var(--bg-main) / <alpha-value>)',
        'bg-sidebar': 'rgb(var(--bg-sidebar) / <alpha-value>)',
        'bg-surface': 'rgb(var(--bg-surface) / <alpha-value>)',
        'text-main': 'rgb(var(--text-main) / <alpha-value>)',
        'text-on-dark': 'rgb(var(--text-on-dark) / <alpha-value>)',
        'action-inactive': 'rgb(var(--action-inactive) / <alpha-value>)',
        'action-hover': 'rgb(var(--action-hover) / <alpha-value>)',
        'status-critical': 'rgb(var(--status-critical) / <alpha-value>)',
        'status-severe': 'rgb(var(--status-severe) / <alpha-value>)',
        'status-regular': 'rgb(var(--status-regular) / <alpha-value>)',
        'status-success': 'rgb(var(--status-success) / <alpha-value>)',
        'status-critical-bg': 'rgb(var(--status-critical-bg) / <alpha-value>)',
        'status-severe-bg': 'rgb(var(--status-severe-bg) / <alpha-value>)',
        'status-regular-bg': 'rgb(var(--status-regular-bg) / <alpha-value>)',
        'status-success-bg': 'rgb(var(--status-success-bg) / <alpha-value>)',
        'border-soft': 'rgb(var(--border-soft) / <alpha-value>)',
        'sidebar-active': 'rgb(var(--sidebar-active) / <alpha-value>)',
      },
      fontSize: {
        'title-large': ['2rem', { fontWeight: '700', lineHeight: '1.2' }],
        'title-medium': ['1.5rem', { fontWeight: '700', lineHeight: '1.3' }],
        'card-title': ['1.125rem', { fontWeight: '600', lineHeight: '1.4' }],
        body: ['0.875rem', { fontWeight: '400', lineHeight: '1.6' }],
        label: ['0.75rem', { fontWeight: '700', lineHeight: '1.4', letterSpacing: '0.05em' }],
      },
      boxShadow: {
        card: '0 2px 12px 0 rgba(9,22,46,0.07)',
        'card-hover': '0 6px 24px 0 rgba(9,22,46,0.13)',
        sidebar: '4px 0 24px 0 rgba(9,22,46,0.18)',
        modal: '0 16px 64px 0 rgba(9,22,46,0.22)',
      },
      borderRadius: {
        card: '12px',
        badge: '999px',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.25s cubic-bezier(.16,1,.3,1)',
        pulse2: 'pulse2 2s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: { from: { opacity: 0 }, to: { opacity: 1 } },
        slideUp: { from: { opacity: 0, transform: 'translateY(16px)' }, to: { opacity: 1, transform: 'translateY(0)' } },
        pulse2: { '0%,100%': { opacity: 1 }, '50%': { opacity: 0.5 } },
      },
    },
  },
  plugins: [],
}