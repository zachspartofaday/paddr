// The small drawings in the Mappings rows. Each one acts out its row once:
// a touch moves and the pointer follows, a zone lights while it is touched,
// a rear button is held and released.
//
// A drawing plays once when its row scrolls into view, and again when the
// row is hovered or tapped. It always ends in the pose it started from, which
// is the pose drawn in the markup, so the page looks the same before the
// script runs, after it has played, and with motion turned off.
//
// The sequences run on the browser's own animation engine through Motion's
// small `animateSequence`, so the values are plain CSS: `translate`, `scale`,
// `rotate` and `opacity`. Distances are in the drawing's own 64-unit grid.

import { hover, inView } from 'motion';
import { animateSequence } from 'motion/mini';

const standard = [0.4, 0, 0.2, 1];
const at = (x, y) => `${x}px ${y}px`;
const appear = { opacity: [0, 1], scale: [0.5, 1] };
const vanish = { opacity: [1, 0], scale: [1, 0.5] };

// Each entry returns a Motion sequence: [element, keyframes, timing] segments
// placed on one timeline with `at`, in seconds.
const sequences = {
  pointer(drawing) {
    const move = drawing.querySelector('.pv-move');
    const touch = drawing.querySelector('.pv-touch');
    const path = glide([[0, 0], [-10, 6], [-5, -9], [8, -7], [7, 6], [0, 0]]);
    return [
      [touch, appear, { duration: 0.18 }],
      [move, { translate: path }, { duration: 2, at: 0.16, ease: 'linear' }],
      [touch, vanish, { duration: 0.2, at: 2.2 }]
    ];
  },

  scroll(drawing) {
    const touch = drawing.querySelector('.pv-touch');
    const lines = drawing.querySelector('.pv-lines');
    return [
      // Swipe up: the content follows.
      [touch, appear, { duration: 0.16 }],
      [touch, { translate: [at(0, 0), at(0, -20)] }, { duration: 0.55, at: 0.2 }],
      [lines, { translate: [at(0, 0), at(0, -18)] }, { duration: 0.55, at: 0.2 }],
      [touch, { opacity: [1, 0] }, { duration: 0.14, at: 0.8 }],
      // Swipe left.
      [touch, { translate: [at(0, -20), at(6, -12)] }, { duration: 0.01, at: 0.96 }],
      [touch, { opacity: [0, 1] }, { duration: 0.14, at: 1 }],
      [touch, { translate: [at(6, -12), at(-14, -12)] }, { duration: 0.55, at: 1.18 }],
      [lines, { translate: [at(0, -18), at(-18, -18)] }, { duration: 0.55, at: 1.18 }],
      [touch, { opacity: [1, 0] }, { duration: 0.14, at: 1.78 }],
      // Back to the start.
      [lines, { translate: [at(-18, -18), at(0, 0)] }, { duration: 0.5, at: 2, ease: 'easeOut' }],
      [touch, { translate: [at(-14, -12), at(0, 0)] }, { duration: 0.01, at: 2.3 }]
    ];
  },

  zones(drawing, row) {
    const touch = drawing.querySelector('.pv-touch');
    const zones = [...drawing.querySelectorAll('.pv-zone')];
    const stops = [at(0, 0), at(13, 13), at(0, 26), at(-13, 13), at(0, 0)];
    const sequence = [[touch, appear, { duration: 0.16 }]];

    // Top, right, bottom, left and back to the top. A zone is lit only while
    // the touch is on it.
    for (let step = 1; step < stops.length; step += 1) {
      const start = 0.45 + (step - 1) * 0.5;
      sequence.push(
        [touch, { translate: [stops[step - 1], stops[step]] }, { duration: 0.26, at: start }],
        [zones[(step - 1) % 4], { opacity: [1, 0] }, { duration: 0.14, at: start + 0.1 }],
        [zones[step % 4], { opacity: [0, 1] }, { duration: 0.14, at: start + 0.1 }]
      );
    }
    sequence.push([touch, vanish, { duration: 0.2, at: 2.45 }]);

    // The five layout glyphs under the description light their zones in turn.
    row.querySelectorAll('.zg').forEach((glyph, glyphIndex) => {
      glyph.querySelectorAll('.zg__zones > *').forEach((zone, zoneIndex) => {
        sequence.push([
          zone,
          { opacity: [0, 1, 0] },
          { duration: 0.42, at: 0.3 + glyphIndex * 0.3 + zoneIndex * 0.1, ease: 'easeOut' }
        ]);
      });
    });
    return sequence;
  },

  tap(drawing) {
    const dot = drawing.querySelector('.pv-dot');
    const ring = drawing.querySelector('.pv-ring');
    const sequence = [];
    for (const start of [0, 0.7]) {
      sequence.push(
        [dot, { scale: [1, 0.55, 1] }, { duration: 0.3, at: start }],
        [ring, { scale: [0.45, 1.75], opacity: [0.95, 0] }, { duration: 0.55, at: start + 0.06, ease: 'easeOut' }]
      );
    }
    sequence.push([ring, { scale: [0.6, 1], opacity: [0, 0.5] }, { duration: 0.35, at: 1.5 }]);
    return sequence;
  },

  rear(drawing) {
    const sequence = [];
    drawing.querySelectorAll('.pv-key').forEach((key, index) => {
      const on = key.querySelector('.pv-on');
      const start = index * 0.42;
      sequence.push(
        [on, { opacity: [0, 1] }, { duration: 0.1, at: start }],
        [key, { scale: [1, 0.9] }, { duration: 0.1, at: start }],
        [on, { opacity: [1, 0] }, { duration: 0.22, at: start + 0.34 }],
        [key, { scale: [0.9, 1] }, { duration: 0.22, at: start + 0.34 }]
      );
    });
    return sequence;
  },

  grips(drawing) {
    const touch = drawing.querySelector('.pv-touch');
    const [left, right] = drawing.querySelectorAll('.pv-on');
    return [
      [touch, appear, { duration: 0.16 }],
      [left, { opacity: [0, 1] }, { duration: 0.16, at: 0.06 }],
      [touch, { translate: [at(0, 0), at(23, 0)] }, { duration: 0.34, at: 0.85 }],
      [left, { opacity: [1, 0] }, { duration: 0.16, at: 0.85 }],
      [right, { opacity: [0, 1] }, { duration: 0.16, at: 1.1 }],
      [touch, vanish, { duration: 0.2, at: 1.95 }],
      [right, { opacity: [1, 0] }, { duration: 0.2, at: 1.95 }],
      [touch, { translate: [at(23, 0), at(0, 0)] }, { duration: 0.01, at: 2.2 }]
    ];
  },

  gyro(drawing) {
    const body = drawing.querySelector('.pv-body');
    const cursor = drawing.querySelector('.pv-cursor');
    const timing = { duration: 2.2, at: 0, times: [0, 0.28, 0.72, 1], ease: 'easeInOut' };
    return [
      [body, { rotate: ['0deg', '-13deg', '13deg', '0deg'] }, timing],
      [cursor, { translate: [at(0, 0), at(-12, 0), at(12, 0), at(0, 0)] }, timing]
    ];
  }
};

