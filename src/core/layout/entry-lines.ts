import { errorTitle, formatKey, isExpandable, previewValue } from '../value/preview.js';
import type { LogEntry, ValueEntry, ValueNode } from '../types.js';
import type { LineSpan, LineTextSpan, LogicalLine } from './types.js';

/** Cells of indentation for every level of nesting. */
export const INDENT_CELLS = 2;

/** Decides whether the value at a path is shown expanded. */
export type ExpansionLookup = (path: string) => boolean;

/**
 * Returns whether a value path is expanded when the user has not toggled it: errors logged
 * directly are open, so their stack trace is visible, and everything else is closed.
 */
export const isExpandedByDefault = (entry: LogEntry, path: string): boolean => {
	if (path.includes('.')) {
		return false;
	}

	const part = entry.parts[Number(path)];

	return part?.type === 'value' && part.value.kind === 'error';
};

const errorSpans = (node: ValueNode): LineTextSpan[] => {
	return [{ text: errorTitle(node), token: 'error' }];
};

const expanderSpan = (path: string, expanded: boolean): LineSpan => {
	return { icon: 'expander', expanded, action: { type: 'toggle-value', path } };
};

const childLines = (
	node: ValueNode,
	path: string,
	indent: number,
	isExpanded: ExpansionLookup,
	lines: LogicalLine[]
): void => {
	// Rows without an expander start two cells in, so their text lines up with the text of
	// the rows that have one.
	const textIndent = indent + INDENT_CELLS;

	if (node.kind === 'error' && node.stack) {
		for (const stackLine of node.stack.split('\n')) {
			lines.push({ indent: textIndent, spans: [{ text: stackLine.trim(), token: 'muted' }] });
		}
	}

	node.children?.forEach((child, index) => {
		childLine(node, child, `${path}.${index}`, indent, isExpanded, lines);
	});

	if ((node.omitted ?? 0) > 0) {
		lines.push({ indent: textIndent, spans: [{ text: `… ${node.omitted} more`, token: 'muted' }] });
	}

	if (node.kind === 'element' && node.value) {
		lines.push({ indent, spans: [{ text: `</${node.value}>`, token: 'tag' }] });
	}
};

const childLine = (
	parent: ValueNode,
	child: ValueEntry,
	path: string,
	indent: number,
	isExpanded: ExpansionLookup,
	lines: LogicalLine[]
): void => {
	const expandable = isExpandable(child.value);
	const expanded = expandable && isExpanded(path);
	const spans: LineSpan[] = [];

	if (expandable) {
		spans.push(expanderSpan(path, expanded));
	}

	if (parent.kind === 'map' && child.keyValue) {
		spans.push(...previewValue(child.keyValue, true), { text: ' => ', token: 'default' });
	} else if (child.key !== undefined && parent.kind !== 'set' && parent.kind !== 'element') {
		spans.push(formatKey(child), { text: ': ', token: 'default' });
	}

	const action = { type: 'toggle-value' as const, path };
	const valueSpans =
		child.value.kind === 'error' ? errorSpans(child.value) : previewValue(child.value);

	spans.push(...valueSpans.map((span) => (expandable ? { ...span, action } : span)));
	lines.push({ indent: expandable ? indent : indent + INDENT_CELLS, spans });

	if (expanded) {
		childLines(child.value, path, indent + INDENT_CELLS, isExpanded, lines);
	}
};

/**
 * Builds the logical lines of an entry: one for every line of its text, followed by the rows
 * of every expanded value in the order the values appear.
 */
export const buildEntryLines = (entry: LogEntry, isExpanded: ExpansionLookup): LogicalLine[] => {
	const baseIndent = entry.groups.length * INDENT_CELLS;
	const lines: LogicalLine[] = [];
	let current: LineSpan[] = [];
	let currentWraps = true;
	const expandedParts: { node: ValueNode; path: string }[] = [];

	if (entry.kind === 'group') {
		current.push({
			icon: 'expander',
			expanded: !entry.collapsed,
			action: { type: 'toggle-group' }
		});
	}

	entry.parts.forEach((part, index) => {
		if (part.type === 'text') {
			const pieces = part.text.split('\n');

			pieces.forEach((piece, pieceIndex) => {
				if (pieceIndex > 0) {
					lines.push({ indent: baseIndent, spans: current, wrap: currentWraps });
					current = [];
					currentWraps = true;
				}

				if (part.wrap === false) {
					currentWraps = false;
				}

				if (piece) {
					current.push({
						text: piece,
						token: part.token,
						style: part.style,
						...(entry.kind === 'group' ? { action: { type: 'toggle-group' as const } } : {})
					});
				}
			});

			return;
		}

		const node = part.value;
		const path = String(index);

		if (!isExpandable(node)) {
			current.push(...previewValue(node));

			return;
		}

		const expanded = isExpanded(path);
		const action = { type: 'toggle-value' as const, path };
		const title = node.kind === 'error' ? errorSpans(node) : previewValue(node);

		current.push(expanderSpan(path, expanded), ...title.map((span) => ({ ...span, action })));

		if (expanded) {
			expandedParts.push({ node, path });
		}
	});

	lines.push({ indent: baseIndent, spans: current, wrap: currentWraps });

	for (const { node, path } of expandedParts) {
		childLines(node, path, baseIndent + INDENT_CELLS, isExpanded, lines);
	}

	return lines;
};
