/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: 'var(--brand)', 2: 'var(--brand-2)', fg: 'var(--brand-fg)' },
        accent: { DEFAULT: 'var(--accent)', soft: 'var(--accent-soft)' },
        bg: 'var(--bg)', surface: { DEFAULT: 'var(--surface)', 2: 'var(--surface-2)' },
        line: { DEFAULT: 'var(--line)', 2: 'var(--line-2)' },
        fg: { DEFAULT: 'var(--fg)', 2: 'var(--fg-2)', 3: 'var(--fg-3)' },
        ok: { DEFAULT: 'var(--ok)', bg: 'var(--ok-bg)' },
        warn: { DEFAULT: 'var(--warn)', bg: 'var(--warn-bg)' },
        bad: { DEFAULT: 'var(--bad)', bg: 'var(--bad-bg)' },
        info: { DEFAULT: 'var(--info)', bg: 'var(--info-bg)' },
        neu: 'var(--neu-bg)',
        side: { DEFAULT: 'var(--sidebar)', fg: 'var(--sidebar-fg)', act: 'var(--sidebar-act)' },
        chart: { 1: 'var(--c1)', 2: 'var(--c2)', 3: 'var(--c3)', 4: 'var(--c4)', 5: 'var(--c5)', 6: 'var(--c6)' },
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      borderRadius: { DEFAULT: '8px', md: '8px', lg: '10px', xl: '12px' },
      boxShadow: { sm: 'var(--sh)', lg: 'var(--sh-2)' },
    },
  },
  plugins: [],
}
