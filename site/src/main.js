// Enhancements only. The page is complete without this file: the drawings
// rest in a readable pose, the steps are all shown, and the window image
// follows the system appearance.

import { setUpAppearance } from './appearance.js';
import { setUpPreviews } from './previews.js';
import { setUpSteps } from './steps.js';

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

setUpAppearance();

if (!reducedMotion.matches) {
  setUpPreviews(reducedMotion);
  setUpSteps();
}
