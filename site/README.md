# Paddr site

The one-page site for Paddr. It is built with [Vite](https://vite.dev) and uses
[Motion](https://motion.dev) for the animations. The result is static files: no
server code, no analytics, and no requests to other hosts.

## Build

Node 20.19 or later, or 22.12 or later.

```sh
cd site
npm ci
npm run build
```

The site is written to `site/dist/`. That folder is not committed.

`npm run dev` serves the page with live reload while editing. `npm run preview`
serves the built `dist/` folder.

## Hosting

Serve the contents of `dist/` as static files. Addresses inside the page are
relative, so it works from a domain root or from a sub-path, and `index.html`
also opens straight from disk.

File names under `dist/assets/` include a content hash, so they can be cached
for a long time. `index.html` should not be cached for long.

`dist/third-party-licenses.md` lists the licences of the code bundled into the
script. Keep it with the deployed files.

## Layout

- `index.html` holds all of the page text.
- `src/styles.css` holds the styles, including the dark appearance and the
  reduced-motion rules.
- `src/main.js` starts the scripts in `src/`: the Light/Dark switch for the
  window image, the drawings beside each mapping, and the install steps.
- `assets/` holds the icons and the two window images.

The page reads correctly with scripts turned off; the scripts only add motion
and the appearance switch.
