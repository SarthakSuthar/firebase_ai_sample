import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_ai_sample/utils.dart';

/*
Sample response 

[
  {
    "event.name": "gen_ai.choice",
    "finish_reason": "stop",
    "index": 0,
    "message": {
      "content": [
        {
          "text": "{\"title\":\"The Kind King and the Starry Crown\",\"story\":\"Once upon a time, in a land of purple hills, lived King Leo. He wore a crown made of moonlight and robes as soft as clouds. Every night, before the moon rose high, the King would walk through his kingdom to tuck in the flowers and whisper to the birds. He carried a small silver bell that chimed a gentle lullaby. When the children heard the chime, they knew it was time for dreams. King Leo would then climb the highest tower and sprinkle golden dust into the breeze, making sure every bed was cozy and every dream was sweet. As the stars twinkled, the King would yawn and say, 'Goodnight, world,' falling fast asleep in his velvet chair.\"}"
        }
      ],
      "role": "model"
    },
    "tool_calls": []
  }
]
 */

class StoryGeneratorRepo {
  static final jsonSchema = Schema.object(
    properties: {
      "title": Schema.string(description: "The title of the story."),
      "story": Schema.string(description: "The story text."),
    },
    description: "required fields: title, story",
  );

  //TODO: add to remote config
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3-flash-preview',
    generationConfig: GenerationConfig(
      responseMimeType: "application/json",
      responseSchema: jsonSchema,
    ),
  );

  Future<Story?> generateStory({required String topic}) async {
    final prompt = [
      Content.text('Write a bed time story for kids about $topic.'),
    ];

    final response = await model.generateContent(prompt);

    showlog("Story title: ${response.text}");
    showlog("Story generator response: ${response.text}");

    if (response.text != null) {
      return Story.fromJson(jsonDecode(response.text!));
    }

    return null;
  }
}

class Story {
  final String title;
  final String story;

  Story({required this.title, required this.story});

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(title: json['title'], story: json['story']);
  }
}
