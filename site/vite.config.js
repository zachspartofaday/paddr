import { defineConfig } from 'vite';

// The built page has to open from disk as well as from a web server. Browsers
// refuse module scripts and `crossorigin` requests on file: addresses, so the
// script is built as one classic file and the tags are rewritten to match.
function classicTags() {
  return {
    name: 'paddr-classic-tags',
    apply: 'build',
    transformIndexHtml: {
      order: 'post',
      handler(html) {
        return html
          .replace(/<script type="module" crossorigin src=/g, '<script defer src=')
          .replace(/(<link\b[^>]*?) crossorigin(?=[\s>])/g, '$1');
      }
    }
  };
}

export default defineConfig({
  // Relative addresses, so dist/ works from any folder or sub-path.
  base: './',
  plugins: [classicTags()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // Keep images as files instead of inlining them into the page.
    assetsInlineLimit: 0,
    modulePreload: false,
    // One stylesheet, linked from the page, so the page is styled without the script.
    cssCodeSplit: false,
    // Ship the licence notices of the code bundled into the script.
    license: { fileName: 'third-party-licenses.md' },
    rolldownOptions: {
      output: { format: 'iife' }
    }
  }
});