// A smooth closed path through the given points, sampled into keyframes so
// the pointer keeps moving through each point instead of stopping on it.
function glide(points, samples = 36) {
  const keyframes = [];
  const last = points.length - 1;
  for (let index = 0; index <= samples; index += 1) {
    const eased = easeInOut(index / samples) * last;
    const segment = Math.min(Math.floor(eased), last - 1);
    const t = eased - segment;
    const p0 = points[Math.max(segment - 1, 0)];
    const p1 = points[segment];
    const p2 = points[segment + 1];
    const p3 = points[Math.min(segment + 2, last)];
    keyframes.push(at(round(catmullRom(p0[0], p1[0], p2[0], p3[0], t)), round(catmullRom(p0[1], p1[1], p2[1], p3[1], t))));
  }
  return keyframes;
}

function catmullRom(a, b, c, d, t) {
  return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t);
}

function easeInOut(t) {
  return t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2;
}

function round(value) {
  return Math.round(value * 100) / 100;
}

export function setUpPreviews(reducedMotion) {
  const rows = document.querySelectorAll('.sheet--previews tbody tr');
  const arrivals = [];
  let nextStart = 0;

  // Rows that come into view together start a beat apart, in reading order,
  // so the whole run is over within a few seconds.
  function startArrivals() {
    const now = performance.now();
    arrivals.sort((a, b) => a.order - b.order);
    for (const { play } of arrivals.splice(0)) {
      const start = Math.max(now, nextStart);
      nextStart = start + 280;
      window.setTimeout(play, start - now);
    }
  }

  rows.forEach((row, order) => {
    const drawing = row.querySelector('.pv');
    const build = drawing && sequences[drawing.dataset.preview];
    if (!build) return;

    let playing = false;
    const play = () => {
      if (playing || reducedMotion.matches) return;
      playing = true;
      animateSequence(build(drawing, row), { defaultTransition: { ease: standard } }).then(() => {
        playing = false;
      });
    };

    const stop = inView(
      row,
      () => {
        if (!arrivals.length) window.setTimeout(startArrivals, 40);
        arrivals.push({ order, play });
        stop();
      },
      { amount: 0.8 }
    );

    hover(row, () => {
      play();
    });
    row.addEventListener('click', play);
  });
}
