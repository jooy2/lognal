import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/layout/search.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/labels.dart';

/// The bar that finds text in the log without hiding anything.
class LognalSearchBar extends StatefulWidget {
  /// Creates the search bar.
  const LognalSearchBar({
    required this.controller,
    required this.theme,
    required this.labels,
    super.key,
  });

  /// The viewer's state.
  final LogViewerController controller;

  /// The palette it is drawn from.
  final LognalTheme theme;

  /// The text of its controls.
  final ViewerLabels labels;

  @override
  State<LognalSearchBar> createState() => _LognalSearchBarState();
}

class _LognalSearchBarState extends State<LognalSearchBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'lognal search');

  @override
  void initState() {
    super.initState();
    _text.text = widget.controller.search.query;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply({bool? caseSensitive, bool? regex}) {
    final SearchOptions current = widget.controller.search.options;

    widget.controller.setSearchQuery(
      _text.text,
      SearchOptions(
        caseSensitive: caseSensitive ?? current.caseSensitive,
        regex: regex ?? current.regex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChromeTheme chrome = widget.theme.chrome;
    final ViewerLabels labels = widget.labels;
    final LogSearch search = widget.controller.search;
    final SearchOptions options = search.options;
    final bool tooltips = widget.controller.options.tooltips;
    final String results = labels.searchResults(
      search.current + 1 > search.count ? 0 : search.current + 1,
      search.count,
      widget.controller.options.formatNumber,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chrome.surface,
        border: Border(bottom: BorderSide(color: chrome.border)),
      ),
      child: Semantics(
        container: true,
        label: labels.search,
        child: Row(
          spacing: controlGap,
          children: <Widget>[
            Expanded(
              child: LognalField(
                controller: _text,
                focusNode: _focus,
                theme: chrome,
                hint: labels.search,
                icon: LognalIcon.search,
                autofocus: true,
                invalid: search.error != null,
                onChanged: (String _) => _apply(),
                onSubmitted: (String _) => widget.controller.findNext(),
              ),
            ),
            const SizedBox(width: 6 - controlGap),
            LognalButton(
              icon: LognalIcon.matchCase,
              label: labels.searchCase,
              theme: chrome,
              tooltips: tooltips,
              pressed: options.caseSensitive,
              onPressed: () => _apply(caseSensitive: !options.caseSensitive),
            ),
            LognalButton(
              icon: LognalIcon.regex,
              label: labels.searchRegex,
              theme: chrome,
              tooltips: tooltips,
              pressed: options.regex,
              onPressed: () => _apply(regex: !options.regex),
            ),
            const SizedBox(width: 6 - controlGap),
            SizedBox(
              width: 72,
              child: LognalText(
                search.error != null ? labels.searchInvalid : results,
                color: chrome.muted,
                size: 11,
              ),
            ),
            LognalButton(
              icon: LognalIcon.chevronUp,
              label: labels.searchPrevious,
              theme: chrome,
              tooltips: tooltips,
              onPressed: widget.controller.findPrevious,
            ),
            LognalButton(
              icon: LognalIcon.chevronDown,
              label: labels.searchNext,
              theme: chrome,
              tooltips: tooltips,
              onPressed: widget.controller.findNext,
            ),
            LognalButton(
              icon: LognalIcon.close,
              label: labels.searchClose,
              theme: chrome,
              tooltips: tooltips,
              onPressed: widget.controller.closeSearch,
            ),
          ],
        ),
      ),
    );
  }
}
