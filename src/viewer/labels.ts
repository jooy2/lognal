/** The text of the viewer's controls. Every label is used as visible text or an accessible name. */
export interface ViewerLabels {
	/** Accessible name of the whole viewer. */
	viewer: string;
	/** Accessible name of the toolbar. */
	toolbar: string;
	follow: string;
	clear: string;
	scrollToTop: string;
	scrollToBottom: string;
	wrap: string;
	filter: string;
	invalidFilter: string;
	levels: string;
	levelAll: string;
	levelLog: string;
	levelInfo: string;
	levelWarn: string;
	levelError: string;
	/** Accessible name of the input line. */
	input: string;
	inputPlaceholder: string;
	/** The button that appears when new entries arrive while the view is scrolled up. */
	newLogs: string;
	/** Accessible name of the list that mirrors the visible entries for screen readers. */
	entryList: string;
	following: string;
	paused: string;
	/** The entry count in the status bar. `format` formats a number for the locale. */
	entries: (shown: number, total: number, format: (value: number) => string) => string;
}

export const EN_LABELS: ViewerLabels = {
	viewer: 'Log viewer',
	toolbar: 'Log viewer tools',
	follow: 'Follow new logs',
	clear: 'Clear logs',
	scrollToTop: 'Scroll to top',
	scrollToBottom: 'Scroll to bottom',
	wrap: 'Wrap long lines',
	filter: 'Filter',
	invalidFilter: 'The filter is not a valid pattern',
	levels: 'Log levels',
	levelAll: 'All levels',
	levelLog: 'Log and above',
	levelInfo: 'Info and above',
	levelWarn: 'Warnings and errors',
	levelError: 'Errors only',
	input: 'Command',
	inputPlaceholder: 'Type a command',
	newLogs: 'New logs',
	entryList: 'Visible log entries',
	following: 'Following',
	paused: 'Paused',
	entries: (shown, total, format) => {
		const noun = total === 1 ? 'entry' : 'entries';

		return shown === total
			? `${format(total)} ${noun}`
			: `${format(shown)} of ${format(total)} ${noun}`;
	}
};

export const KO_LABELS: ViewerLabels = {
	viewer: '로그 뷰어',
	toolbar: '로그 뷰어 도구',
	follow: '새 로그 따라가기',
	clear: '로그 지우기',
	scrollToTop: '맨 위로 이동',
	scrollToBottom: '맨 아래로 이동',
	wrap: '긴 줄 바꾸기',
	filter: '필터',
	invalidFilter: '필터 패턴이 올바르지 않습니다',
	levels: '로그 수준',
	levelAll: '모든 수준',
	levelLog: '로그 이상',
	levelInfo: '정보 이상',
	levelWarn: '경고와 오류',
	levelError: '오류만',
	input: '명령',
	inputPlaceholder: '명령을 입력하세요',
	newLogs: '새 로그',
	entryList: '화면에 보이는 로그',
	following: '따라가는 중',
	paused: '멈춤',
	entries: (shown, total, format) => {
		return shown === total
			? `로그 ${format(total)}개`
			: `로그 ${format(total)}개 중 ${format(shown)}개`;
	}
};

/** Returns the built-in labels for a language tag. English is used for any other language. */
export const labelsFor = (locale: string | undefined): ViewerLabels => {
	return locale && /^ko\b/i.test(locale) ? KO_LABELS : EN_LABELS;
};
