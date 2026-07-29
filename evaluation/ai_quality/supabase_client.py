from __future__ import annotations

import json
import mimetypes
import secrets
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any, Iterator
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class DownloadedImage:
    data: bytes
    mime_type: str
    filename: str


@dataclass(frozen=True)
class EphemeralEvaluationUser:
    user_id: str
    email: str
    access_token: str = field(repr=False)


class EvaluationHttpError(RuntimeError):
    def __init__(self, status_code: int, message: str):
        super().__init__(f"HTTP {status_code}: {message}")
        self.status_code = status_code
        self.message = message


def load_env_file(path: str | Path) -> dict[str, str]:
    values: dict[str, str] = {}
    with Path(path).open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, raw_value = stripped.split("=", 1)
            key = key.strip()
            value = raw_value.strip()
            if (
                len(value) >= 2
                and value[0] == value[-1]
                and value[0] in {'"', "'"}
            ):
                value = value[1:-1]
            values[key] = value
    return values


class SupabaseEvaluationClient:
    def __init__(
        self,
        base_url: str,
        *,
        anon_key: str,
        service_role_key: str,
        timeout_seconds: float = 60.0,
    ):
        self.base_url = base_url.rstrip("/")
        self._anon_key = anon_key
        self._service_role_key = service_role_key
        self.timeout_seconds = timeout_seconds

    def invoke(
        self,
        function_name: str,
        payload: dict[str, Any],
        *,
        access_token: str,
    ) -> dict[str, Any]:
        started = time.perf_counter()
        try:
            status, _, body = self._request(
                "POST",
                f"/functions/v1/{function_name}",
                headers={
                    "apikey": self._anon_key,
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
                body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            )
            response = _decode_json_object(body)
            return {
                "ok": 200 <= status < 300,
                "status_code": status,
                "latency_ms": round(
                    (time.perf_counter() - started) * 1000, 3
                ),
                "response": response,
                "error": None if 200 <= status < 300 else _provider_error(response),
            }
        except EvaluationHttpError as error:
            return {
                "ok": False,
                "status_code": error.status_code,
                "latency_ms": round(
                    (time.perf_counter() - started) * 1000, 3
                ),
                "response": {},
                "error": error.message,
            }
        except (URLError, TimeoutError, OSError) as error:
            return {
                "ok": False,
                "status_code": None,
                "latency_ms": round(
                    (time.perf_counter() - started) * 1000, 3
                ),
                "response": {},
                "error": type(error).__name__,
            }

    def download_image(self, url: str) -> DownloadedImage:
        status, headers, data = self._request(
            "GET",
            url,
            headers={"User-Agent": "HelloVietnam-AI-Evaluation/1.0"},
        )
        if not 200 <= status < 300:
            raise EvaluationHttpError(status, "image download failed")
        parsed = urlparse(url)
        filename = Path(parsed.path).name or "image.jpg"
        header_mime = headers.get("content-type", "").split(";", 1)[0].strip()
        guessed_mime = mimetypes.guess_type(filename)[0]
        mime_type = header_mime or guessed_mime or "image/jpeg"
        return DownloadedImage(
            data=data,
            mime_type=mime_type,
            filename=filename,
        )

    def is_url_reachable(self, url: str) -> bool:
        try:
            status, _, body = self._request(
                "GET",
                url,
                headers={"Range": "bytes=0-15"},
            )
            return 200 <= status < 400 and len(body) > 0
        except (EvaluationHttpError, URLError, TimeoutError, OSError):
            return False

    @contextmanager
    def ephemeral_user(self) -> Iterator[EphemeralEvaluationUser]:
        email = f"ai-eval-{uuid.uuid4().hex}@example.invalid"
        password = secrets.token_urlsafe(24)
        user_id: str | None = None
        try:
            created = self._service_json(
                "POST",
                "/auth/v1/admin/users",
                {
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {"full_name": "AI Evaluation"},
                },
            )
            user_object = (
                created.get("user")
                if isinstance(created.get("user"), dict)
                else created
            )
            user_id = _required_string(user_object, "id")

            signed_in = self._anon_json(
                "POST",
                "/auth/v1/token?grant_type=password",
                {"email": email, "password": password},
            )
            access_token = _required_string(signed_in, "access_token")
            self._grant_temporary_premium(user_id)
            yield EphemeralEvaluationUser(
                user_id=user_id,
                email=email,
                access_token=access_token,
            )
        finally:
            if user_id is not None:
                self._cleanup_ephemeral_user(user_id)

    def _grant_temporary_premium(self, user_id: str) -> None:
        plans = self._service_json(
            "GET",
            "/rest/v1/subscription_plan"
            "?select=id_subscription_plan"
            "&status=eq.active"
            "&order=duration_days.desc"
            "&limit=1",
        )
        if not isinstance(plans, list) or not plans:
            raise RuntimeError("No active subscription plan is available")
        plan_id = _required_string(plans[0], "id_subscription_plan")
        now = datetime.now(UTC)
        self._service_json(
            "POST",
            "/rest/v1/premium_subscription",
            {
                "id_user": user_id,
                "id_plan": plan_id,
                "start_date": now.isoformat(),
                "end_date": (now + timedelta(days=1)).isoformat(),
                "currency": "VND",
                "status": "active",
            },
        )

    def _cleanup_ephemeral_user(self, user_id: str) -> None:
        public_targets = (
            ("premium_subscription", "id_user"),
            ("ai_usage_log", "id_user"),
            ("ai_user_quota", "id_user"),
            ("user_translation_limits", "user_id"),
            ("ai_chat_conversation", "id_user"),
            ("user_contact", "id_user"),
            ("user_account", "id_user"),
        )
        for table, column in public_targets:
            self._best_effort_delete(
                f"/rest/v1/{table}?{column}=eq.{user_id}",
                service=True,
            )
        self._best_effort_delete(
            f"/auth/v1/admin/users/{user_id}",
            service=True,
        )

    def _best_effort_delete(self, path: str, *, service: bool) -> None:
        key = self._service_role_key if service else self._anon_key
        try:
            self._request(
                "DELETE",
                path,
                headers={
                    "apikey": key,
                    "Authorization": f"Bearer {key}",
                },
            )
        except (EvaluationHttpError, URLError, TimeoutError, OSError):
            pass

    def _service_json(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> Any:
        key = self._service_role_key
        return self._request_json(
            method,
            path,
            payload,
            headers={
                "apikey": key,
                "Authorization": f"Bearer {key}",
            },
        )

    def _anon_json(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> Any:
        return self._request_json(
            method,
            path,
            payload,
            headers={"apikey": self._anon_key},
        )

    def _request_json(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None,
        *,
        headers: dict[str, str],
    ) -> Any:
        request_headers = {
            **headers,
            "Accept": "application/json",
        }
        body = None
        if payload is not None:
            request_headers["Content-Type"] = "application/json"
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        _, _, response_body = self._request(
            method,
            path,
            headers=request_headers,
            body=body,
        )
        if not response_body:
            return {}
        try:
            return json.loads(response_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RuntimeError("Supabase returned invalid JSON") from error

    def _request(
        self,
        method: str,
        path_or_url: str,
        *,
        headers: dict[str, str] | None = None,
        body: bytes | None = None,
    ) -> tuple[int, dict[str, str], bytes]:
        url = (
            path_or_url
            if path_or_url.startswith(("http://", "https://"))
            else f"{self.base_url}{path_or_url}"
        )
        request = Request(
            url,
            data=body,
            method=method,
            headers=headers or {},
        )
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:
                return (
                    int(response.status),
                    {key.lower(): value for key, value in response.headers.items()},
                    response.read(),
                )
        except HTTPError as error:
            response_body = error.read()
            message = _provider_error(_decode_json_object(response_body))
            raise EvaluationHttpError(error.code, message) from error


def _decode_json_object(body: bytes) -> dict[str, Any]:
    if not body:
        return {}
    try:
        value = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {"data": value}


def _provider_error(value: dict[str, Any]) -> str:
    for key in ("error", "message", "error_message", "errorMessage"):
        nested = value.get(key)
        if isinstance(nested, str) and nested.strip():
            return nested.strip()
        if isinstance(nested, dict):
            message = nested.get("message")
            if isinstance(message, str) and message.strip():
                return message.strip()
    return "request failed"


def _required_string(value: Any, key: str) -> str:
    if not isinstance(value, dict):
        raise RuntimeError(f"Supabase response is missing '{key}'")
    result = value.get(key)
    if not isinstance(result, str) or not result.strip():
        raise RuntimeError(f"Supabase response is missing '{key}'")
    return result.strip()
