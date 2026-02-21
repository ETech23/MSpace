// lib/features/messaging/data/datasources/message_remote_data_source.dart
// FIXED: All notification inserts now include sub_type and related_id
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  Future<List<ConversationModel>> getConversations(String userId);
  Future<List<MessageModel>> getMessages(String conversationId);
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String messageText,
  });
  Future<MessageModel> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String voiceFilePath,
    required int durationSeconds,
  });
  Future<MessageModel> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String filePath,
    required String fileType,
  });
  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
    String? bookingId,
  });
  Future<void> markMessagesAsRead(String conversationId, String userId);
  Future<int> getUnreadMessageCount(String userId);
  Stream<List<MessageModel>> subscribeToMessages(String conversationId);
  Stream<List<ConversationModel>> subscribeToConversations(String userId);
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final SupabaseClient supabase;
  
  static const String voiceMessagesBucket = 'voice-messages';
  static const String chatFilesBucket = 'chat-files';

  MessageRemoteDataSourceImpl({required this.supabase});

  @override
  Future<List<ConversationModel>> getConversations(String userId) async {
    try {
      final response = await supabase
          .from('conversations')
          .select('''
            *,
            participant1:users!conversations_participant1_id_fkey(*),
            participant2:users!conversations_participant2_id_fkey(*)
          ''')
          .or('participant1_id.eq.$userId,participant2_id.eq.$userId')
          .order('updated_at', ascending: false);

      final conversationsWithMessages = <Map<String, dynamic>>[];
      
      for (final conv in response as List) {
        final convMap = Map<String, dynamic>.from(conv);
        
        if (conv['last_message_id'] != null) {
          try {
            final lastMessage = await supabase
                .from('messages')
                .select('*')
                .eq('id', conv['last_message_id'])
                .maybeSingle();
            
            if (lastMessage != null) {
              convMap['last_message'] = lastMessage;
            }
          } catch (e) {
            debugPrint('Error fetching last message: $e');
          }
        }
        
        try {
          final unreadMessages = await supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', conv['id'])
              .neq('sender_id', userId)
              .eq('is_read', false);
          
          convMap['unread_count'] = (unreadMessages as List).length;
        } catch (e) {
          debugPrint('Error fetching unread count: $e');
          convMap['unread_count'] = 0;
        }
        
        conversationsWithMessages.add(convMap);
      }

      return conversationsWithMessages
          .map((json) => ConversationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch conversations: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final response = await supabase
          .from('messages')
          .select('*, sender:users!messages_sender_id_fkey(*)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => MessageModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch messages: $e');
    }
  }

  // lib/features/messaging/data/datasources/message_remote_data_source.dart

@override
Future<MessageModel> sendMessage({
  required String conversationId,
  required String senderId,
  required String messageText,
}) async {
  try {
    final response = await supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_text': messageText,
          'message_type': 'text',
        })
        .select('*, sender:users!messages_sender_id_fkey(*)')
        .single();

    // ❌ REMOVE: Manual notification insert - trigger handles it
    // await supabase.from('notifications').insert({...});

    await _updateConversationTimestamp(conversationId, response['id']);

    return MessageModel.fromJson(response);
  } catch (e) {
    throw ServerException(message: 'Failed to send message: $e');
  }
}

@override
Future<MessageModel> sendVoiceMessage({
  required String conversationId,
  required String senderId,
  required String voiceFilePath,
  required int durationSeconds,
}) async {
  try {
    final voiceUrl = await _uploadFile(
      filePath: voiceFilePath,
      senderId: senderId,
      bucket: voiceMessagesBucket,
      fileType: 'voice',
      contentType: 'audio/mp4',
    );

    final response = await supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_type': 'voice',
          'attachment_url': voiceUrl,
          'voice_duration_seconds': durationSeconds,
          'message_text': '',
        })
        .select('*, sender:users!messages_sender_id_fkey(*)')
        .single();

    // ❌ REMOVE: Manual notification insert
    // await supabase.from('notifications').insert({...});

    await _updateConversationTimestamp(conversationId, response['id']);

    return MessageModel.fromJson(response);
  } catch (e) {
    throw ServerException(message: 'Failed to send voice message: $e');
  }
}

