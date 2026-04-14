import 'dart:async';
import 'dart:math';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final _botPretensions = [
    "Thinking...", "Analyzing your request...", "Checking local municipal data...", "Gathering insights..."
  ];

  // Auto-detect category from description
  Future<Map<String, String>> analyzeComplaint(String description) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network request for AI processing
    final descLower = description.toLowerCase();
    
    String category = 'Other';
    String department = 'General Grievance Cell';

    if (descLower.contains('pothole') || descLower.contains('road') || descLower.contains('crack')) {
      category = 'Potholes';
      department = 'Municipal Road Department';
    } else if (descLower.contains('garbage') || descLower.contains('trash') || descLower.contains('waste')) {
      category = 'Garbage Overflow';
      department = 'Sanitation Department';
    } else if (descLower.contains('light') || descLower.contains('electricity') || descLower.contains('power')) {
      category = 'Streetlight Failure';
      department = 'Electricity Board';
    } else if (descLower.contains('water') || descLower.contains('leak') || descLower.contains('pipe')) {
      category = 'Water Leakage';
      department = 'Water Supply Department';
    }

    return {
      'category': category,
      'department': department,
    };
  }

  // Simulate a chat conversation with delay for realism
  Stream<String> getChatResponse(String message) async* {
    yield _botPretensions[Random().nextInt(_botPretensions.length)];
    await Future.delayed(const Duration(milliseconds: 1500));
    
    final lower = message.toLowerCase();
    String response = "I'm your Smart Civic Assistant. I can help you report issues or answer questions about municipal services. Need help reporting a pothole, garbage, or leaking water?";

    if (lower.contains('hello') || lower.contains('hi')) {
      response = "Hello! I am the Smart City AI. How can I assist you with reporting civic issues today?";
    } else if (lower.contains('report') || lower.contains('issue')) {
      response = "You can report an issue by tapping the big blue '+' button on the dashboard. Make sure to take a clear photo and our AI will attempt to auto-categorize it for you!";
    } else if (lower.contains('pothole') || lower.contains('road')) {
      response = "Potholes are a serious safety hazard. Please report it using the '+' button, provide a photo, and it will be assigned to the Municipal Road Department with high priority.";
    } else if (lower.contains('points') || lower.contains('reward') || lower.contains('rank')) {
      response = "You earn 50 points for every reported issue that gets resolved! Keep reporting to rank up from Active Citizen to City Guardian!";
    } else if (lower.contains('community') || lower.contains('feed')) {
      response = "The Community Feed allows you to see public reports. You can upvote them to increase their visibility or propose solutions in the detailed view.";
    }

    // yield character by character to simulate typing
    String currentText = "";
    for (int i = 0; i < response.length; i++) {
      currentText += response[i];
      yield currentText;
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }
}
