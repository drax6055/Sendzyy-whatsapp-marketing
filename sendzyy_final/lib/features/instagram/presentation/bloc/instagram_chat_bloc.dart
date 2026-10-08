import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import '../../data/models/instagram_chat_models.dart';
import '../../data/repositories/instagram_chat_repository.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class InstagramChatEvent extends Equatable {
  const InstagramChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadInstagramChatData extends InstagramChatEvent {
  final bool silent;
  const LoadInstagramChatData({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

class SelectInstagramConversation extends InstagramChatEvent {
  final InstagramConversationModel conversation;
  const SelectInstagramConversation(this.conversation);

  @override
  List<Object?> get props => [conversation];
}

class SendInstagramReplyMessage extends InstagramChatEvent {
  final String text;
  final List<String>? quickReplies;
  const SendInstagramReplyMessage({required this.text, this.quickReplies});

  @override
  List<Object?> get props => [text, quickReplies];
}

class ToggleConversationHumanTakeover extends InstagramChatEvent {
  final bool isHumanTakeover;
  const ToggleConversationHumanTakeover(this.isHumanTakeover);

  @override
  List<Object?> get props => [isHumanTakeover];
}

class FilterInstagramConversations extends InstagramChatEvent {
  final String? searchQuery;
  final String? selectedAccountId;
  final String? filterStatus; // 'all' | 'unread' | 'takeover'

  const FilterInstagramConversations({
    this.searchQuery,
    this.selectedAccountId,
    this.filterStatus,
  });

  @override
  List<Object?> get props => [searchQuery, selectedAccountId, filterStatus];
}

class InstagramMessageReceivedSocketEvent extends InstagramChatEvent {
  final Map<String, dynamic> payload;
  const InstagramMessageReceivedSocketEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class InstagramConversationUpdatedSocketEvent extends InstagramChatEvent {
  final Map<String, dynamic> payload;
  const InstagramConversationUpdatedSocketEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class InstagramStatusSocketEvent extends InstagramChatEvent {
  final Map<String, dynamic> payload;
  const InstagramStatusSocketEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class InstagramChatState extends Equatable {
  const InstagramChatState();

  @override
  List<Object?> get props => [];
}

class InstagramChatInitial extends InstagramChatState {}

class InstagramChatLoading extends InstagramChatState {}

class InstagramChatLoaded extends InstagramChatState {
  final List<InstagramConversationModel> conversations;
  final List<InstagramAccountModel> accounts;
  final InstagramConversationModel? selectedConversation;
  final List<InstagramMessageModel> messages;
  final bool isLoadingMessages;
  final bool isSendingMessage;
  final String? errorMessage;
  final String searchQuery;
  final String? selectedAccountId;
  final String filterStatus; // 'all' | 'unread' | 'takeover'

  const InstagramChatLoaded({
    required this.conversations,
    required this.accounts,
    this.selectedConversation,
    this.messages = const [],
    this.isLoadingMessages = false,
    this.isSendingMessage = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedAccountId,
    this.filterStatus = 'all',
  });

  List<InstagramConversationModel> get filteredConversations {
    return conversations.where((c) {
      if (selectedAccountId != null && selectedAccountId!.isNotEmpty) {
        if (c.instagramAccountId != selectedAccountId) return false;
      }
      if (filterStatus == 'unread' && c.unreadCount == 0) {
        return false;
      }
      if (filterStatus == 'takeover' && !c.isHumanTakeover) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final nameMatch = c.name.toLowerCase().contains(q);
        final userMatch = c.username.toLowerCase().contains(q);
        final msgMatch = c.lastMessage.toLowerCase().contains(q);
        if (!nameMatch && !userMatch && !msgMatch) return false;
      }
      return true;
    }).toList();
  }

  InstagramChatLoaded copyWith({
    List<InstagramConversationModel>? conversations,
    List<InstagramAccountModel>? accounts,
    InstagramConversationModel? selectedConversation,
    bool clearSelectedConversation = false,
    List<InstagramMessageModel>? messages,
    bool? isLoadingMessages,
    bool? isSendingMessage,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    String? selectedAccountId,
    bool clearSelectedAccountId = false,
    String? filterStatus,
  }) {
    return InstagramChatLoaded(
      conversations: conversations ?? this.conversations,
      accounts: accounts ?? this.accounts,
      selectedConversation: clearSelectedConversation
          ? null
          : (selectedConversation ?? this.selectedConversation),
      messages: messages ?? this.messages,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedAccountId: clearSelectedAccountId
          ? null
          : (selectedAccountId ?? this.selectedAccountId),
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        accounts,
        selectedConversation,
        messages,
        isLoadingMessages,
        isSendingMessage,
        errorMessage,
        searchQuery,
        selectedAccountId,
        filterStatus,
      ];
}

class InstagramChatError extends InstagramChatState {
  final String message;
  const InstagramChatError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class InstagramChatBloc extends Bloc<InstagramChatEvent, InstagramChatState> {
  final InstagramChatRepository _repository;
  final SocketService _socketService;

  StreamSubscription? _msgSub;
  StreamSubscription? _convSub;
  StreamSubscription? _statusSub;

  InstagramChatBloc(this._repository, this._socketService) : super(InstagramChatInitial()) {
    on<LoadInstagramChatData>(_onLoadData);
    on<SelectInstagramConversation>(_onSelectConversation);
    on<SendInstagramReplyMessage>(_onSendMessage);
    on<ToggleConversationHumanTakeover>(_onToggleTakeover);
    on<FilterInstagramConversations>(_onFilterConversations);
    on<InstagramMessageReceivedSocketEvent>(_onSocketMessageReceived);
    on<InstagramConversationUpdatedSocketEvent>(_onSocketConversationUpdated);
    on<InstagramStatusSocketEvent>(_onSocketStatusUpdated);

    // Listen to real-time events from SocketService
    _msgSub = _socketService.instagramMessageStream.listen((data) {
      add(InstagramMessageReceivedSocketEvent(data));
    });
    _convSub = _socketService.instagramConversationStream.listen((data) {
      add(InstagramConversationUpdatedSocketEvent(data));
    });
    _statusSub = _socketService.instagramStatusStream.listen((data) {
      add(InstagramStatusSocketEvent(data));
    });
  }

  @override
  Future<void> close() {
    _msgSub?.cancel();
    _convSub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }

  Future<void> _onLoadData(LoadInstagramChatData event, Emitter<InstagramChatState> emit) async {
    if (!event.silent) {
      emit(InstagramChatLoading());
    }
    try {
      final accounts = await _repository.getAccounts();
      final conversations = await _repository.getConversations();

      InstagramConversationModel? currentSelected;
      List<InstagramMessageModel> currentMessages = [];

      if (state is InstagramChatLoaded) {
        final current = state as InstagramChatLoaded;
        if (current.selectedConversation != null) {
          // Keep current selection if exists in new list or update it
          currentSelected = conversations.firstWhere(
            (c) => c.id == current.selectedConversation!.id,
            orElse: () => current.selectedConversation!,
          );
          currentMessages = current.messages;
        }
      }

      emit(InstagramChatLoaded(
        conversations: conversations,
        accounts: accounts,
        selectedConversation: currentSelected,
        messages: currentMessages,
      ));
    } catch (e) {
      emit(InstagramChatError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSelectConversation(
    SelectInstagramConversation event,
    Emitter<InstagramChatState> emit,
  ) async {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;

    // Reset unread count locally immediately
    final updatedConv = event.conversation.copyWith(unreadCount: 0);
    final updatedConvs = currentState.conversations.map((c) {
      return c.id == updatedConv.id ? updatedConv : c;
    }).toList();

    emit(currentState.copyWith(
      selectedConversation: updatedConv,
      conversations: updatedConvs,
      isLoadingMessages: true,
      clearError: true,
    ));

    try {
      final messages = await _repository.getMessages(event.conversation.id);
      _repository.markAsRead(event.conversation.id);
      emit((state as InstagramChatLoaded).copyWith(
        messages: messages,
        isLoadingMessages: false,
      ));
    } catch (e) {
      emit((state as InstagramChatLoaded).copyWith(
        isLoadingMessages: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onSendMessage(
    SendInstagramReplyMessage event,
    Emitter<InstagramChatState> emit,
  ) async {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;
    final activeConv = currentState.selectedConversation;
    if (activeConv == null) return;

    emit(currentState.copyWith(isSendingMessage: true, clearError: true));

    try {
      final sentMessage = await _repository.sendMessage(
        activeConv.id,
        event.text,
        quickReplies: event.quickReplies,
      );

      final updatedMessages = List<InstagramMessageModel>.from(currentState.messages);
      if (!updatedMessages.any((m) => m.id == sentMessage.id)) {
        updatedMessages.add(sentMessage);
      }

      final updatedConv = activeConv.copyWith(
        lastMessage: event.text,
        lastMessageAt: DateTime.now(),
        isHumanTakeover: true,
      );

      final updatedConvs = [
        updatedConv,
        ...currentState.conversations.where((c) => c.id != updatedConv.id),
      ];

      emit(currentState.copyWith(
        messages: updatedMessages,
        conversations: updatedConvs,
        selectedConversation: updatedConv,
        isSendingMessage: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(
        isSendingMessage: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onToggleTakeover(
    ToggleConversationHumanTakeover event,
    Emitter<InstagramChatState> emit,
  ) async {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;
    final activeConv = currentState.selectedConversation;
    if (activeConv == null) return;

    try {
      final updated = await _repository.toggleTakeover(activeConv.id, event.isHumanTakeover);
      final updatedConvs = currentState.conversations.map((c) {
        return c.id == updated.id ? updated : c;
      }).toList();

      emit(currentState.copyWith(
        selectedConversation: updated,
        conversations: updatedConvs,
      ));
    } catch (e) {
      emit(currentState.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  void _onFilterConversations(
    FilterInstagramConversations event,
    Emitter<InstagramChatState> emit,
  ) {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;

    emit(currentState.copyWith(
      searchQuery: event.searchQuery ?? currentState.searchQuery,
      selectedAccountId: event.selectedAccountId ?? currentState.selectedAccountId,
      clearSelectedAccountId: event.selectedAccountId == '',
      filterStatus: event.filterStatus ?? currentState.filterStatus,
    ));
  }

  void _onSocketMessageReceived(
    InstagramMessageReceivedSocketEvent event,
    Emitter<InstagramChatState> emit,
  ) {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;

    try {
      final rawConv = event.payload['conversation'];
      final rawMsg = event.payload['message'];

      InstagramConversationModel? conv;
      InstagramMessageModel? msg;

      if (rawConv is Map<String, dynamic>) {
        conv = InstagramConversationModel.fromJson(rawConv);
      }
      if (rawMsg is Map<String, dynamic>) {
        msg = InstagramMessageModel.fromJson(rawMsg);
      }

      if (conv == null) return;

      // Update conversations list (move updated conversation to front)
      final existingIndex = currentState.conversations.indexWhere((c) => c.id == conv!.id);
      final updatedConvs = List<InstagramConversationModel>.from(currentState.conversations);

      if (existingIndex != -1) {
        updatedConvs.removeAt(existingIndex);
      }
      updatedConvs.insert(0, conv);

      // Check if received message belongs to active open chat
      List<InstagramMessageModel> updatedMessages = List.from(currentState.messages);
      InstagramConversationModel? updatedSelected = currentState.selectedConversation;

      if (currentState.selectedConversation != null && currentState.selectedConversation!.id == conv.id) {
        updatedSelected = conv.copyWith(unreadCount: 0);
        if (msg != null && !updatedMessages.any((m) => m.id == msg!.id || (m.mid.isNotEmpty && m.mid == msg.mid))) {
          updatedMessages.add(msg);
        }
      }

      emit(currentState.copyWith(
        conversations: updatedConvs,
        selectedConversation: updatedSelected,
        messages: updatedMessages,
      ));
    } catch (_) {}
  }

  void _onSocketConversationUpdated(
    InstagramConversationUpdatedSocketEvent event,
    Emitter<InstagramChatState> emit,
  ) {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;

    try {
      final conv = InstagramConversationModel.fromJson(event.payload);
      final updatedConvs = currentState.conversations.map((c) {
        return c.id == conv.id ? conv : c;
      }).toList();

      InstagramConversationModel? updatedSelected = currentState.selectedConversation;
      if (updatedSelected != null && updatedSelected.id == conv.id) {
        updatedSelected = conv;
      }

      emit(currentState.copyWith(
        conversations: updatedConvs,
        selectedConversation: updatedSelected,
      ));
    } catch (_) {}
  }

  void _onSocketStatusUpdated(
    InstagramStatusSocketEvent event,
    Emitter<InstagramChatState> emit,
  ) {
    if (state is! InstagramChatLoaded) return;
    final currentState = state as InstagramChatLoaded;

    try {
      final mids = event.payload['mids'];
      final status = event.payload['status']?.toString();
      if (mids is List && status != null) {
        final midSet = Set<String>.from(mids.map((e) => e.toString()));
        final updatedMessages = currentState.messages.map((m) {
          if (midSet.contains(m.mid)) {
            return InstagramMessageModel(
              id: m.id,
              conversationId: m.conversationId,
              igsid: m.igsid,
              isMe: m.isMe,
              senderType: m.senderType,
              text: m.text,
              messageType: m.messageType,
              mediaUrl: m.mediaUrl,
              quickReplies: m.quickReplies,
              mid: m.mid,
              status: status,
              timestamp: m.timestamp,
            );
          }
          return m;
        }).toList();

        emit(currentState.copyWith(messages: updatedMessages));
      }
    } catch (_) {}
  }
}
