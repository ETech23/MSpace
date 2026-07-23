import type { Config } from "tailwindcss";
import forms from "@tailwindcss/forms";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          green: "#0F7A4A",
          gold: "#C9B037",
          ink: "#14211B",
          soft: "#F3F8F5"
        }
      },
      boxShadow: {
        glass: "0 24px 80px rgba(15, 122, 74, 0.16)"
      }
    }
  },
  plugins: [forms]
};

export default config;
