# lognal

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jooy2/lognal/blob/main/LICENSE) ![Commit Count](https://img.shields.io/github/commit-activity/y/jooy2/lognal) [![Followers](https://img.shields.io/github/followers/jooy2?style=social)](https://github.com/jooy2) ![Stars](https://img.shields.io/github/stars/jooy2/lognal?style=social)

**lognal** is a log viewer for web pages that looks and behaves like a terminal. It draws log output on a canvas instead of creating a DOM element for every line, so it keeps up with a fast stream of messages and a long history without slowing the page down.

> **lognal is in the design stage.** No package is published and there is no API to try yet. The sections below describe what the library is being built to do.

## What it is for

- **Show the browser console inside your page.** Hook `console.log`, `console.warn`, `console.error` and the other console methods, and display what they print the way the browser's developer tools do. The original console keeps working.
- **Read text files.** Open a log file and scroll through it in the viewer. A browser cannot follow a growing file the way `tail -f` does, so reading the file is the starting point.
- **Inspect values by type.** Arrays, objects, JSON, numbers, strings, `Map`, `Set`, errors and other types are formatted by type, and nested values can be expanded and collapsed.
- **Send input.** When you connect something that answers, such as a command handler, a WebSocket or a worker, the viewer shows an input line and prints the replies.

## Planned features

- A timestamp on every line
- Filtering by log level and by text
- Search with highlighted matches
- Light and dark themes, and custom color themes
- Custom font family, font size and line height
- Text selection and copy to the clipboard
- A limit on retained lines, so memory use stays bounded

## Design goals

- **Rendering cost follows the screen, not the history.** Drawing a frame costs about the same whether the viewer holds a hundred lines or a million.
- **A core that does not depend on a framework.** React is the first adapter. Other frameworks can follow without changing the core.
- **Usable without a mouse.** Keyboard navigation, focus handling and screen reader output are part of the design, even though the text is drawn on a canvas.
- **Few dependencies.** The published package should pull in as little as possible.

## Roadmap

1. Technology research: the renderer, the data model, console hooking and value serialization
1. The core engine and the React adapter
1. Documentation and the first npm release
1. Adapters for other frameworks

## Contributing

Anyone can contribute to the project by reporting new issues or submitting a pull request. For more information, please see [CONTRIBUTING.md](CONTRIBUTING.md). Participation is subject to the [Code of Conduct](CODE_OF_CONDUCT.md).

To report a security issue, please follow the process described in [SECURITY.md](SECURITY.md).

For anything that does not belong in a public issue, write to CDGet at [cdget.com/contact](https://cdget.com/contact).

## Sponsor

lognal is free to use and maintained in the open. If it saves you time, you can support the work at [cdget.com/donate](https://cdget.com/donate) or through the Sponsor button on GitHub.

## License

Please see the [LICENSE](LICENSE) file for more information about project owners, usage rights, and more.
