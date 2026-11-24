/**
 * Brain O' Clock promo (portrait, 1080 x 1920, about 16 seconds).
 *
 * One phone on a soft silver background walks through the app:
 * set an alarm -> it rings -> answer three in a row -> alarm off,
 * then pulls back to three phones and ends on the logo.
 */
import {Circle, Gradient, Img, Layout, Node, Rect, Txt, makeScene2D} from '@motion-canvas/2d';
import {
  all,
  cancel,
  chain,
  createRef,
  createRefArray,
  createSignal,
  easeInCubic,
  easeInOutCubic,
  easeOutBack,
  easeOutCubic,
  loop,
  sequence,
  waitFor,
} from '@motion-canvas/core';

import logo from '../assets/logo.png';

// ------------------------------------------------------------------ look
const FONT = 'Outfit, Inter, Arial, sans-serif';
const BG = '#000000';
const CARD = '#15151a';
const CARD_2 = '#1f1f26';
const LINE = '#2a2a31';
const INK = '#f4f4f5';
const MUTED = '#9a9aa6';
const BLUE = '#8ab4f8';
const DEEP_BLUE = '#1f4fd1';
const GREEN = '#30d158';
const DARK = '#16181d';

// The phone's glass, in its own units. Everything inside is laid out for it.
const W = 560;
const H = 1200;

const QUESTIONS = [
  {
    topic: 'BETA BLOCKERS',
    text: 'Which drug is a cardioselective beta blocker?',
    options: ['Propranolol', 'Atenolol', 'Carvedilol', 'Labetalol'],
    right: 1,
  },
  {
    topic: 'ANTICOAGULANTS',
    text: 'Which vitamin reverses the effect of warfarin?',
    options: ['Vitamin K', 'Vitamin C', 'Vitamin B12', 'Vitamin D'],
    right: 0,
  },
  {
    topic: 'OPIOIDS',
    text: 'What is the antidote for morphine overdose?',
    options: ['Flumazenil', 'Atropine', 'Naloxone', 'Protamine'],
    right: 2,
  },
];

/** A phone: silver frame, black glass, whatever is passed in on the glass. */
function Phone(props: {children?: any; ref?: any; x?: number; y?: number; scale?: number; rotation?: number; opacity?: number}) {
  return (
    <Node ref={props.ref} x={props.x ?? 0} y={props.y ?? 0} scale={props.scale ?? 1} rotation={props.rotation ?? 0} opacity={props.opacity ?? 1}>
      <Rect width={W + 44} height={H + 44} radius={92} fill={'#e8eaee'} stroke={'#8f949e'} lineWidth={3} shadowColor={'rgba(20,22,30,0.45)'} shadowBlur={70} shadowOffsetY={40} />
      <Rect width={W + 14} height={H + 14} radius={78} fill={'#050506'} />
      <Rect width={W} height={H} radius={72} fill={BG} clip>
        {props.children}
        <Circle y={-H / 2 + 34} size={18} fill={'#17181c'} />
      </Rect>
    </Node>
  );
}

