import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_ai_sample/utils/logger.dart';

enum ChatState { initial, loading, success, error }

class ChatRepo {
  ChatState _state = ChatState.initial;

  ChatState get state => _state;

  static final jsonSchema = Schema.object(
    properties: {"response": Schema.string(description: "The response text.")},
    description: "required fields: response",
  );

  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3-flash-preview',
    generationConfig: GenerationConfig(
      responseMimeType: "application/json",
      responseSchema: jsonSchema,
    ),
  );

  Future<ChatSession> startChat() async {
    _state = ChatState.loading;
    final response = model.startChat();
    showlog("Chat Session : Started}");
    return response;
  }

  Future<Chat> sendMessage({
    required String message,
    required ChatSession chat,
  }) async {
    _state = ChatState.loading;
    final prompt = Content.text(message);

    final response = await chat.sendMessage(prompt);

    showlog("Chat response: ${response.text}");

    if (response.text != null) {
      _state = ChatState.success;
      return Chat.fromJson(jsonDecode(response.text!));
    }

    _state = ChatState.error;
    return Chat(response: "Something went wrong!");
  }
}

class Chat {
  final String response;

  Chat({required this.response});

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(response: json['response']);
  }
}
