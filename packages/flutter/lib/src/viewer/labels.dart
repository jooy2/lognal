/// Formats a number for the reader's language.
typedef NumberFormatter = String Function(int value);

/// The text of the viewer's controls. Every label is used as visible text or an
/// accessible name.
class ViewerLabels {
  /// Creates a complete set of labels.
  const ViewerLabels({
    required this.viewer,
    required this.toolbar,
    required this.follow,
    required this.clear,
    required this.scrollToTop,
    required this.scrollToBottom,
    required this.wrap,
    required this.filter,
    required this.invalidFilter,
    required this.levels,
    required this.levelAll,
    required this.levelDebug,
    required this.levelLog,
    required this.levelInfo,
    required this.levelWarn,
    required this.levelError,
    required this.levelSome,
    required this.theme,
    required this.themeAuto,
    required this.themeLight,
    required this.themePaper,
    required this.themeDark,
    required this.themeMidnight,
    required this.themeEmber,
    required this.themeMoss,
    required this.input,
    required this.inputPlaceholder,
    required this.newLogs,
    required this.entryList,
    required this.entryActions,
    required this.copyEntry,
    required this.copyEntryWithTime,
    required this.copyEntryFormatted,
    required this.copyEntryData,
    required this.expandAll,
    required this.collapseAll,
    required this.expandRepeats,
    required this.collapseRepeats,
    required this.openLink,
    required this.linkDialogTitle,
    required this.linkDialogMessage,
    required this.linkDialogOpen,
    required this.linkDialogCancel,
    required this.mute,
    required this.muteMessage,
    required this.muteEmpty,
    required this.muteText,
    required this.muteAdd,
    required this.muteRemove,
    required this.muteEnabled,
    required this.muteClose,
    required this.muteCount,
    required this.selectEntries,
    required this.selectedEntries,
    required this.search,
    required this.searchPrevious,
    required this.searchNext,
    required this.searchClose,
    required this.searchCase,
    required this.searchRegex,
    required this.searchInvalid,
    required this.searchResults,
    required this.following,
    required this.paused,
    required this.entries,
  });

  /// Accessible name of the whole viewer.
  final String viewer;

  /// Accessible name of the toolbar.
  final String toolbar;

  /// The toolbar button that follows new logs.
  final String follow;

  /// The toolbar button that removes every entry.
  final String clear;

  /// The toolbar button that jumps to the oldest entry.
  final String scrollToTop;

  /// The toolbar button that jumps to the newest entry.
  final String scrollToBottom;

  /// The toolbar button that wraps long lines.
  final String wrap;

  /// The text filter field.
  final String filter;

  /// What the filter field says while its pattern does not compile.
  final String invalidFilter;

  /// The level menu.
  final String levels;

  /// The menu item that shows every level, and the button while every level is
  /// shown.
  final String levelAll;

  /// The name of the debug level.
  final String levelDebug;

  /// The name of the log level.
  final String levelLog;

  /// The name of the info level.
  final String levelInfo;

  /// The name of the warning level.
  final String levelWarn;

  /// The name of the error level.
  final String levelError;

  /// The level button while some levels are shown and others are not.
  final String Function(int count, NumberFormatter format) levelSome;

  /// The toolbar button that opens the theme menu, and the menu itself.
  final String theme;

  /// The theme that follows the color scheme of the system.
  final String themeAuto;

  /// The name of the light palette.
  final String themeLight;

  /// The name of the paper palette.
  final String themePaper;

  /// The name of the dark palette.
  final String themeDark;

  /// The name of the midnight palette.
  final String themeMidnight;

  /// The name of the ember palette.
  final String themeEmber;

  /// The name of the moss palette.
  final String themeMoss;

  /// Accessible name of the input line.
  final String input;

  /// The hint inside the input line.
  final String inputPlaceholder;

  /// The button that appears when new entries arrive while the view is scrolled
  /// up.
  final String newLogs;

  /// Accessible name of the list that mirrors the visible entries.
  final String entryList;

  /// The button at the end of the entry under the pointer, and the menu it
  /// opens.
  final String entryActions;

  /// The menu item that copies the text of an entry.
  final String copyEntry;

  /// The menu item that copies the text of an entry after its timestamp.
  final String copyEntryWithTime;

  /// The menu item that copies an entry over several lines.
  final String copyEntryFormatted;

  /// The menu item that copies the values of an entry as JSON.
  final String copyEntryData;

  /// The menu item that expands every value of an entry.
  final String expandAll;

