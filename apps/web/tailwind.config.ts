import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-sans)"],
        serif: ["var(--font-serif)"],
        mono: ["var(--font-mono)"],
      },
      screens: {
        xs: "440px",
        "toast-mobile": "600px",
      },
      fontSize: {
        xxs: ["0.625rem", { lineHeight: "1rem" }], // 10px
      },
      borderRadius: {
        lg: "var(--radius)",
        xxl: "var(--radius-2xl)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        surface: {
          DEFAULT: "hsl(var(--surface))",
          elevated: "hsl(var(--surface-elevated))",
          hover: "hsl(var(--surface-hover))",
          muted: "hsl(var(--surface-muted))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
          blue: "hsl(var(--primary-blue))",
          /** Color palette 50–950 (matching screenshots) */
          50: "var(--primary-50)",
          100: "var(--primary-100)",
          200: "var(--primary-200)",
          300: "var(--primary-300)",
          400: "var(--primary-400)",
          500: "var(--primary-500)",
          600: "var(--primary-600)",
          700: "var(--primary-700)",
          800: "var(--primary-800)",
          900: "var(--primary-900)",
          950: "var(--primary-950)",
          /** New design system: gradient endpoints, for from-primary-start to-primary-end etc. */
          start: "var(--primary-start)",
          end: "var(--primary-end)",
        },
        tag: {
          DEFAULT: "hsl(var(--primary-blue-text))",
          "red-text": "hsl(var(--tag-red-text))",
          "red-bg": "hsl(var(--tag-red-bg))",
          "orange-bg": "hsl(var(--tag-orange-bg))",
          "orange-text": "hsl(var(--tag-orange-text))",
          "green-bg": "hsl(var(--tag-green-bg))",
          "green-text": "hsl(var(--tag-green-text))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
          /** Secondary primary color (700 #B9580A), for CTA/tags etc. */
          brand: "var(--accent-brand)",
          /** Secondary color palette 50–950 (matching screenshots) */
          50: "var(--accent-50)",
          100: "var(--accent-100)",
          200: "var(--accent-200)",
          300: "var(--accent-300)",
          400: "var(--accent-400)",
          500: "var(--accent-500)",
          600: "var(--accent-600)",
          700: "var(--accent-700)",
          800: "var(--accent-800)",
          900: "var(--accent-900)",
          950: "var(--accent-950)",
        },
        /** Secondary background gradient endpoints */
        "accent-bg": {
          start: "var(--accent-bg-start)",
          end: "var(--accent-bg-end)",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        success: {
          DEFAULT: "hsl(var(--success))",
          foreground: "hsl(var(--success-foreground))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        chart: {
          "1": "hsl(var(--chart-1))",
          "2": "hsl(var(--chart-2))",
          "3": "hsl(var(--chart-3))",
          "4": "hsl(var(--chart-4))",
          "5": "hsl(var(--chart-5))",
        },
        sidebar: {
          DEFAULT: "hsl(var(--sidebar-background))",
          foreground: "hsl(var(--sidebar-foreground))",
          primary: "hsl(var(--sidebar-primary))",
          "primary-foreground": "hsl(var(--sidebar-primary-foreground))",
          accent: "hsl(var(--sidebar-accent))",
          "accent-foreground": "hsl(var(--sidebar-accent-foreground))",
          border: "hsl(var(--sidebar-border))",
          ring: "hsl(var(--sidebar-ring))",
          active: "hsl(var(--sidebar-active))",
          "active-foreground": "hsl(var(--sidebar-active-foreground))",
          hover: "hsl(var(--sidebar-hover))",
          "hover-foreground": "hsl(var(--sidebar-hover-foreground))",
        },
        theme: {
          "vivid-orange": "hsl(var(--theme-vivid-orange))",
          "electric-orange": "hsl(var(--theme-electric-orange))",
          amber: "hsl(var(--theme-amber))",
          "yellow-accent": "hsl(var(--theme-yellow-accent))",
        },
        "dynamic-theme": {
          start: "hsl(var(--dynamic-theme-start))",
          main: "hsl(var(--dynamic-theme-main))",
          end: "hsl(var(--dynamic-theme-end))",
        },
        /* Marketing / Brand Colors */
        deepwater: "var(--color-deepwater)",
        flowlight: "var(--color-flowlight)",
        gold: "var(--color-gold)",
        surfaceBlue: "var(--color-surfaceBlue)",
        "foreground-secondary": "var(--color-foreground-secondary)",
        "foreground-muted": "var(--color-foreground-muted)",
        "foreground-primary": "var(--color-foreground-primary)",
        "background-card": "var(--color-background-card)",
        "border-primary": "var(--color-border-primary)",
        "border-secondary": "var(--color-border-secondary)",
      },
      keyframes: {
        "accordion-down": {
          from: {
            height: "0",
          },
          to: {
            height: "var(--radix-accordion-content-height)",
          },
        },
        "accordion-up": {
          from: {
            height: "var(--radix-accordion-content-height)",
          },
          to: {
            height: "0",
          },
        },
        blob: {
          "0%": {
            transform: "translate(0px, 0px) scale(1)",
          },
          "33%": {
            transform: "translate(30px, -50px) scale(1.1)",
          },
          "66%": {
            transform: "translate(-20px, 20px) scale(0.9)",
          },
          "100%": {
            transform: "translate(0px, 0px) scale(1)",
          },
        },
        "spin-slow": {
          "0%": {
            transform: "rotate(0deg)",
          },
          "100%": {
            transform: "rotate(360deg)",
          },
        },
        "pulse-slow": {
          "0%, 100%": {
            opacity: "1",
          },
          "50%": {
            opacity: "0.8",
          },
        },
        float: {
          "0%, 100%": {
            transform: "translateY(0px)",
          },
          "50%": {
            transform: "translateY(-10px)",
          },
        },
        flow: {
          "0%": {
            backgroundPosition: "0% 50%",
          },
          "100%": {
            backgroundPosition: "200% 50%",
          },
        },
        shimmer: {
          "0%": {
            backgroundPosition: "-200% 0",
          },
          "100%": {
            backgroundPosition: "200% 0",
          },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        blob: "blob 7s infinite",
        "spin-slow": "spin-slow 20s linear infinite",
        "pulse-slow": "pulse-slow 4s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        float: "float 3s ease-in-out infinite",
        flow: "flow 20s ease-in-out infinite",
        shimmer: "shimmer 3s linear infinite",
      },
    },
  },
  plugins: [require("tailwindcss-animate"), require("@tailwindcss/typography")],
};
export default config;
