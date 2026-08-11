"""Immutable scope and safety limits for the place content backfill."""

APPROVED_PROVINCES = (
    "094014a7-b8f6-481a-bbce-5ed6cdd457c5",  # Ho Chi Minh City
    "b5f3ef5e-dc49-4482-88e3-a8048cb32639",  # Hue
    "3355c4a1-ccb1-46be-99e5-046d5f55b891",  # Ha Noi
    "8f9d18e3-7e24-4e36-bf50-a3823c1f78df",  # Quang Ninh
    "49fa7ad8-b892-494d-a712-bb49802200c1",  # Lam Dong
)

# Keep the spelling/ordering used by the audit output stable.
PROVINCE_EXPECTED_COUNTS = {
    APPROVED_PROVINCES[0]: 539,
    APPROVED_PROVINCES[1]: 201,
    APPROVED_PROVINCES[2]: 235,
    APPROVED_PROVINCES[3]: 200,
    APPROVED_PROVINCES[4]: 358,
}
EXPECTED_TOTAL = sum(PROVINCE_EXPECTED_COUNTS.values())
MAX_APPLY_BATCH_SIZE = 50
PROMPT_VERSION = "place_content_v3"
ARTIFACT_STREAMS = (
    "baseline",
    "sources",
    "proposals",
    "approved",
    "applied",
    "rollback",
)
SECRET_KEY_MARKERS = (
    "api_key",
    "apikey",
    "access_token",
    "authorization",
    "database_url",
    "deepseek",
    "password",
    "secret",
    "service_role",
)
