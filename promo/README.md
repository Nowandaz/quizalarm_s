# Brain O' Clock promo animation (Motion Canvas 3.17)

Portrait, 1080 x 1920, about 1 minute 45 seconds. Every picture inside the
phone is a screenshot of the real app (taken from a browser build, without
the phone's status bar). The scene is `src/scenes/film.tsx`, registered in
`src/project.ts`; it plays the steps listed in `src/scenes/film.steps.json`
with the pictures in `src/assets/shots/`.

    npm install
    npx tsc --noEmit -p .     # check for errors
    npm start                 # editor at http://localhost:9000

What to change where:

- Captions: the `CAPTIONS` table at the top of `film.tsx`.
- How long a screen stays: `hold` (seconds) on that step in
  `film.steps.json`; `read: true` marks a screen with an explanation.
- New screenshots: film the app again (see `tool/promo/README.md` in the app
  repository), then `python3 tools_prepare.py <folder with the shots>`.

`brain-o-clock-promo.mp4` is the rendered video (no sound).
