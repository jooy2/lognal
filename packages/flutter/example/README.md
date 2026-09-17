# lognal for Flutter: the gallery

The viewer, running, with buttons that write each kind of log.

```bash
flutter run
```

It is also what the documentation site frames for every Flutter preview. Built
for the web and served under `/flutter/`, it reads `?demo=` for which sample to
show and `?locale=` for which language the page around it is written in, and it
listens for the palette the page posts in. `npm run flutter` in `docs/` builds
it and copies it there.
