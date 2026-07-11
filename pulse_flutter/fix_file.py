import re

with open('lib/screens/chat_list_screen.dart', 'r') as f:
    text = f.read()

# 1. Add imports
imports = """import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_field.dart';
"""
text = text.replace("import 'package:pulse_flutter/widgets/pulse_skeleton.dart';", "import 'package:pulse_flutter/widgets/pulse_skeleton.dart';\n" + imports)

# 2. Remove _ChatFilter
text = re.sub(r"enum _ChatFilter \{ all, unread, groups, channels, direct, bots \}\n\n", "", text)

# 3. Remove search/filter state in _ChatListScreenState
state_vars = """  final SearchController _searchController = SearchController();
  late final TabController _filterController;
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;
  Timer? _searchDebounce;"""
text = text.replace(state_vars, "")

# 4. Remove TabController init from initState
init_state_tab = """    _filterController = TabController(
      length: _ChatFilter.values.length,
      vsync: this,
    );
"""
text = text.replace(init_state_tab, "")

# 5. Remove dispose items
dispose_items = """    _searchDebounce?.cancel();
    _filterController.dispose();
    ref.read(chatListSearchProvider.notifier).clear();
    _searchController.dispose();
"""
text = text.replace(dispose_items, "")

# 6. Apply filter should use ChatFilter
text = text.replace("_ChatFilter", "ChatFilter")

# 7. Build method variables
build_vars_old = """    final String query = _query.trim();
    final AsyncValue<ApiSearchResult> searchAsync = query.isEmpty
        ? const AsyncValue<ApiSearchResult>.data(ApiSearchResult.empty())
        : ref.watch(chatListSearchProvider);"""

build_vars_new = """    final AsyncValue<ApiSearchResult> searchAsync = ref.watch(chatListSearchProvider);
    final filter = ref.watch(chatFilterProvider);"""
text = text.replace(build_vars_old, build_vars_new)

# 8. Replace AppBar
appbar_old = r"""      appBar: AppBar\(
        title: ClipRRect\(
          borderRadius: BorderRadius.circular\(20\),
          child: optimize
              \? Container\(
                  padding: const EdgeInsets.symmetric\(horizontal: 16, vertical: 8\),
                  color: scheme.surface.withValues\(alpha: 0.95\),
                  child: Text\(context.l10n.tabChats\),
                \)
              : BackdropFilter\(
                  filter: ImageFilter.blur\(sigmaX: 10, sigmaY: 10\),
                  child: Container\(
                    padding: const EdgeInsets.symmetric\(horizontal: 16, vertical: 8\),
                    color: scheme.surface.withValues\(alpha: 0.6\),
                    child: Text\(context.l10n.tabChats\),
                  \),
                \),
        \),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: <Widget>\[
          IconButton\(
            onPressed: \(\) => _showCreateMenu\(context\),
            tooltip: context.l10n.groupCreateOrJoin,
            icon: const Icon\(Icons.add_circle_outline_rounded\),
          \),
          const SizedBox\(width: 8\),
        \],
      \),"""
appbar_new = """      appBar: ChatListHeader(
        onCreatePressed: () => _showCreateMenu(context),
      ),"""
text = re.sub(appbar_old, appbar_new, text, flags=re.MULTILINE)

# 9. Replace searchAndFilter
search_and_filter_old = """                      _searchAndFilter(scheme, textTheme, searchAsync),"""
search_and_filter_new = """                      const ChatSearchField(),
                      const SizedBox(height: 10),
                      const ChatListFilterBar(),"""
text = text.replace(search_and_filter_old, search_and_filter_new)

# 10. Fix _buildChatSlivers call in build
build_slivers_old = """              ..._buildChatSlivers(
                auth,
                chatsAsync,
                compact,
                scheme,
                textTheme,
                searchAsync.asData?.value,
              ),"""
build_slivers_new = """              ..._buildChatSlivers(
                auth,
                chatsAsync,
                compact,
                scheme,
                textTheme,
                searchAsync.asData?.value,
                filter,
              ),"""
