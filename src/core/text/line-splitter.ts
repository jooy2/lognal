/**
 * Splits a stream of text chunks into lines.
 *
 * A line ends at `\n`, `\r\n` or a lone `\r`. A `\r\n` pair split across two chunks still
 * counts as one line break.
 */
export class LineSplitter {
	private pending = '';
	private skipLineFeed = false;

	/** Adds a chunk and returns the lines it completed. */
	push(chunk: string): string[] {
		const lines: string[] = [];
		let start = 0;
		let index = 0;

		if (this.skipLineFeed && chunk.charCodeAt(0) === 0x0a) {
			start = 1;
			index = 1;
		}

		this.skipLineFeed = false;

		for (; index < chunk.length; index++) {
			const code = chunk.charCodeAt(index);

			if (code !== 0x0a && code !== 0x0d) {
				continue;
			}

			lines.push(this.pending + chunk.slice(start, index));
			this.pending = '';

			if (code === 0x0d) {
				if (index + 1 === chunk.length) {
					this.skipLineFeed = true;
				} else if (chunk.charCodeAt(index + 1) === 0x0a) {
					index++;
				}
			}

			start = index + 1;
		}

		this.pending += chunk.slice(start);

		return lines;
	}

	/** Returns the unfinished last line, if any, and resets the splitter. */
	flush(): string[] {
		const rest = this.pending;

		this.pending = '';
		this.skipLineFeed = false;

		return rest ? [rest] : [];
	}

	/** Whether text is waiting for a line break. */
	get hasPending(): boolean {
		return this.pending.length > 0;
	}
}

/** Splits a whole string into lines. A trailing line break does not add an empty line. */
export const splitLines = (text: string): string[] => {
	const splitter = new LineSplitter();

	return [...splitter.push(text), ...splitter.flush()];
};
