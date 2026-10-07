import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import '../../data/models/instagram_chat_models.dart';
import '../../data/repositories/instagram_chat_repository.dart';
import '../bloc/instagram_chat_bloc.dart';

class InstagramMessagesPage extends StatelessWidget {
  const InstagramMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt.isRegistered<InstagramChatBloc>()
            ? getIt<InstagramChatBloc>()
            : InstagramChatBloc(
                getIt.isRegistered<InstagramChatRepository>()
                    ? getIt<InstagramChatRepository>()
                    : InstagramChatRepository(getIt<Dio>()),
                getIt<SocketService>(),
              );
        return bloc..add(const LoadInstagramChatData());
      },
      child: const _InstagramMessagesView(),
    );
  }
}

class _InstagramMessagesView extends StatefulWidget {
  const _InstagramMessagesView();

  @override
  State<_InstagramMessagesView> createState() => _InstagramMessagesViewState();
}

class _InstagramMessagesViewState extends State<_InstagramMessagesView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageInputController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  static const List<Color> _igGradientColors = [
    Color(0xFFFFB700),
    Color(0xFFFF007F),
    Color(0xFF8000FF),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _messageInputController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<InstagramChatBloc, InstagramChatState>(
        listener: (context, state) {
          if (state is InstagramChatLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          if (state is InstagramChatLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8000FF)),
            );
          }

          if (state is InstagramChatError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.read<InstagramChatBloc>().add(const LoadInstagramChatData()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8000FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is InstagramChatLoaded) {
            if (isMobile) {
              // Mobile view: single pane navigation
              if (state.selectedConversation != null) {
                return _buildChatPane(context, state, isMobile: true);
              }
              return _buildConversationsListPane(context, state);
            }

            // Desktop / Tablet view: Two-panel master-detail layout
            return Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _buildConversationsListPane(context, state),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: state.selectedConversation != null
                      ? _buildChatPane(context, state, isMobile: false)
                      : _buildEmptyState(),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ─── Left Panel: Conversations List ──────────────────────────────────────────

  Widget _buildConversationsListPane(BuildContext context, InstagramChatLoaded state) {
    final filtered = state.filteredConversations;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _igGradientColors,
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.instagram,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instagram Messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Real-time Meta DMs & Inbox',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                  onPressed: () => context.read<InstagramChatBloc>().add(const LoadInstagramChatData(silent: true)),
                ),
              ],
            ),
          ),

          // Account Selector Filter (Multi-account isolation)
          if (state.accounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: state.selectedAccountId ?? '',
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All Connected Accounts'),
                      ),
                      ...state.accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc.instagramAccountId,
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.instagram, size: 13, color: Color(0xFFFF007F)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '@${acc.username.isNotEmpty ? acc.username : acc.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      context.read<InstagramChatBloc>().add(
                            FilterInstagramConversations(selectedAccountId: val),
                          );
                    },
                  ),
                ),
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, handle, message...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<InstagramChatBloc>().add(
                                const FilterInstagramConversations(searchQuery: ''),
                              );
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8000FF), width: 1.5),
                ),
              ),
              onChanged: (val) {
                context.read<InstagramChatBloc>().add(
                      FilterInstagramConversations(searchQuery: val),
                    );
              },
            ),
          ),

          // Filter Chips: All, Unread, Human Takeover
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(context, state, 'all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(context, state, 'unread', 'Unread'),
                const SizedBox(width: 8),
                _buildFilterChip(context, state, 'takeover', 'Takeover'),
              ],
            ),
          ),

          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),

          // Conversations List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mark_chat_read_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No conversations found',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'New Instagram DMs received from Meta webhooks will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 72,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final isSelected = state.selectedConversation?.id == conv.id;

                      return _buildConversationListItem(context, conv, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    InstagramChatLoaded state,
    String filterKey,
    String label,
  ) {
    final isSelected = state.filterStatus == filterKey;

    return InkWell(
      onTap: () {
        context.read<InstagramChatBloc>().add(
              FilterInstagramConversations(filterStatus: filterKey),
            );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8000FF).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8000FF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF8000FF) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationListItem(
    BuildContext context,
    InstagramConversationModel conv,
    bool isSelected,
  ) {
    final timeStr = _formatTimestamp(conv.lastMessageAt);

    return InkWell(
      onTap: () {
        context.read<InstagramChatBloc>().add(SelectInstagramConversation(conv));
      },
      child: Container(
        color: isSelected ? const Color(0xFF8000FF).withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with Instagram gradient border
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _igGradientColors,
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: conv.profilePic.isNotEmpty ? NetworkImage(conv.profilePic) : null,
                    child: conv.profilePic.isEmpty
                        ? Text(
                            conv.name.isNotEmpty
                                ? conv.name[0].toUpperCase()
                                : (conv.username.isNotEmpty ? conv.username[0].toUpperCase() : 'U'),
                            style: const TextStyle(
                              color: Color(0xFF8000FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
                // 24-hr window status indicator dot
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: conv.isWindowOpen ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Name, preview, and badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.name.isNotEmpty ? conv.name : (conv.username.isNotEmpty ? '@${conv.username}' : 'User ${conv.igsid.substring(0, 5)}'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          color: conv.unreadCount > 0 ? const Color(0xFF8000FF) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (conv.username.isNotEmpty)
                    Text(
                      '@${conv.username}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage.isNotEmpty ? conv.lastMessage : 'No messages yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: conv.unreadCount > 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: _igGradientColors),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conv.unreadCount.toString(),
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Badges: Human takeover / Bot active
                  if (conv.isHumanTakeover)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded, size: 10, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'Agent Takeover',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Right Panel: Chat Window ────────────────────────────────────────────────

  Widget _buildChatPane(BuildContext context, InstagramChatLoaded state, {required bool isMobile}) {
    final conv = state.selectedConversation!;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Chat Header Bar
          _buildChatHeader(context, conv, isMobile),

          // 24-hr Policy & Human Takeover Banner
          _buildPolicyAndTakeoverBanner(context, conv),

          // Message Bubbles List
          Expanded(
            child: state.isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8000FF)),
                  )
                : state.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'No messages in this conversation',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Type below to send a reply directly to customer\'s Instagram DM.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _messagesScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          final isFirstOrDiffDay = index == 0 ||
                              !_isSameDay(state.messages[index - 1].timestamp, msg.timestamp);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isFirstOrDiffDay) _buildDateSeparator(msg.timestamp),
                              _buildMessageBubble(msg),
                            ],
                          );
                        },
                      ),
          ),

          // Bottom Input Bar
          _buildMessageInputBar(context, state, conv),
        ],
      ),
    );
  }

  Widget _buildChatHeader(
    BuildContext context,
    InstagramConversationModel conv,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
              onPressed: () {
                context.read<InstagramChatBloc>().add(const LoadInstagramChatData(silent: true));
              },
            ),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF8000FF).withValues(alpha: 0.1),
            backgroundImage: conv.profilePic.isNotEmpty ? NetworkImage(conv.profilePic) : null,
            child: conv.profilePic.isEmpty
                ? Text(
                    conv.name.isNotEmpty
                        ? conv.name[0].toUpperCase()
                        : (conv.username.isNotEmpty ? conv.username[0].toUpperCase() : 'U'),
                    style: const TextStyle(color: Color(0xFF8000FF), fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Contact Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conv.name.isNotEmpty ? conv.name : 'Instagram User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const FaIcon(FontAwesomeIcons.instagram, size: 13, color: Color(0xFFFF007F)),
                  ],
                ),
                Text(
                  conv.username.isNotEmpty
                      ? '@${conv.username}  •  IGSID: ${conv.igsid}'
                      : 'IGSID: ${conv.igsid}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Human Takeover Action Toggle Button
          InkWell(
            onTap: () {
              context.read<InstagramChatBloc>().add(
                    ToggleConversationHumanTakeover(!conv.isHumanTakeover),
                  );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: conv.isHumanTakeover ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: conv.isHumanTakeover ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    conv.isHumanTakeover ? Icons.person_rounded : Icons.smart_toy_outlined,
                    size: 14,
                    color: conv.isHumanTakeover ? const Color(0xFF2563EB) : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    conv.isHumanTakeover ? 'Agent Mode (Pause Bot)' : 'Bot Active (Takeover)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: conv.isHumanTakeover ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyAndTakeoverBanner(
    BuildContext context,
    InstagramConversationModel conv,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: conv.isWindowOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        border: Border(
          bottom: BorderSide(
            color: conv.isWindowOpen ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            conv.isWindowOpen ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: conv.isWindowOpen ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              conv.isWindowOpen
                  ? 'Meta 24h Window Active: ${conv.remainingHours}h remaining to reply to this customer.'
                  : 'Meta 24h Messaging Window Expired: Direct replies outside 24h may be restricted by Meta policy until customer messages again.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: conv.isWindowOpen ? const Color(0xFF15803D) : const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormat('EEEE, MMM d, yyyy').format(date),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(InstagramMessageModel msg) {
    final isMe = msg.isMe;
    final isBot = msg.senderType == 'automation';
    final timeStr = DateFormat('hh:mm a').format(msg.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          gradient: isMe
              ? (isBot
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF8000FF), Color(0xFFFF007F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ))
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender tag
            if (isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBot ? Icons.smart_toy_rounded : Icons.support_agent_rounded,
                      size: 11,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBot ? 'Bot Auto-Reply' : 'Agent',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

            // Message Text
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),

            // Quick replies chips if any
            if (msg.quickReplies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.quickReplies.map((qr) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMe ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      qr.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 4),
            // Timestamp and ticks
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.status == 'read'
                        ? Icons.done_all_rounded
                        : (msg.status == 'delivered' ? Icons.done_all_rounded : Icons.done_rounded),
                    size: 13,
                    color: msg.status == 'read' ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputBar(
    BuildContext context,
    InstagramChatLoaded state,
    InstagramConversationModel conv,
  ) {
    final isSending = state.isSendingMessage;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pre-canned Quick Replies Suggestion Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickInsertChip('Hello! How can I help you?'),
                _buildQuickInsertChip('Thanks for reaching out!'),
                _buildQuickInsertChip('Check out our catalog'),
                _buildQuickInsertChip('Connecting you with an agent...'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Input field and send button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageInputController,
                  maxLines: 4,
                  minLines: 1,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Type an Instagram reply (Meta max 1,000 chars)...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8000FF), width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(context),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: _igGradientColors,
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: isSending ? null : () => _handleSend(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsertChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        onPressed: () {
          _messageInputController.text = text;
          _messageInputController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        },
      ),
    );
  }

  void _handleSend(BuildContext context) {
    final text = _messageInputController.text.trim();
    if (text.isEmpty) return;

    context.read<InstagramChatBloc>().add(SendInstagramReplyMessage(text: text));
    _messageInputController.clear();
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: _igGradientColors,
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF007F).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const FaIcon(
                FontAwesomeIcons.instagram,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View and reply to customer Instagram Direct Messages in real-time.\nSupports automated bot responses and human agent takeover.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('E').format(time);
    return DateFormat('MMM d').format(time);
  }
}
