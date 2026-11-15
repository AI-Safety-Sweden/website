import { defineConfig } from "vite";

export default {
  vite: defineConfig({}),
  headTagsTemplate(context) {
    return `
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600&display=swap" />
<link rel="stylesheet" href="/style.css" />
<script defer src="/remove-netlify-badge.js"></script>
<meta name="generator" content="elm-pages v${context.cliVersion}" />
`;
  },
  preloadTagForFile(file) {
    // add preload directives for JS assets and font assets, etc., skip for CSS files
    return !file.endsWith(".css");
  },
};
