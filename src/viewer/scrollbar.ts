export type ScrollbarOrientation = 'vertical' | 'horizontal';

/** The shortest a thumb gets, in CSS pixels, so it stays easy to grab. */
const MIN_THUMB_SIZE = 28;
/** How long the scrollbar stays visible after the view scrolls, in milliseconds. */
const IDLE_DELAY = 1000;

/**
 * A scrollbar drawn in the DOM for a scroll container whose own scrollbar is hidden.
 *
 * The container keeps doing the scrolling, so wheel, touch, keyboard and assistive technology
 * work as usual. This element only shows the position and lets a mouse drag the thumb or
 * click the track. It is hidden from assistive technology, which uses the container.
 */
export class Scrollbar {
	readonly element: HTMLDivElement;
	private readonly thumb: HTMLDivElement;
	private idleTimer: ReturnType<typeof setTimeout> | undefined;
	private drag: { pointerId: number; start: number; scroll: number } | null = null;

	constructor(
		ownerDocument: Document,
		private readonly orientation: ScrollbarOrientation,
		private readonly viewport: HTMLElement
	) {
		this.element = ownerDocument.createElement('div');
		this.element.className = `lognal-scrollbar lognal-scrollbar-${orientation}`;
		this.element.setAttribute('aria-hidden', 'true');
		this.thumb = ownerDocument.createElement('div');
		this.thumb.className = 'lognal-scrollbar-thumb';
		this.element.append(this.thumb);
		this.element.addEventListener('pointerdown', this.onPointerDown);
		this.element.addEventListener('pointermove', this.onPointerMove);
		this.element.addEventListener('pointerup', this.onPointerUp);
		this.element.addEventListener('pointercancel', this.onPointerUp);
	}

	/** Moves the thumb to match the container, and shows the scrollbar for a moment. */
	update(showActivity = false): void {
		const { client, total, position } = this.measure();
		const scrollable = total - client > 1;

		this.element.hidden = !scrollable;

		if (!scrollable) {
			return;
		}

		const track = this.trackSize();
		const thumbSize = Math.max(MIN_THUMB_SIZE, (client / total) * track);
		const offset = ((track - thumbSize) * position) / (total - client);

		if (this.orientation === 'vertical') {
			this.thumb.style.height = `${thumbSize}px`;
			this.thumb.style.transform = `translateY(${offset}px)`;
		} else {
			this.thumb.style.width = `${thumbSize}px`;
			this.thumb.style.transform = `translateX(${offset}px)`;
		}

		if (showActivity) {
			this.element.classList.add('is-active');
			clearTimeout(this.idleTimer);
			this.idleTimer = setTimeout(() => {
				this.element.classList.remove('is-active');
			}, IDLE_DELAY);
		}
	}

	dispose(): void {
		clearTimeout(this.idleTimer);
		this.element.remove();
	}

	private measure(): { client: number; total: number; position: number } {
		const viewport = this.viewport;

		if (this.orientation === 'vertical') {
			return {
				client: viewport.clientHeight,
				total: viewport.scrollHeight,
				position: viewport.scrollTop
			};
		}

		return {
			client: viewport.clientWidth,
			total: viewport.scrollWidth,
			position: viewport.scrollLeft
		};
	}

	private trackSize(): number {
		const rect = this.element.getBoundingClientRect();

		return this.orientation === 'vertical' ? rect.height : rect.width;
	}

	private pointerOffset(event: PointerEvent): number {
		const rect = this.element.getBoundingClientRect();

		return this.orientation === 'vertical' ? event.clientY - rect.top : event.clientX - rect.left;
	}

	private scrollTo(position: number): void {
		if (this.orientation === 'vertical') {
			this.viewport.scrollTop = position;
		} else {
			this.viewport.scrollLeft = position;
		}
	}

	private readonly onPointerDown = (event: PointerEvent): void => {
		if (event.button !== 0) {
			return;
		}

		event.preventDefault();

		const { client, total, position } = this.measure();

		if (event.target === this.thumb) {
			this.drag = {
				pointerId: event.pointerId,
				start: this.pointerOffset(event),
				scroll: position
			};

			try {
				this.element.setPointerCapture(event.pointerId);
			} catch {
				// The pointer ended before the capture could start.
			}

			this.element.classList.add('is-dragging');

			return;
		}

		const thumbRect = this.thumb.getBoundingClientRect();
		const thumbStart = this.orientation === 'vertical' ? thumbRect.top : thumbRect.left;
		const pointer = this.orientation === 'vertical' ? event.clientY : event.clientX;
		const direction = pointer < thumbStart ? -1 : 1;

		this.scrollTo(Math.max(0, Math.min(total - client, position + direction * client * 0.9)));
	};

	private readonly onPointerMove = (event: PointerEvent): void => {
		if (!this.drag || event.pointerId !== this.drag.pointerId) {
			return;
		}

		const { client, total } = this.measure();
		const track = this.trackSize();
		const thumbSize = Math.max(MIN_THUMB_SIZE, (client / total) * track);
		const movable = Math.max(1, track - thumbSize);
		const delta = this.pointerOffset(event) - this.drag.start;

		this.scrollTo(this.drag.scroll + (delta * (total - client)) / movable);
	};

	private readonly onPointerUp = (event: PointerEvent): void => {
		if (!this.drag || event.pointerId !== this.drag.pointerId) {
			return;
		}

		this.drag = null;
		this.element.classList.remove('is-dragging');

		if (this.element.hasPointerCapture(event.pointerId)) {
			this.element.releasePointerCapture(event.pointerId);
		}
	};
}
