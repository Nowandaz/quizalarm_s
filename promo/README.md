# Brain O' Clock promo animation (Motion Canvas 3.17)

Portrait, 1080 x 1920, about 20 seconds. The scene is `src/scenes/brainoclock.tsx`,
registered in `src/project.ts`.

    npm install
    npx tsc --noEmit -p .     # check for errors
    npm start                 # editor at http://localhost:9000

To use it in another Motion Canvas project, copy `src/scenes/brainoclock.tsx`,
`src/assets/` and `src/global.css`, then add the scene to that project's
`project.ts` (and `import './global.css';` for the Outfit font). Set the
resolution to 1080 x 1920 under Video Settings.
