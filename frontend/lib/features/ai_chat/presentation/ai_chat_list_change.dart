enum AiChatListChange { none, prepended, appended }

bool shouldAutoScrollAiChatAppend({
  required double currentOffset,
  required double maxScrollExtent,
  double threshold = 160,
}) {
  return maxScrollExtent - currentOffset <= threshold;
}

AiChatListChange detectAiChatListChange({
  required List<String> previousIds,
  required List<String> currentIds,
}) {
  if (currentIds.length <= previousIds.length) {
    return AiChatListChange.none;
  }
  if (previousIds.isEmpty) return AiChatListChange.appended;

  final int offset = currentIds.length - previousIds.length;
  var previousIsSuffix = true;
  for (var index = 0; index < previousIds.length; index++) {
    if (previousIds[index] != currentIds[index + offset]) {
      previousIsSuffix = false;
      break;
    }
  }
  return previousIsSuffix
      ? AiChatListChange.prepended
      : AiChatListChange.appended;
}