  /// The menu item that collapses every value of an entry.
  final String collapseAll;

  /// The menu item that shows the messages that repeat the first entry of a run.
  final String expandRepeats;

  /// The menu item that hides them again.
  final String collapseRepeats;

  /// The menu item that opens a link of an entry.
  final String Function(String url) openLink;

  /// The title of the dialog that asks before a link opens.
  final String linkDialogTitle;

  /// The sentence under the title of the link dialog.
  final String linkDialogMessage;

  /// The button of the link dialog that opens the link.
  final String linkDialogOpen;

  /// The button of the link dialog that closes it without opening the link.
  final String linkDialogCancel;

  /// The toolbar button that opens the dialog of hidden messages, and the title
  /// of the dialog.
  final String mute;

  /// The sentence under the title of that dialog.
  final String muteMessage;

  /// What the dialog says while no rule is set.
  final String muteEmpty;

  /// The field of a rule, and the field that adds one.
  final String muteText;

  /// The button that adds a rule.
  final String muteAdd;

  /// The button that removes a rule.
  final String muteRemove;

  /// The switch that applies a rule or leaves it out without removing it.
  final String muteEnabled;

  /// The button that closes the dialog.
  final String muteClose;

  /// How many entries the mute rules hide, on the toolbar button.
  final String Function(int count, NumberFormatter format) muteCount;

  /// The toolbar button that switches between selecting text and selecting whole
  /// entries.
  final String selectEntries;

  /// The number of selected entries in entry mode.
  final String Function(int count, NumberFormatter format) selectedEntries;

  /// Accessible name of the search bar, and the hint inside its field.
  final String search;

  /// The button that moves to the previous match.
  final String searchPrevious;

  /// The button that moves to the next match.
  final String searchNext;

  /// The button that closes the search bar.
  final String searchClose;

  /// The toggle that makes the search match letter case.
  final String searchCase;

  /// The toggle that makes the search text a regular expression.
  final String searchRegex;

  /// What the search field says while its regular expression does not compile.
  final String searchInvalid;

  /// The position of the current match among all matches, such as `3/12`.
  /// `current` is 0 while no match is current.
  final String Function(int current, int total, NumberFormatter format) searchResults;

  /// What the status bar says while the view follows new entries.
  final String following;

  /// What it says while it does not.
  final String paused;

  /// The entry count in the status bar.
  final String Function(int shown, int total, NumberFormatter format) entries;

