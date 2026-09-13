/** How the timestamp of an entry is written. */
export type TimestampFormat = 'time' | 'datetime' | 'iso' | ((time: number) => string);

const pad = (value: number, length = 2): string => {
	return String(value).padStart(length, '0');
};

/**
 * Formats an epoch time in local time.
 *
 * - `time`: `14:03:09.120`
 * - `datetime`: `2026-09-13 14:03:09.120`
 * - `iso`: `2026-09-13T05:03:09.120Z`, in UTC
 */
export const formatTimestamp = (time: number, format: TimestampFormat = 'time'): string => {
	if (typeof format === 'function') {
		return format(time);
	}

	const date = new Date(time);

	if (format === 'iso') {
		return date.toISOString();
	}

	const clock = `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;

	if (format === 'datetime') {
		return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${clock}`;
	}

	return clock;
};