@override
Future<MessageModel> sendFileMessage({
  required String conversationId,
  required String senderId,
  required String filePath,
  required String fileType,
}) async {
  try {
    final extension = filePath.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';
    
    if (fileType == 'image') {
      contentType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
    } else if (extension == 'pdf') {
      contentType = 'application/pdf';
    } else if (extension == 'doc' || extension == 'docx') {
      contentType = 'application/msword';
    }

    final fileUrl = await _uploadFile(
      filePath: filePath,
      senderId: senderId,
      bucket: chatFilesBucket,
      fileType: fileType,
      contentType: contentType,
    );

    final messageText = fileType == 'image' 
        ? '📷 Image' 
        : '📄 ${extension.toUpperCase()} File';

    final response = await supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_type': fileType,
          'attachment_url': fileUrl,
          'message_text': messageText,
        })
        .select('*, sender:users!messages_sender_id_fkey(*)')
        .single();

    // ❌ REMOVE: Manual notification insert
    // await supabase.from('notifications').insert({...});

    await _updateConversationTimestamp(conversationId, response['id']);

    return MessageModel.fromJson(response);
  } catch (e) {
    throw ServerException(message: 'Failed to send file: $e');
  }
}

  Future<String> _uploadFile({
    required String filePath,
    required String senderId,
    required String bucket,
    required String fileType,
    required String contentType,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ServerException(message: 'File not found');
      }

      try {
        await supabase.storage.from(bucket).list();
      } catch (e) {
        throw ServerException(
          message: 'Storage bucket "$bucket" not found.\n\n'
              'Create it in Supabase Dashboard:\n'
              '1. Go to Storage\n'
              '2. Click "New bucket"\n'
              '3. Name: $bucket\n'
              '4. Make it Public ✓',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = filePath.split('.').last;
      final fileName = '${fileType}_${senderId}_$timestamp.$extension';
      final storagePath = '$senderId/$fileName';

      await supabase.storage.from(bucket).upload(
        storagePath,
        file,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl = supabase.storage
          .from(bucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } on StorageException catch (e) {
      if (e.statusCode == '404') {
        throw ServerException(
          message: 'Bucket "$bucket" not found. Create it in Supabase Storage.',
        );
      }
      throw ServerException(message: 'Upload failed: ${e.message}');
    } catch (e) {
      throw ServerException(message: 'Upload failed: $e');
    }
  }

  Future<void> _updateConversationTimestamp(
    String conversationId,
    String lastMessageId,
  ) async {
    try {
      await supabase
          .from('conversations')
          .update({
            'last_message_id': lastMessageId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Failed to update conversation: $e');
    }
  }

  @override
  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
    String? bookingId,
  }) async {
    try {
      final existing = await supabase
          .from('conversations')
          .select('id')
          .or('and(participant1_id.eq.$userId1,participant2_id.eq.$userId2),'
              'and(participant1_id.eq.$userId2,participant2_id.eq.$userId1)')
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      final response = await supabase
          .from('conversations')
          .insert({
            'participant1_id': userId1,
            'participant2_id': userId2,
            if (bookingId != null) 'booking_id': bookingId,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      throw ServerException(message: 'Failed to create conversation: $e');
    }
  }

  @override
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(message: 'Failed to mark messages as read: $e');
    }
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final conversations = await supabase
          .from('conversations')
          .select('id')
          .or('participant1_id.eq.$userId,participant2_id.eq.$userId');

      final conversationIds = (conversations as List)
          .map((c) => c['id'] as String)
          .toList();

      if (conversationIds.isEmpty) return 0;

      final response = await supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', conversationIds)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      throw ServerException(message: 'Failed to get unread count: $e');
    }
  }

  @override
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) => (data as List)
            .map((json) => MessageModel.fromJson(json))
            .toList());
  }

  @override
  Stream<List<ConversationModel>> subscribeToConversations(String userId) async* {
    await for (final event in supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)) {
      
      final userConversationIds = (event as List)
          .where((conv) {
            final participant1 = conv['participant1_id'];
            final participant2 = conv['participant2_id'];
            return participant1 == userId || participant2 == userId;
          })
          .map((conv) => conv['id'] as String)
          .toList();

      if (userConversationIds.isEmpty) {
        yield [];
        continue;
      }

      try {
        final response = await supabase
            .from('conversations')
            .select('''
              *,
              participant1:users!conversations_participant1_id_fkey(*),
              participant2:users!conversations_participant2_id_fkey(*)
            ''')
            .inFilter('id', userConversationIds)
            .order('updated_at', ascending: false);

        final conversationsWithMessages = <Map<String, dynamic>>[];
        
        for (final conv in response as List) {
          final convMap = Map<String, dynamic>.from(conv);
          
          if (conv['last_message_id'] != null) {
            try {
              final lastMessage = await supabase
                  .from('messages')
                  .select('*')
                  .eq('id', conv['last_message_id'])
                  .maybeSingle();
              
              if (lastMessage != null) {
                convMap['last_message'] = lastMessage;
              }
            } catch (e) {
              debugPrint('Error fetching last message: $e');
            }
          }
          
          try {
            final unreadMessages = await supabase
                .from('messages')
                .select('id')
                .eq('conversation_id', conv['id'])
                .neq('sender_id', userId)
                .eq('is_read', false);
            
            convMap['unread_count'] = (unreadMessages as List).length;
          } catch (e) {
            debugPrint('Error fetching unread count: $e');
            convMap['unread_count'] = 0;
          }
          
          conversationsWithMessages.add(convMap);
        }

        yield conversationsWithMessages
            .map((json) => ConversationModel.fromJson(json))
            .toList();
      } catch (e) {
        debugPrint('Error fetching conversation details: $e');
        yield [];
      }
    }
  }
}