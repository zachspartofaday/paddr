// Install steps: the numbers and the lines between them arrive in order the
// first time the list scrolls into view. The timing lives in styles.css; this
// only says when.

import { inView } from 'motion';

export function setUpSteps() {
  const steps = document.querySelector('.steps');
  if (!steps) return;

  steps.classList.add('is-armed');
  const stop = inView(
    steps,
    () => {
      steps.classList.add('is-in');
      stop();
    },
    { amount: 0.25 }
  );
}
