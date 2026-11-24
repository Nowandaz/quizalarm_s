/**
 * Brain O' Clock promo: the real app, screen by screen.
 *
 * Every picture in the phone is a screenshot taken from the app itself
 * (see tools_prepare.py and film.steps.json). This scene only plays them
 * in order: a finger marks each tap or swipe, the next screen fades in,
 * and a caption above the phone says what is happening.
 */
import {Circle, Gradient, Img, Node, Rect, Txt, makeScene2D} from '@motion-canvas/2d';
import {
  all,
  cancel,
  chain,
  createRef,
  createRefArray,
  easeInCubic,
  easeInOutCubic,
  easeOutBack,
  easeOutCubic,
  loop,
  sequence,
  waitFor,
} from '@motion-canvas/core';

import logo from '../assets/logo.png';
import stepList from './film.steps.json';

interface Step {
  img: string;
  name: string;
  /** Where the finger taps, in the app's own 412 x 892 points. */
  tap?: number[] | null;
  /** A swipe: start x, start y, distance down (negative = up). */
  drag?: number[];
  /** Seconds to stay on this screen before moving on. */
  hold?: number;
  /** A screen with an explanation to read: stays longer. */
  read?: boolean;
  /** The chapter that starts with this screen. */
  chapter?: string;
}
const STEPS = stepList as Step[];

const pictures = import.meta.glob('../assets/shots/*.jpg', {eager: true, import: 'default'}) as Record<string, string>;
const picture = (name: string) => pictures[`../assets/shots/${name}`];

const FONT = 'Outfit, Inter, Arial, sans-serif';
const DARK = '#16181d';

// The app is filmed at 412 x 892; this is its size on the canvas.
const W = 630;
const H = (W * 892) / 412;

/** What the caption says in each chapter. */
const CAPTIONS: Record<string, [string, string]> = {
  alarm: ['Set your alarm.', 'Choose the time you need to be up.'],
  topic: ['Pick what wakes you.', 'Any unit, section or topic.'],
  ring: ['5:30 AM. It rings.', 'No off button. Answer to stop it.'],
  reset: ['Wrong? The streak resets.', 'And you see why, straight away.'],
  streak: ['Answer in a row.', 'Only then does the alarm stop.'],
  review: ['Review what you missed.', 'Every mistake, with its explanation.'],
  bank: ['A full question bank.', 'Search any topic in seconds.'],
  practice: ['Practise any time.', 'No alarm needed.'],
  reports: ['Know what to revise.', 'Reports show your weak topics.'],
};

