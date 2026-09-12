/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Premium Black Palette
        black: {
          950: "#0a0a0a", // Deep Black
          900: "#121212", // Near Black
          850: "#1a1a1a", // Dark Charcoal
          800: "#212121", // Charcoal
          700: "#2a2a2a",
          600: "#333333",
          500: "#3d3d3d",
        },
        // Premium Orange Accent
        orange: {
          50: "#fef9f3",
          100: "#fed7aa",
          200: "#fdba74",
          300: "#fb923c",
          400: "#f97316", // Primary Orange
          500: "#ea580c", // Deep Orange
          600: "#c2410c",
        },
        // Supporting Colors
        gray: {
          50: "#f9fafb",
          100: "#f3f4f6",
          200: "#e5e7eb",
          300: "#d1d5db",
          400: "#9ca3af",
          500: "#6b7280",
          600: "#4b5563",
          700: "#374151",
          800: "#1f2937",
          900: "#111827",
        },
        // Semantic Colors
        success: "#10b981",
        warning: "#f59e0b",
        danger: "#ef4444",
        info: "#3b82f6",
      },
      fontSize: {
        xs: ["12px", "16px"],
        sm: ["14px", "20px"],
        base: ["16px", "24px"],
        lg: ["18px", "28px"],
        xl: ["20px", "28px"],
        "2xl": ["24px", "32px"],
        "3xl": ["30px", "36px"],
        "4xl": ["36px", "44px"],
      },
      spacing: {
        xs: "4px",
        sm: "8px",
        md: "12px",
        lg: "16px",
        xl: "24px",
        "2xl": "32px",
        "3xl": "48px",
        "4xl": "64px",
      },
      borderRadius: {
        xs: "8px",
        sm: "10px",
        base: "12px",
        lg: "14px",
        xl: "16px",
        "2xl": "20px",
        "3xl": "24px",
      },
      boxShadow: {
        xs: "0 1px 2px 0 rgba(0, 0, 0, 0.05)",
        sm: "0 1px 2px 0 rgba(0, 0, 0, 0.1)",
        base: "0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)",
        md: "0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)",
        lg: "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)",
        xl: "0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)",
      },
      backgroundImage: {
        "gradient-orange": "linear-gradient(135deg, #f97316 0%, #ea580c 100%)",
        "gradient-dark": "linear-gradient(180deg, #121212 0%, #0a0a0a 100%)",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
  ],
  darkMode: "class",
}
