import {makeProject} from '@motion-canvas/core';

import './global.css';
import brainoclock from './scenes/brainoclock?scene';

export default makeProject({
  scenes: [brainoclock],
});
