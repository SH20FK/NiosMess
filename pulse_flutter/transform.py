import re

with open('lib/screens/chat_list_screen.dart', 'r') as f:
    content = f.read()

# Add new imports
imports = """import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_field.dart';
"""
content = re.sub(r"(import 'package:pulse_flutter/widgets/pulse_skeleton\.dart';)", r"\1\n" + imports, content)

# Remove _ChatFilter enum
content = re.sub(r"enum _ChatFilter \{ .*? \}\n\n", "", content)

# Remove search and filter controller from state
content = re.sub(r"  final SearchController _searchController = SearchController\(\);\n  late final TabController _filterController;\n  String _query = '';\n  _ChatFilter _filter = _ChatFilter\.all;\n  Timer\? _searchDebounce;\n", "", content)

# Remove _filterController initialization
content = re.sub(r"    _filterController = TabController\(\n      length: _ChatFilter\.values\.length,\n      vsync: this,\n    \);\n", "", content)

# Remove dispose items
content = re.sub(r"    _searchDebounce\?\.cancel\(\);\n    _filterController\.dispose\(\);\n    ref\.read\(chatListSearchProvider\.notifier\)\.clear\(\);\n    _searchController\.dispose\(\);\n", "", content)

# Replace AppBar
appbar_pattern = r"      appBar: AppBar\(.*?      \),"
content = re.sub(appbar_pattern, r"      appBar: ChatListHeader(onCreatePressed: () => _showCreateMenu(context)),", content, flags=re.DOTALL)

# Replace _searchAndFilter usage
content = re.sub(
    r"                      _searchAndFilter\(scheme, textTheme, searchAsync\),",
    r"                      const ChatSearchField(),\n                      const SizedBox(height: 10),\n                      const ChatListFilterBar(),",
    content
)

# In build, we need to read the chat filter instead of local _filter
content = re.sub(
    r"    final String query = _query\.trim\(\);\n    final AsyncValue<ApiSearchResult> searchAsync = query\.isEmpty\n        \? const AsyncValue<ApiSearchResult>\.data\(ApiSearchResult\.empty\(\)\)\n        : ref\.watch\(chatListSearchProvider\);\n",
    "",
    content
)

content = re.sub(
    r"    final AuthState auth = ref\.watch\(authProvider\);",
    r"    final AuthState auth = ref.watch(authProvider);\n    final searchAsync = ref.watch(chatListSearchProvider);\n    final _filter = ref.watch(chatFilterProvider);",
    content
)

content = re.sub(r"_ChatFilter", "ChatFilter", content)

# Replace ChatTile( with const ChatTile(
content = re.sub(r"(?<!const )ChatTile\(", r"const ChatTile(", content)

# Replace _searchAndFilter method and related search/filter methods completely
methods_to_remove = r"  Widget _searchAndFilter\([\s\S]*?Widget _messageResultTile\([\s\S]*?  \}"
content = re.sub(methods_to_remove, "", content)

# Remove _filterShortLabel and _filterIcon methods
content = re.sub(r"  String _filterShortLabel\(ChatFilter value\) \{[\s\S]*?  \}\n\n", "", content)
content = re.sub(r"  IconData _filterIcon\(ChatFilter value\) \{[\s\S]*?  \}\n\n", "", content)

# In _buildChatSlivers we use chatListSearchProvider. We need to handle `query`. But wait, `_query` was used in `_buildChatSlivers`.
# The query is now only in chatListSearchProvider. The simplest way is to check `searchResult`.
# In _buildChatSlivers, change query logic:
query_logic = r"""        final String query = _query\.trim\(\)\.toLowerCase\(\);\n        final Set<int> resultChatIds = <int>\{\n          \.\.\.\?searchResult\?\.chats\.map\(\(ApiSearchChat chat\) => chat\.id\),\n          \.\.\.\?searchResult\?\.messages\.map\(\n            \(ApiSearchMessage message\) => message\.chatId,\n          \),\n        \};\n        final List<ApiChatSummary> searched = filtered\n            \.where\(\(ApiChatSummary chat\) \{\n              if \(query\.isEmpty\) return true;\n              return chat\.name\.toLowerCase\(\)\.contains\(query\) \|\|\n                  \(chat\.lastMessage\?\.content \?\? ''\)\.toLowerCase\(\)\.contains\(\n                    query,\n                  \) \|\|\n                  resultChatIds\.contains\(chat\.id\);\n            \}\)\n            \.toList\(growable: false\);"""

new_query_logic = r"""        final Set<int> resultChatIds = <int>{
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

content = re.sub(query_logic, new_query_logic, content)

with open('lib/screens/chat_list_screen.dart', 'w') as f:
    f.write(content)

