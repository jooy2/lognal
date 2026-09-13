const SVG_NAMESPACE = 'http://www.w3.org/2000/svg';

/** Path data for the toolbar icons, drawn on a 16 by 16 grid with a 1.5 stroke. */
const ICON_PATHS = {
	follow: 'M8 2.75v7.5M4.75 7 8 10.25 11.25 7M3.5 13.25h9',
	clear: 'M8 2.75a5.25 5.25 0 1 0 0 10.5 5.25 5.25 0 0 0 0-10.5ZM4.3 11.7l7.4-7.4',
	top: 'M3.5 2.75h9M8 13.25v-7.5M4.75 9 8 5.75 11.25 9',
	bottom: 'M3.5 13.25h9M8 2.75v7.5M4.75 7 8 10.25 11.25 7',
	wrap: 'M2.75 4h10.5M2.75 8h8.5a2 2 0 0 1 0 4H8.5M10 10.5 8.5 12l1.5 1.5M2.75 12h3',
	search: 'M7 2.75a4.25 4.25 0 1 0 0 8.5 4.25 4.25 0 0 0 0-8.5ZM10.25 10.25l3 3',
	arrowDown: 'M8 3.25v9.5M4.25 9 8 12.75 11.75 9'
} as const;

export type IconName = keyof typeof ICON_PATHS;

/** Creates an inline SVG icon. Icons are decorative; the control around them carries the name. */
export const createIcon = (ownerDocument: Document, name: IconName): SVGSVGElement => {
	const svg = ownerDocument.createElementNS(SVG_NAMESPACE, 'svg');
	const path = ownerDocument.createElementNS(SVG_NAMESPACE, 'path');

	svg.setAttribute('viewBox', '0 0 16 16');
	svg.setAttribute('width', '16');
	svg.setAttribute('height', '16');
	svg.setAttribute('fill', 'none');
	svg.setAttribute('aria-hidden', 'true');
	svg.setAttribute('focusable', 'false');
	svg.classList.add('lognal-icon');
	path.setAttribute('d', ICON_PATHS[name]);
	path.setAttribute('stroke', 'currentColor');
	path.setAttribute('stroke-width', '1.5');
	path.setAttribute('stroke-linecap', 'round');
	path.setAttribute('stroke-linejoin', 'round');
	svg.append(path);

	return svg;
};