export default makeScene2D(function* (view) {
  view.fill('#bec1c9');
  view.fontFamily(FONT);

  const glow = createRef<Circle>();
  const caption = createRef<Txt>();
  const sub = createRef<Txt>();
  const phone = createRef<Node>();
  const shots = createRefArray<Img>();
  const night = createRef<Rect>();
  const finger = createRef<Circle>();
  const mark = createRef<Img>();
  const name = createRef<Txt>();
  const line = createRef<Txt>();
  const pill = createRef<Rect>();

  view.add(
    <>
      <Circle
        ref={glow}
        y={200}
        size={2300}
        opacity={0}
        fill={
          new Gradient({
            type: 'radial',
            fromRadius: 0,
            toRadius: 1150,
            stops: [
              {offset: 0, color: 'rgba(255,255,255,0.55)'},
              {offset: 0.55, color: 'rgba(255,255,255,0.16)'},
              {offset: 1, color: 'rgba(255,255,255,0)'},
            ],
          })
        }
      />

      <Txt ref={caption} y={-860} fontSize={70} fontWeight={700} fill={DARK} opacity={0} letterSpacing={-1.5} />
      <Txt ref={sub} y={-780} fontSize={38} fontWeight={500} fill={'#3b3e48'} opacity={0} />

      <Node ref={phone} y={2100} rotation={12}>
        <Rect width={W + 44} height={H + 44} radius={86} fill={'#e8eaee'} stroke={'#8f949e'} lineWidth={3} shadowColor={'rgba(20,22,30,0.45)'} shadowBlur={70} shadowOffsetY={40} />
        <Rect width={W + 14} height={H + 14} radius={72} fill={'#050506'} />
        <Rect width={W} height={H} radius={64} fill={'#000000'} clip>
          {STEPS.map(s => (
            <Img ref={shots} src={picture(s.img)} width={W} height={H} opacity={0} />
          ))}
          <Rect ref={night} width={W} height={H} fill={'#000000'} opacity={0} />
          <Circle ref={finger} size={78} fill={'rgba(255,255,255,0.30)'} stroke={'rgba(255,255,255,0.85)'} lineWidth={4} opacity={0} />
        </Rect>
      </Node>

      <Img ref={mark} src={logo} width={300} y={-80} scale={0} />
      <Txt ref={name} text={"Brain O' Clock"} y={150} fontSize={104} fontWeight={800} fill={DARK} letterSpacing={-3} opacity={0} />
      <Txt ref={line} text={'The alarm that won’t stop until you’ve revised.'} y={250} fontSize={40} fontWeight={500} fill={'#3b3e48'} opacity={0} />
      <Rect ref={pill} y={420} layout padding={[26, 54]} radius={50} fill={DARK} opacity={0} scale={0.9}>
        <Txt text={'brainoclock.onrender.com'} fontSize={42} fontWeight={700} fill={'#ffffff'} />
      </Rect>
    </>,
  );

  /** A point of the app's screen, as a position inside the phone. */
  const at = (x: number, y: number): [number, number] => [(x / 412 - 0.5) * W, (y / 892 - 0.5) * H];
  const length = (y: number) => (y / 892) * H;

  function* say(key: string) {
    const words = CAPTIONS[key];
    if (!words) return;
    yield* all(caption().opacity(0, 0.2), sub().opacity(0, 0.2));
    caption().text(words[0]);
    sub().text(words[1]);
    caption().y(-830);
    yield* all(caption().opacity(1, 0.35), caption().y(-860, 0.35, easeOutCubic), sub().opacity(1, 0.45));
  }

  // ----------------------------------------------------------------- intro
  yield* all(glow().opacity(1, 0.8), mark().scale(1, 0.7, easeOutBack));
  yield* name().opacity(1, 0.4);
  yield* waitFor(0.8);
  yield* all(mark().scale(0, 0.4, easeInCubic), mark().y(-300, 0.4, easeInCubic), name().opacity(0, 0.3));

  // ------------------------------------------------- the app, step by step
  shots[0].opacity(1);
  for (let i = 0; i < STEPS.length; i++) {
    const step = STEPS[i];
    const next = i + 1 < STEPS.length ? shots[i + 1] : null;
    const nextStep = STEPS[i + 1];

    if (i === 0) {
      yield* all(phone().y(130, 0.9, easeOutCubic), phone().rotation(0, 0.9, easeOutCubic), say(step.chapter ?? ''));
    } else if (step.chapter) {
      yield* say(step.chapter);
    }

    // The alarm starts ringing: the phone shakes.
    if (step.chapter === 'ring') {
      const shake = yield loop(() => phone().rotation(2, 0.05).to(-2, 0.1).to(0, 0.05));
      yield* waitFor(1.2);
      cancel(shake);
      yield* phone().rotation(0, 0.15);
    }

    yield* waitFor(step.hold ?? (step.read ? 3.4 : step.name.endsWith('_correct') ? 0.75 : 0.6));
    if (!next) break;

    // Night passes between setting the alarm and its ringing.
    if (nextStep.chapter === 'ring') {
      yield* all(night().opacity(1, 0.5), caption().opacity(0, 0.3), sub().opacity(0, 0.3));
      shots[i].opacity(0);
      next.opacity(1);
      yield* waitFor(0.35);
      yield* night().opacity(0, 0.4);
      continue;
    }

    if (step.tap) {
      const [x, y] = at(step.tap[0], step.tap[1]);
      finger().position([x + 70, y + 150]);
      finger().scale(1);
      yield* all(finger().opacity(1, 0.18), finger().position([x, y], 0.34, easeInOutCubic));
      yield* finger().scale(0.7, 0.08).to(1, 0.1);
      yield* all(next.opacity(1, 0.22), finger().opacity(0, 0.22));
    } else if (step.drag) {
      const [x, y] = at(step.drag[0], step.drag[1]);
      finger().position([x, y]);
      finger().scale(0.85);
      yield* finger().opacity(1, 0.15);
      yield* all(finger().position([x, y + length(step.drag[2])], 0.45, easeInOutCubic), next.opacity(1, 0.45));
      yield* finger().opacity(0, 0.15);
    } else {
      yield* next.opacity(1, 0.22);
    }
    shots[i].opacity(0);
  }
  yield* waitFor(0.6);

  // -------------------------------------------------------------- end card
  yield* all(caption().opacity(0, 0.3), sub().opacity(0, 0.3), phone().opacity(0, 0.45), phone().y(300, 0.45, easeInCubic));
  mark().y(-190);
  yield* sequence(
    0.15,
    mark().scale(1, 0.6, easeOutBack),
    name().opacity(1, 0.4),
    line().opacity(1, 0.4),
    all(pill().opacity(1, 0.4), pill().scale(1, 0.4, easeOutBack)),
  );
  yield* chain(pill().scale(1.05, 0.5, easeInOutCubic), pill().scale(1, 0.5, easeInOutCubic));
  yield* waitFor(1.5);
});
