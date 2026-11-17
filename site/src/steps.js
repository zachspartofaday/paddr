// Install steps: the numbers and the lines between them arrive in order the
// first time the list scrolls into view. The timing lives in styles.css; this
// only says when.

import { inView } from 'motion';

export function setUpSteps(reducedMotion) {
  const steps = document.querySelector('.steps');
  if (!steps) return;

  let stopWatching = () => {};
  const finish = () => {
    stopWatching();
    reducedMotion.removeEventListener('change', onMotionChange);
  };

  // Reduce Motion can be turned on after the page has loaded. Show the list
  // as it is in the markup, without the reveal.
  const onMotionChange = () => {
    if (!reducedMotion.matches) return;
    steps.classList.remove('is-armed');
    finish();
  };

  steps.classList.add('is-armed');
  reducedMotion.addEventListener('change', onMotionChange);
  stopWatching = inView(
    steps,
    () => {
      if (reducedMotion.matches) {
        steps.classList.remove('is-armed');
      } else {
        steps.classList.add('is-in');
      }
      finish();
    },
    { amount: 0.25 }
  );
}
