// Mocha Neon — Insomnia theme
// Source of truth for hex: docs/mocha-neon-palette.md
// Forked from Dracula PRO; all accents bumped to Mocha Neon neon variant.
module.exports = {
  name: "mocha-neon",
  displayName: "Mocha Neon",
  theme: {
    background: {
      default: "#1E1E2E",
      success: "#50FA7B",
      notice: "#FF8C42",
      warning: "#FFD700",
      danger: "#FF6B9D",
      surprise: "#B347FF",
      info: "#8BE9FD",
    },
    foreground: {
      default: "#F0F0FF",
      success: "#1E1E2E",
      notice: "#1E1E2E",
      warning: "#1E1E2E",
      danger: "#1E1E2E",
      surprise: "#F0F0FF",
      info: "#1E1E2E",
    },
    highlight: {
      default: "rgba(179, 71, 255, 0.8)",
      xxs: "rgba(179, 71, 255, 0.1)",
      xs: "rgba(179, 71, 255, 0.1)",
      sm: "rgba(179, 71, 255, 0.2)",
      md: "rgba(179, 71, 255, 0.4)",
      lg: "rgba(179, 71, 255, 0.6)",
      xl: "rgba(179, 71, 255, 0.8)",
    },
    styles: {
      appHeader: {
        background: {
          default: "#1E1E2E",
        },
      },
      sidebar: {
        background: {
          default: "#181825",
        },
      },
      dialog: {
        background: {
          default: "#2A2A3A",
        },
      },
      paneHeader: {
        background: {
          success: "#50FA7B",
          notice: "#FF8C42",
          warning: "#FFD700",
          danger: "#FF6B9D",
          surprise: "#B347FF",
          info: "#8BE9FD",
        },
      },
      transparentOverlay: {
        background: {
          default: "rgba(42, 42, 58, 0.8)",
        },
      },
    },
  },
};
