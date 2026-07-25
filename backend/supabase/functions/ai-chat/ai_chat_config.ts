const DEFAULT_DEEPSEEK_CHAT_MODEL = "deepseek-v4-flash";

export function resolveDeepSeekChatModel(
  configuredModel: string | undefined,
): string {
  const model = configuredModel?.trim();
  return model ? model : DEFAULT_DEEPSEEK_CHAT_MODEL;
}
