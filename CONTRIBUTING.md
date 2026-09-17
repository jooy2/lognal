# Contributing to lognal

Thank you for contributing to the project. Your contributions will help us take the project to the next level.

This project adheres to the [Contributor Covenant](CODE_OF_CONDUCT.md) code of conduct, version 2.1. Your contribution implies that you have read and agree to this policy. Any behavior that undermines the quality of the project community, including this policy, will be warned or restricted by the maintainers.

## Repository layout

lognal ships one library in two ecosystems, so the repository holds one package per language and a documentation site they share. There is no install at the root and no root manifest; each folder is entered and run on its own.

```text
packages/js/       # the npm package, `lognal`
packages/flutter/  # the pub.dev package, `lognal`
docs/              # the VitePress documentation site (English and Korean, both packages)
```

Both packages are laid out the same way, because they are the same library:

```text
core/       # entries, the store, filters, text measurement and layout; no screen, no framework
sources/    # console capture and text file reading, which use the platform's own APIs
renderer/   # the renderer interface and the canvas renderer
viewer/     # the viewer itself: toolbar, scrolling, selection, input line and accessibility
```

In `packages/js` those are folders under `src/`, plus `react/` for the React component and `styles/` for `lognal.css`. In `packages/flutter` they are folders under `lib/src/`, plus `theme/` for the palettes that the stylesheet holds on the other side. Each package keeps its own tests beside them, its own `README.md`, `LICENSE` and `CHANGELOG.md`, and its own toolchain.

Code under `core/` must stay free of the DOM, of framework code and of platform APIs only one language has, because the two cores are written against each other and a change to one is a change to both. Pass a platform feature in, the way `setGraphemeSplitter` does, instead of importing it there.

## Development

You need Node.js 22.12 or later for the JavaScript package and the site, and Flutter 3.32 or later for the Flutter package.

### The JavaScript package, in `packages/js`

| Task                      | Command                    |
| ------------------------- | -------------------------- |
| Install                   | `npm install`              |
| Playground                | `npm run dev`              |
| All tests                 | `npm test`                 |
| Unit tests only           | `npm run test:unit`        |
| Browser tests only        | `npm run test:browser`     |
| Lint / format             | `npm run lint` / `npm run format` |
| Type check                | `npm run typecheck`        |
| Build `dist/`             | `npm run build`            |
| Regenerate Unicode widths | `npm run generate:unicode` |

Browser tests use Playwright. Install the browsers once with `npx playwright install`, or run a single browser with `LOGNAL_TEST_BROWSERS=chromium npm run test:browser`.

Import other source files with a `.js` extension, such as `import { LogStore } from './store.js'`. TypeScript resolves it to the `.ts` file, and the published declaration files keep working.

### The Flutter package, in `packages/flutter`

| Task               | Command                            |
| ------------------ | ---------------------------------- |
| Install            | `flutter pub get`                  |
| Tests              | `flutter test`                     |
| Analyse            | `dart analyze`                     |
| Format             | `dart format lib test example/lib` |
| Example            | `cd example && flutter run`        |
| Check it publishes | `dart pub publish --dry-run`       |

### The documentation site, in `docs`

| Task            | Command             |
| --------------- | ------------------- |
| Install         | `npm install`       |
| Develop         | `npm run dev`       |
| Build           | `npm run build`     |
| Flutter gallery | `npm run flutter`   |

The site is one set of pages for both packages. A switch above the sidebar picks the language, and `::: fw js` and `::: fw flutter` blocks mark the parts of a page that differ. Write both halves, or neither.

A change that users can see needs an entry in the `CHANGELOG.md` of the package it changes, in the unreleased section at the top.

## Issues

Issues can be created on the following page: https://github.com/jooy2/lognal/issues

Alternatively, you can reach the maintainers at https://cdget.com/contact. However, we prefer to track progress via GitHub Issues.

When creating an issue, keep the following in mind:

- Please specify the correct category selection based on the format of the issue (e.g., bug report, feature request).
- Check to see if there are duplicate issues.
- Describe in detail what is happening and what needs to be fixed. You may need additional materials such as images or video.
- Name the package and version you are on, and the browser or the Flutter version you ran it in.
- Use appropriate keyword titles to make it easy for others to search and understand.
- Please use English in all content.

A security vulnerability is not a general issue. Report one through the process in [SECURITY.md](SECURITY.md).

## How to contribute (Pull Requests)

### Write the code you want to change

Here's the process for contributing to the project:

1. Clone the project (or rebase to the latest commit in the main branch)
2. Install the package (if the package manager exists)
3. Setting up lint or code formatter in the IDE (if your project includes a linter) and installing the relevant plugins. Some projects may use specific commands to check rules and perform formatting after module installation and before committing.
4. Write the code that needs to be fixed
5. Update the documentation (if it exists) or create a new one. If your project supports multilingual documentation, update the documentation for all languages. You can fill in the content in your own language and not translate it.
6. Add or modify tests as needed (if test code exists). You should also verify that existing tests pass.

### Write a commit message

While we don't have strict restrictions on commit messages, we recommend that you follow the recommendations below whenever possible:

- Write in English.
- Use backticks to name functions, variables, folders, and files.
- Use a format like `xxx: message (fixes #1)`. The content in parentheses is optional.
- The message includes a summary of what was modified.
- It's a good idea to separate multiple modifications into their own commit messages.

It is recommended that you include a tag at the beginning of the commit message. Between the tag and the message, use `: ` between the tag and the message.

tags conform to the ["Udacity Git Commit Message Style Guide"](https://udacity.github.io/git-styleguide). However, you are welcome to use tags not listed here for additional situations.

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Changes to documentation
- `style`: Formatting, missing semicolons, etc.; no code change
- `refactor`: Refactoring production code
- `test`: Adding tests, refactoring test; no production code change
- `chore`: Updating build tasks, package manager configs, etc.; no production code change

Informal tags:

- `package`: Modifications to package settings, modules, or GitHub projects
- `typo`: Fix typos

```text
feat: add the `maxEntries` option
fix: keep the scroll position when the viewer is resized (fixes #12)
```

### Create a pull request

When creating a pull request, keep the following in mind:

- Include a specific description of what the modification is, why it needs to be made, and how it works.
- Check to see if there are duplicate pull requests.
- Please use English in all content.

Typically, a project maintainer will review and test your code before merging it into the project. This process can take some time, and they may ask you for further edits or clarifications in the comments.