export default makeScene2D(function* (view) {
  view.fill('#bec1c9');
  view.fontFamily(FONT);

  // -------------------------------------------------------------- stage
  const glow = createRef<Circle>();
  const caption = createRef<Txt>();
  const sub = createRef<Txt>();
  const phone = createRef<Node>();
  const left = createRef<Node>();
  const right = createRef<Node>();

  // What the phone shows.
  const home = createRef<Node>();
  const ring = createRef<Node>();
  const done = createRef<Node>();
  const toggle = createRef<Rect>();
  const knob = createRef<Circle>();
  const question = createRef<Node>();
  const options = createRefArray<Rect>();
  const badges = createRefArray<Rect>();
  const finger = createRef<Circle>();
  const tick = createRef<Circle>();

  const streak = createSignal(0);
  const bar = createSignal(0);
  const topic = createSignal(QUESTIONS[0].topic);
  const text = createSignal(QUESTIONS[0].text);
  const optionText = QUESTIONS[0].options.map(o => createSignal(o));

  // Intro and end card.
  const mark = createRef<Img>();
  const name = createRef<Txt>();
  const line = createRef<Txt>();
  const pill = createRef<Rect>();

  view.add(
    <>
      <Circle
        ref={glow}
        y={240}
        size={2200}
        opacity={0}
        fill={
          new Gradient({
            type: 'radial',
            fromRadius: 0,
            toRadius: 1100,
            stops: [
              {offset: 0, color: 'rgba(255,255,255,0.55)'},
              {offset: 0.55, color: 'rgba(255,255,255,0.16)'},
              {offset: 1, color: 'rgba(255,255,255,0)'},
            ],
          })
        }
      />

      <Txt ref={caption} y={-800} fontSize={76} fontWeight={700} fill={DARK} opacity={0} textAlign={'center'} letterSpacing={-1.5} />
      <Txt ref={sub} y={-712} fontSize={40} fontWeight={500} fill={'#3b3e48'} opacity={0} textAlign={'center'} />

      {/* Two more phones for the pull-back, behind the main one. */}
      <Phone ref={left} x={-900} y={240} scale={0.58} rotation={-9} opacity={0}>
        <Layout layout direction={'column'} width={W} height={H} padding={[110, 40, 40, 40]} gap={26}>
          <Txt text={'Reports'} fontSize={48} fontWeight={700} fill={INK} />
          <Rect layout direction={'column'} fill={CARD} radius={30} padding={32} gap={10}>
            <Txt text={'Accuracy'} fontSize={28} fill={MUTED} />
            <Txt text={'78%'} fontSize={110} fontWeight={700} fill={INK} />
            <Txt text={'Up 6% this week'} fontSize={28} fill={GREEN} />
          </Rect>
          <Rect layout fill={CARD} radius={30} padding={32} gap={20} height={420} alignItems={'end'} justifyContent={'space-between'}>
            {[150, 210, 120, 260, 190, 300, 240].map(h => (
              <Rect width={44} height={h} radius={12} fill={h > 250 ? BLUE : CARD_2} />
            ))}
          </Rect>
          <Rect layout direction={'column'} fill={CARD} radius={30} padding={32} gap={8}>
            <Txt text={'Revise next'} fontSize={28} fill={MUTED} />
            <Txt text={'Antiarrhythmics'} fontSize={38} fontWeight={600} fill={INK} />
          </Rect>
        </Layout>
      </Phone>
      <Phone ref={right} x={900} y={240} scale={0.58} rotation={9} opacity={0}>
        <Layout layout direction={'column'} width={W} height={H} padding={[110, 40, 40, 40]} gap={22}>
          <Txt text={'Pharmacology'} fontSize={48} fontWeight={700} fill={INK} />
          <Txt text={'172 topics · 2,300+ questions'} fontSize={28} fill={MUTED} />
          {['Autonomic nervous system', 'Antimicrobials', 'Cardiovascular drugs', 'CNS and anaesthesia', 'Endocrine drugs', 'Chemotherapy'].map(
            (t, i) => (
              <Rect layout fill={CARD} radius={26} padding={[26, 28]} gap={22} alignItems={'center'}>
                <Circle size={52} stroke={i < 2 ? GREEN : BLUE} lineWidth={7} startAngle={-90} endAngle={-90 + [320, 250, 190, 140, 90, 40][i]} />
                <Txt text={t} fontSize={31} fontWeight={600} fill={INK} />
              </Rect>
            ),
          )}
        </Layout>
      </Phone>

      <Phone ref={phone} y={1900} rotation={14} scale={0.94}>
        {/* 1. Home: the alarm list. */}
        <Node ref={home}>
          <Layout layout direction={'column'} width={W} height={H} padding={[110, 40, 40, 40]} gap={28}>
            <Txt text={"Brain O' Clock"} fontSize={42} fontWeight={700} fill={INK} />
            <Rect layout direction={'column'} fill={CARD} radius={34} padding={36} gap={6}>
              <Txt text={'Good evening'} fontSize={28} fill={MUTED} />
              <Txt text={'10:42 PM'} fontSize={104} fontWeight={600} fill={INK} letterSpacing={-3} />
              <Txt text={'Next alarm in 6 hours 48 minutes'} fontSize={25} fill={BLUE} />
            </Rect>
            <Txt text={'Your alarms'} fontSize={32} fontWeight={600} fill={INK} marginTop={14} />
            <Rect layout fill={CARD} radius={34} padding={36} alignItems={'center'} justifyContent={'space-between'}>
              <Layout layout direction={'column'} gap={6}>
                <Txt text={'5:30 AM'} fontSize={72} fontWeight={600} fill={INK} letterSpacing={-2} />
                <Txt text={'Pharmacology · tomorrow'} fontSize={25} fill={MUTED} />
              </Layout>
              <Rect ref={toggle} width={104} height={58} radius={29} fill={CARD_2}>
                <Circle ref={knob} x={-23} size={44} fill={'#8d8d98'} />
              </Rect>
            </Rect>
            <Rect layout fill={CARD} radius={34} padding={36} alignItems={'center'} justifyContent={'space-between'} opacity={0.55}>
              <Layout layout direction={'column'} gap={6}>
                <Txt text={'7:00 AM'} fontSize={72} fontWeight={600} fill={INK} letterSpacing={-2} />
                <Txt text={'All topics · weekdays'} fontSize={25} fill={MUTED} />
              </Layout>
              <Rect width={104} height={58} radius={29} fill={CARD_2}>
                <Circle x={-23} size={44} fill={'#8d8d98'} />
              </Rect>
            </Rect>
          </Layout>
          <Rect y={H / 2 - 110} layout padding={[26, 50]} radius={44} fill={INK}>
            <Txt text={'+  Add alarm'} fontSize={32} fontWeight={700} fill={'#05060a'} />
          </Rect>
        </Node>

        {/* 2. The alarm ringing: answer to stop it. */}
        <Node ref={ring} opacity={0}>
          <Layout layout direction={'column'} width={W} height={H} padding={[110, 38, 40, 38]} gap={18}>
            <Layout layout justifyContent={'space-between'} alignItems={'center'}>
              <Txt text={'Morning alarm'} fontSize={32} fontWeight={600} fill={MUTED} />
              <Txt text={'5:30 AM'} fontSize={48} fontWeight={700} fill={INK} />
            </Layout>
            <Txt text={() => `Streak: ${streak()} / 3`} fontSize={38} fontWeight={700} fill={INK} marginTop={10} />
            <Rect width={W - 76} height={14} radius={7} fill={CARD_2}>
              <Rect x={() => -(W - 76) / 2 + ((W - 76) * bar()) / 2} width={() => (W - 76) * bar()} height={14} radius={7} fill={GREEN} />
            </Rect>
            <Node ref={question}>
              <Layout layout direction={'column'} gap={22} marginTop={60} width={W - 76}>
                <Txt text={() => `TOPIC: ${topic()}`} fontSize={24} fontWeight={600} fill={MUTED} letterSpacing={1} />
                <Txt text={text} fontSize={48} fontWeight={700} fill={INK} textWrap width={W - 76} lineHeight={60} />
                <Layout layout direction={'column'} gap={20} marginTop={30}>
                  {optionText.map((o, i) => (
                    <Rect ref={options} layout fill={CARD} stroke={LINE} lineWidth={2} radius={26} padding={[30, 26]} gap={22} alignItems={'center'}>
                      <Rect ref={badges} width={50} height={50} radius={14} fill={CARD_2} layout alignItems={'center'} justifyContent={'center'}>
                        <Txt text={'ABCD'[i]} fontSize={26} fontWeight={700} fill={INK} />
                      </Rect>
                      <Txt text={o} fontSize={38} fontWeight={500} fill={INK} />
                    </Rect>
                  ))}
                </Layout>
              </Layout>
            </Node>
          </Layout>
          <Circle ref={finger} size={70} fill={'rgba(255,255,255,0.32)'} stroke={'rgba(255,255,255,0.75)'} lineWidth={3} x={200} y={620} opacity={0} />
        </Node>

        {/* 3. Alarm off. */}
        <Node ref={done} opacity={0}>
          <Circle ref={tick} y={-120} size={230} fill={GREEN} scale={0}>
            <Txt text={'✓'} fontSize={130} fontWeight={800} fill={'#06140a'} y={6} />
          </Circle>
          <Txt text={'Alarm off'} y={90} fontSize={72} fontWeight={700} fill={INK} />
          <Txt text={'3 in a row. Good morning.'} y={170} fontSize={32} fill={MUTED} />
        </Node>
      </Phone>

      {/* Intro and end card. */}
      <Img ref={mark} src={logo} width={300} y={-80} scale={0} />
      <Txt ref={name} text={"Brain O' Clock"} y={150} fontSize={104} fontWeight={800} fill={DARK} letterSpacing={-3} opacity={0} />
      <Txt ref={line} text={'The alarm that won’t stop until you’ve revised.'} y={250} fontSize={40} fontWeight={500} fill={'#3b3e48'} opacity={0} />
      <Rect ref={pill} y={420} layout padding={[26, 54]} radius={50} fill={DARK} opacity={0} scale={0.9}>
        <Txt text={'brainoclock.onrender.com'} fontSize={42} fontWeight={700} fill={'#ffffff'} />
      </Rect>
    </>,
  );

  /** Swaps the headline above the phone. */
  function* say(title: string, under: string) {
    yield* all(caption().opacity(0, 0.2), sub().opacity(0, 0.2));
    caption().text(title);
    sub().text(under);
    caption().y(-770);
    yield* all(
      caption().opacity(1, 0.35),
      caption().y(-800, 0.35, easeOutCubic),
      sub().opacity(1, 0.45),
    );
  }

  /** A finger taps the right option; it turns green and the streak grows. */
  function* answer(index: number) {
    const q = QUESTIONS[index];
    const target = options[q.right];
    // Where the option is, in the ringing screen's own coordinates.
    const at = target.absolutePosition().transformAsPoint(ring().worldToLocal());
    finger().position([at.x + 150, at.y + 230]);
    yield* all(finger().opacity(1, 0.2), finger().position([at.x + 60, at.y + 6], 0.45, easeInOutCubic));
    yield* finger().scale(0.72, 0.09).to(1, 0.12);
    yield* all(
      target.fill('#0f2a16', 0.18),
      target.stroke(GREEN, 0.18),
      badges[q.right].fill(GREEN, 0.18),
      target.scale(1.03, 0.12).to(1, 0.16),
      finger().opacity(0, 0.25),
      bar((index + 1) / 3, 0.4, easeOutCubic),
    );
    streak(index + 1);
    yield* waitFor(0.35);
  }

  /** Brings the next question in. */
  function* next(index: number) {
    const q = QUESTIONS[index];
    yield* all(question().opacity(0, 0.18), question().x(-40, 0.18, easeInCubic));
    topic(q.topic);
    text(q.text);
    q.options.forEach((o, i) => optionText[i](o));
    options.forEach(o => {
      o.fill(CARD);
      o.stroke(LINE);
    });
    badges.forEach(b => b.fill(CARD_2));
    question().x(40);
    yield* all(question().opacity(1, 0.22), question().x(0, 0.22, easeOutCubic));
  }

  // ------------------------------------------------------------- 1. intro
  yield* all(glow().opacity(1, 0.8), mark().scale(1, 0.7, easeOutBack));
  yield* name().opacity(1, 0.4);
  yield* waitFor(0.7);
  yield* all(
    mark().scale(0, 0.4, easeInCubic),
    mark().y(-300, 0.4, easeInCubic),
    name().opacity(0, 0.3),
  );

  // ---------------------------------------------------- 2. set the alarm
  yield* all(
    phone().y(240, 0.9, easeOutCubic),
    phone().rotation(0, 0.9, easeOutCubic),
    say('Set tomorrow’s alarm.', 'Pick the topic that wakes you.'),
  );
  yield* waitFor(0.3);
  yield* all(
    toggle().fill(DEEP_BLUE, 0.25),
    knob().x(23, 0.25, easeInOutCubic),
    knob().fill('#ffffff', 0.25),
    toggle().scale(1.1, 0.12).to(1, 0.16),
  );
  yield* waitFor(0.8);

  // ------------------------------------------------------------ 3. it rings
  yield* all(
    home().opacity(0, 0.3),
    home().x(-80, 0.3, easeInCubic),
    ring().opacity(1, 0.35),
    say('5:30 AM. It rings.', 'No off button. No easy snooze.'),
  );
  const shake = yield loop(() => phone().rotation(2.2, 0.05).to(-2.2, 0.1).to(0, 0.05));
  yield* waitFor(1.1);
  cancel(shake);
  yield* phone().rotation(0, 0.15);

  // ------------------------------------------------- 4. three in a row
  yield* say('Answer 3 in a row.', 'From your own course’s questions.');
  yield* answer(0);
  yield* next(1);
  yield* answer(1);
  yield* next(2);
  yield* answer(2);

  // ------------------------------------------------------- 5. alarm off
  yield* all(
    ring().opacity(0, 0.3),
    done().opacity(1, 0.3),
    tick().scale(1, 0.5, easeOutBack),
    say('Alarm off.', 'You’re up, and already revised.'),
  );
  yield* waitFor(1.2);

  // -------------------------------------------------------- 6. pull back
  yield* all(
    phone().scale(0.66, 0.8, easeInOutCubic),
    phone().y(200, 0.8, easeInOutCubic),
    left().opacity(1, 0.5),
    left().x(-330, 0.8, easeOutCubic),
    right().opacity(1, 0.5),
    right().x(330, 0.8, easeOutCubic),
    say('2,300+ questions.', 'Reports show what to revise next.'),
  );
  yield* waitFor(1.5);

  // --------------------------------------------------------- 7. end card
  yield* all(
    caption().opacity(0, 0.3),
    sub().opacity(0, 0.3),
    ...[phone(), left(), right()].map(p => all(p.opacity(0, 0.4), p.y(p.y() + 160, 0.4, easeInCubic))),
  );
  mark().y(-190);
  yield* sequence(
    0.15,
    mark().scale(1, 0.6, easeOutBack),
    name().opacity(1, 0.4),
    line().opacity(1, 0.4),
    all(pill().opacity(1, 0.4), pill().scale(1, 0.4, easeOutBack)),
  );
  yield* chain(pill().scale(1.05, 0.5, easeInOutCubic), pill().scale(1, 0.5, easeInOutCubic));
  yield* waitFor(1);
});