  /// A copy with the labels given here replaced.
  ViewerLabels copyWith({
    String? viewer,
    String? toolbar,
    String? follow,
    String? clear,
    String? scrollToTop,
    String? scrollToBottom,
    String? wrap,
    String? filter,
    String? invalidFilter,
    String? levels,
    String? levelAll,
    String? levelDebug,
    String? levelLog,
    String? levelInfo,
    String? levelWarn,
    String? levelError,
    String Function(int count, NumberFormatter format)? levelSome,
    String? theme,
    String? themeAuto,
    String? themeLight,
    String? themePaper,
    String? themeDark,
    String? themeMidnight,
    String? themeEmber,
    String? themeMoss,
    String? input,
    String? inputPlaceholder,
    String? newLogs,
    String? entryList,
    String? entryActions,
    String? copyEntry,
    String? copyEntryWithTime,
    String? copyEntryFormatted,
    String? copyEntryData,
    String? expandAll,
    String? collapseAll,
    String? expandRepeats,
    String? collapseRepeats,
    String Function(String url)? openLink,
    String? linkDialogTitle,
    String? linkDialogMessage,
    String? linkDialogOpen,
    String? linkDialogCancel,
    String? mute,
    String? muteMessage,
    String? muteEmpty,
    String? muteText,
    String? muteAdd,
    String? muteRemove,
    String? muteEnabled,
    String? muteClose,
    String Function(int count, NumberFormatter format)? muteCount,
    String? selectEntries,
    String Function(int count, NumberFormatter format)? selectedEntries,
    String? search,
    String? searchPrevious,
    String? searchNext,
    String? searchClose,
    String? searchCase,
    String? searchRegex,
    String? searchInvalid,
    String Function(int current, int total, NumberFormatter format)? searchResults,
    String? following,
    String? paused,
    String Function(int shown, int total, NumberFormatter format)? entries,
  }) {
    return ViewerLabels(
      viewer: viewer ?? this.viewer,
      toolbar: toolbar ?? this.toolbar,
      follow: follow ?? this.follow,
      clear: clear ?? this.clear,
      scrollToTop: scrollToTop ?? this.scrollToTop,
      scrollToBottom: scrollToBottom ?? this.scrollToBottom,
      wrap: wrap ?? this.wrap,
      filter: filter ?? this.filter,
      invalidFilter: invalidFilter ?? this.invalidFilter,
      levels: levels ?? this.levels,
      levelAll: levelAll ?? this.levelAll,
      levelDebug: levelDebug ?? this.levelDebug,
      levelLog: levelLog ?? this.levelLog,
      levelInfo: levelInfo ?? this.levelInfo,
      levelWarn: levelWarn ?? this.levelWarn,
      levelError: levelError ?? this.levelError,
      levelSome: levelSome ?? this.levelSome,
      theme: theme ?? this.theme,
      themeAuto: themeAuto ?? this.themeAuto,
      themeLight: themeLight ?? this.themeLight,
      themePaper: themePaper ?? this.themePaper,
      themeDark: themeDark ?? this.themeDark,
      themeMidnight: themeMidnight ?? this.themeMidnight,
      themeEmber: themeEmber ?? this.themeEmber,
      themeMoss: themeMoss ?? this.themeMoss,
      input: input ?? this.input,
      inputPlaceholder: inputPlaceholder ?? this.inputPlaceholder,
      newLogs: newLogs ?? this.newLogs,
      entryList: entryList ?? this.entryList,
      entryActions: entryActions ?? this.entryActions,
      copyEntry: copyEntry ?? this.copyEntry,
      copyEntryWithTime: copyEntryWithTime ?? this.copyEntryWithTime,
      copyEntryFormatted: copyEntryFormatted ?? this.copyEntryFormatted,
      copyEntryData: copyEntryData ?? this.copyEntryData,
      expandAll: expandAll ?? this.expandAll,
      collapseAll: collapseAll ?? this.collapseAll,
      expandRepeats: expandRepeats ?? this.expandRepeats,
      collapseRepeats: collapseRepeats ?? this.collapseRepeats,
      openLink: openLink ?? this.openLink,
      linkDialogTitle: linkDialogTitle ?? this.linkDialogTitle,
      linkDialogMessage: linkDialogMessage ?? this.linkDialogMessage,
      linkDialogOpen: linkDialogOpen ?? this.linkDialogOpen,
      linkDialogCancel: linkDialogCancel ?? this.linkDialogCancel,
      mute: mute ?? this.mute,
      muteMessage: muteMessage ?? this.muteMessage,
      muteEmpty: muteEmpty ?? this.muteEmpty,
      muteText: muteText ?? this.muteText,
      muteAdd: muteAdd ?? this.muteAdd,
      muteRemove: muteRemove ?? this.muteRemove,
      muteEnabled: muteEnabled ?? this.muteEnabled,
      muteClose: muteClose ?? this.muteClose,
      muteCount: muteCount ?? this.muteCount,
      selectEntries: selectEntries ?? this.selectEntries,
      selectedEntries: selectedEntries ?? this.selectedEntries,
      search: search ?? this.search,
      searchPrevious: searchPrevious ?? this.searchPrevious,
      searchNext: searchNext ?? this.searchNext,
      searchClose: searchClose ?? this.searchClose,
      searchCase: searchCase ?? this.searchCase,
      searchRegex: searchRegex ?? this.searchRegex,
      searchInvalid: searchInvalid ?? this.searchInvalid,
      searchResults: searchResults ?? this.searchResults,
      following: following ?? this.following,
      paused: paused ?? this.paused,
      entries: entries ?? this.entries,
    );
  }
}

