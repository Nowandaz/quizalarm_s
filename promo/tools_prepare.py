"""Copies the screenshots taken from the real app into the project and
writes the list of steps the scene plays (src/scenes/film.steps.json).

    python3 tools_prepare.py <folder with the screenshots and steps.json>
"""
import json, os, subprocess, sys, shutil
src = sys.argv[1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src', 'assets', 'shots')
shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
steps, chapter, n = [], None, 0
for s in json.load(open(os.path.join(src, 'steps.json'))):
    if 'chapter' in s:
        chapter = s['chapter']; continue
    name = '%03d.jpg' % n; n += 1
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(src, s['file']), '-vf', 'scale=824:-1:flags=lanczos',
                    '-q:v', '2', os.path.join(out, name)], check=True)
    step = {'img': name, 'name': s['name']}
    for k in ('tap', 'drag', 'hold', 'read'):
        if s.get(k) is not None: step[k] = s[k]
    if chapter: step['chapter'] = chapter; chapter = None
    steps.append(step)
json.dump(steps, open(os.path.join(os.path.dirname(out), '..', 'scenes', 'film.steps.json'), 'w'), indent=1)
print(len(steps), 'steps')
