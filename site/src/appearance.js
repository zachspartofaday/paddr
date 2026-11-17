// The Light / Dark switch for the window image.
//
// The markup already shows the capture that matches the system appearance
// through <picture>. This adds the other capture on top and fades it in and
// out. Both addresses are read from the markup, so the build can rename the
// files freely.

export function setUpAppearance() {
  const control = document.querySelector('.appearance');
  const frame = document.querySelector('.window__frame');
  const source = frame?.querySelector('source');
  const image = frame?.querySelector('img');
  if (!control || !source || !image) return;

  const addresses = {
    light: image.getAttribute('src'),
    dark: source.getAttribute('srcset')
  };
  const darkScheme = window.matchMedia('(prefers-color-scheme: dark)');
  const systemAppearance = () => (darkScheme.matches ? 'dark' : 'light');

  const other = document.createElement('img');
  other.className = 'window__other';
  other.alt = '';
  other.setAttribute('width', image.getAttribute('width'));
  other.setAttribute('height', image.getAttribute('height'));
  other.decoding = 'async';
  other.setAttribute('aria-hidden', 'true');
  frame.append(other);

  let selected = systemAppearance();
  let request = 0;

  function load() {
    const appearance = systemAppearance() === 'dark' ? 'light' : 'dark';
    if (other.dataset.appearance !== appearance) {
      other.dataset.appearance = appearance;
      other.src = addresses[appearance];
    }
    return other.decode().catch(() => {});
  }

  async function show() {
    control.querySelector(`input[value="${selected}"]`).checked = true;
    control.dataset.selected = selected;
    const current = ++request;
    if (selected === systemAppearance()) {
      frame.classList.remove('is-other');
      return;
    }
    await load();
    if (current === request) frame.classList.add('is-other');
  }

  control.addEventListener('change', (event) => {
    selected = event.target.value;
    show();
  });

  // Fetch the second capture when the switch is about to be used, not before.
  control.addEventListener('pointerenter', load, { once: true });
  control.addEventListener('focusin', load, { once: true });

  // If the system appearance changes, start again from it.
  darkScheme.addEventListener('change', () => {
    selected = systemAppearance();
    frame.classList.remove('is-other');
    show();
  });

  control.hidden = false;
  show();
}