/// The English labels.
final ViewerLabels enLabels = ViewerLabels(
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
  levelDebug: 'Debug',
  levelLog: 'Log',
  levelInfo: 'Info',
  levelWarn: 'Warning',
  levelError: 'Error',
  levelSome: (int count, NumberFormatter format) => '${format(count)} levels',
  theme: 'Theme',
  themeAuto: 'System',
  themeLight: 'Light',
  themePaper: 'Paper',
  themeDark: 'Dark',
  themeMidnight: 'Midnight',
  themeEmber: 'Ember',
  themeMoss: 'Moss',
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
  expandRepeats: 'Show repeats',
  collapseRepeats: 'Hide repeats',
  openLink: (String url) => 'Open $url',
  linkDialogTitle: 'Open this link?',
  linkDialogMessage: 'The link opens outside the app. Check the address before you open it.',
  linkDialogOpen: 'Open link',
  linkDialogCancel: 'Cancel',
  mute: 'Hidden messages',
  muteMessage: 'An entry that matches one of these is kept out of the log.',
  muteEmpty: 'Nothing is hidden yet.',
  muteText: 'Text to hide',
  muteAdd: 'Add',
  muteRemove: 'Remove',
  muteEnabled: 'Apply this rule',
  muteClose: 'Done',
  muteCount: (int count, NumberFormatter format) =>
      count == 1 ? '1 entry hidden' : '${format(count)} entries hidden',
  selectEntries: 'Select whole entries',
  selectedEntries: (int count, NumberFormatter format) =>
      count == 1 ? '1 entry selected' : '${format(count)} entries selected',
  search: 'Find in log',
  searchPrevious: 'Previous match',
  searchNext: 'Next match',
  searchClose: 'Close search',
  searchCase: 'Match case',
  searchRegex: 'Use regular expression',
  searchInvalid: 'Not a valid regular expression',
  searchResults: (int current, int total, NumberFormatter format) =>
      total == 0 ? 'No results' : '${format(current)}/${format(total)}',
  following: 'Following',
  paused: 'Paused',
  entries: (int shown, int total, NumberFormatter format) {
    final String noun = total == 1 ? 'entry' : 'entries';

    return shown == total ? '${format(total)} $noun' : '${format(shown)} of ${format(total)} $noun';
  },
);

/// The Korean labels.
final ViewerLabels koLabels = ViewerLabels(
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
  levelDebug: '디버그',
  levelLog: '로그',
  levelInfo: '정보',
  levelWarn: '경고',
  levelError: '오류',
  levelSome: (int count, NumberFormatter format) => '수준 ${format(count)}개',
  theme: '테마',
  themeAuto: '시스템',
  themeLight: '라이트',
  themePaper: '페이퍼',
  themeDark: '다크',
  themeMidnight: '미드나이트',
  themeEmber: '엠버',
  themeMoss: '모스',
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
  expandRepeats: '반복 펼치기',
  collapseRepeats: '반복 접기',
  openLink: (String url) => '링크 열기: $url',
  linkDialogTitle: '이 링크를 열까요?',
  linkDialogMessage: '링크는 앱 밖에서 열립니다. 열기 전에 주소를 확인하세요.',
  linkDialogOpen: '링크 열기',
  linkDialogCancel: '취소',
  mute: '숨긴 메시지',
  muteMessage: '여기에 해당하는 항목은 로그에 나오지 않습니다.',
  muteEmpty: '아직 숨긴 메시지가 없습니다.',
  muteText: '숨길 텍스트',
  muteAdd: '추가',
  muteRemove: '삭제',
  muteEnabled: '이 규칙 적용',
  muteClose: '완료',
  muteCount: (int count, NumberFormatter format) => '항목 ${format(count)}개 숨김',
  selectEntries: '항목 단위로 선택',
  selectedEntries: (int count, NumberFormatter format) => '항목 ${format(count)}개 선택됨',
  search: '로그에서 찾기',
  searchPrevious: '이전 결과',
  searchNext: '다음 결과',
  searchClose: '검색 닫기',
  searchCase: '대소문자 구분',
  searchRegex: '정규 표현식 사용',
  searchInvalid: '올바른 정규 표현식이 아닙니다',
  searchResults: (int current, int total, NumberFormatter format) =>
      total == 0 ? '결과 없음' : '${format(current)}/${format(total)}',
  following: '따라가는 중',
  paused: '멈춤',
  entries: (int shown, int total, NumberFormatter format) =>
      shown == total ? '로그 ${format(total)}개' : '로그 ${format(total)}개 중 ${format(shown)}개',
);

/// Returns the built-in labels for a language tag. English is used for any other
/// language.
ViewerLabels labelsFor(String? locale) {
  return locale != null && RegExp(r'^ko\b', caseSensitive: false).hasMatch(locale)
      ? koLabels
      : enLabels;
}

/// Writes a number with a separator every three digits.
///
/// It is not a locale-aware formatter: `package:intl` is a dependency this
/// package does not take, and a comma every three digits is what both languages
/// this ships labels for actually write. Pass your own through
/// `LogViewerOptions.formatNumber` where a locale needs something else.
String formatCount(int value) {
  final String digits = value.abs().toString();
  final StringBuffer text = StringBuffer(value < 0 ? '-' : '');

  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      text.write(',');
    }

    text.write(digits[index]);
  }

  return text.toString();
}
