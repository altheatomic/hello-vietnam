export interface RawCloneAuthorization {
  requestingUserId: string;
  ownerUserId: string | null;
  hasActiveForumShare: boolean;
}

export function isRawCloneAllowed(input: RawCloneAuthorization): boolean {
  return input.ownerUserId === input.requestingUserId || input.hasActiveForumShare;
}
