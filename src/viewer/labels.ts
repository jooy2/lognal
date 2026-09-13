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
	/** The button at the end of the entry under the pointer, and the menu it opens. */
	entryActions: string;
	/** The menu item that copies the text of an entry. */
	copyEntry: string;
	/** The menu item that copies the text of an entry after its timestamp. */
	copyEntryWithTime: string;
	/** The menu item that copies an entry over several lines, with colors for rich text. */
	copyEntryFormatted: string;
	/** The menu item that copies the values of an entry as JSON. */
	copyEntryData: string;
	/** The menu item that expands every value of an entry. */
	expandAll: string;
	/** The menu item that collapses every value of an entry. */
	collapseAll: string;
	/** Accessible name of the search bar, and the placeholder of its field. */
	search: string;
	searchPrevious: string;
	searchNext: string;
	searchClose: string;
	/**
	 * The position of the current match among all matches, such as `3/12`. `current` is 0 while
	 * no match is current. `format` formats a number for the locale.
	 */
	searchResults: (current: number, total: number, format: (value: number) => string) => string;
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
	entryActions: 'Entry actions',
	copyEntry: 'Copy as text',
	copyEntryWithTime: 'Copy with timestamp',
	copyEntryFormatted: 'Copy as formatted text',
	copyEntryData: 'Copy as data',
	expandAll: 'Expand all',
	collapseAll: 'Collapse all',
	search: 'Find in log',
	searchPrevious: 'Previous match',
	searchNext: 'Next match',
	searchClose: 'Close search',
	searchResults: (current, total, format) => {
		return total === 0 ? 'No results' : `${format(current)}/${format(total)}`;
	},
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
	entryActions: '항목 작업',
	copyEntry: '텍스트로 복사',
	copyEntryWithTime: '타임스탬프와 함께 복사',
	copyEntryFormatted: '서식 있는 텍스트로 복사',
	copyEntryData: '데이터로 복사',
	expandAll: '모두 펼치기',
	collapseAll: '모두 접기',
	search: '로그에서 찾기',
	searchPrevious: '이전 결과',
	searchNext: '다음 결과',
	searchClose: '검색 닫기',
	searchResults: (current, total, format) => {
		return total === 0 ? '결과 없음' : `${format(current)}/${format(total)}`;
	},
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