text = text.replace(build_slivers_old, build_slivers_new)

# Also fix the inner recursive calls in error and loading
error_loading_slivers_old = """          return _buildChatSlivers(
            auth,
            AsyncValue.data(chatsAsync.value!),
            compact,
            scheme,
            textTheme,
            searchResult,
          );"""
error_loading_slivers_new = """          return _buildChatSlivers(
            auth,
            AsyncValue.data(chatsAsync.value!),
            compact,
            scheme,
            textTheme,
            searchResult,
            filter,
          );"""
text = text.replace(error_loading_slivers_old, error_loading_slivers_new)

# 11. Fix _buildChatSlivers definition
def_slivers_old = """  List<Widget> _buildChatSlivers(
    AuthState auth,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    TextTheme textTheme,
    ApiSearchResult? searchResult,
  ) {"""
def_slivers_new = """  List<Widget> _buildChatSlivers(
    AuthState auth,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    TextTheme textTheme,
    ApiSearchResult? searchResult,
    ChatFilter filter,
  ) {"""
text = text.replace(def_slivers_old, def_slivers_new)

# 12. Fix filter logic in _buildChatSlivers
filter_old = """        final List<ApiChatSummary> filtered = _applyFilter(chats, _filter);"""
filter_new = """        final List<ApiChatSummary> filtered = _applyFilter(chats, filter);"""
text = text.replace(filter_old, filter_new)

# 13. Fix query logic in _buildChatSlivers
query_logic_old = r"""        final String query = _query.trim().toLowerCase();
        final Set<int> resultChatIds = <int>{
          ...?searchResult?.chats.map((ApiSearchChat chat) => chat.id),
          ...?searchResult?.messages.map(
            (ApiSearchMessage message) => message.chatId,
          ),
        };
        final List<ApiChatSummary> searched = filtered
            .where((ApiChatSummary chat) {
              if (query.isEmpty) return true;
              return chat.name.toLowerCase().contains(query) ||
                  (chat.lastMessage?.content ?? '').toLowerCase().contains(
                    query,
                  ) ||
                  resultChatIds.contains(chat.id);
            })
            .toList(growable: false);"""

query_logic_new = r"""        final Set<int> resultChatIds = <int>{
          ...?searchResult?.chats.map((ApiSearchChat chat) => chat.id),
          ...?searchResult?.messages.map(
            (ApiSearchMessage message) => message.chatId,
          ),
        };
        final bool isSearchActive = searchResult != null && searchResult.messages.isNotEmpty;
        final List<ApiChatSummary> searched = filtered
            .where((ApiChatSummary chat) {
              if (!isSearchActive) return true;
              return resultChatIds.contains(chat.id);
            })
            .toList(growable: false);"""

text = text.replace(query_logic_old, query_logic_new)

# 14. Remove extracted methods
extracted_methods = [
    r"  Widget _searchAndFilter\([\s\S]*?\n  bool _handleUserScroll",
    r"  void _onSearchChanged\([\s\S]*?Widget _messageResultTile",
    r"  Widget _messageResultTile\([\s\S]*?  \}\n\n  String _filterShortLabel",
    r"  String _filterShortLabel\([\s\S]*?  \}\n\n  List<Widget> _buildChatSlivers",
    r"  IconData _filterIcon\([\s\S]*?  \}\n\n  String _previewText",
]

text = re.sub(r"  Widget _searchAndFilter\([\s\S]*?\n  bool _handleUserScroll", r"  bool _handleUserScroll", text)
text = re.sub(r"  void _onSearchChanged\([\s\S]*?\n  List<Widget> _buildChatSlivers", r"  List<Widget> _buildChatSlivers", text)
text = re.sub(r"  IconData _filterIcon\([\s\S]*?\n  String _previewText", r"  String _previewText", text)

# 15. Fix const ChatTile
text = re.sub(r"(?<!const )ChatTile\(", r"const ChatTile(", text)

with open('lib/screens/chat_list_screen.dart', 'w') as f:
    f.write(text)

