import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from evaluation.ai_quality.supabase_client import (
    SupabaseEvaluationClient,
    load_env_file,
)


class RecordingHandler(BaseHTTPRequestHandler):
    requests = []

    def log_message(self, format, *args):
        return

    def _record(self):
        length = int(self.headers.get("content-length", "0"))
        body = self.rfile.read(length) if length else b""
        self.__class__.requests.append(
            {
                "method": self.command,
                "path": self.path,
                "headers": {
                    key.lower(): value for key, value in self.headers.items()
                },
                "body": body,
            }
        )
        return body

    def _json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._record()
        if self.path.startswith("/rest/v1/subscription_plan"):
            self._json(200, [{"id_subscription_plan": "plan-001"}])
            return
        if self.path == "/image.jpg":
            body = b"\xff\xd8\xff\xe0test-jpeg"
            self.send_response(200)
            self.send_header("content-type", "image/jpeg")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        body = self._record()
        if self.path == "/auth/v1/admin/users":
            payload = json.loads(body)
            self.assertTrue(payload["email_confirm"])
            self._json(200, {"id": "user-001", "email": payload["email"]})
            return
        if self.path == "/auth/v1/token?grant_type=password":
            self._json(200, {"access_token": "user-jwt"})
            return
        if self.path == "/rest/v1/premium_subscription":
            self._json(201, {})
            return
        if self.path == "/functions/v1/ai-search":
            self._json(200, {"result_type": "food", "confidence": 0.8})
            return
        self._json(404, {"error": "not found"})

    def do_DELETE(self):
        self._record()
        self.send_response(204)
        self.end_headers()

    def assertTrue(self, value):
        if not value:
            raise AssertionError("expected truthy value")


class LocalApiServer:
    def __enter__(self):
        RecordingHandler.requests = []
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), RecordingHandler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.daemon = True
        self.thread.start()
        host, port = self.server.server_address
        self.base_url = f"http://{host}:{port}"
        return self

    def __exit__(self, exc_type, exc, traceback):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)


class EnvironmentLoadingTests(unittest.TestCase):
    def test_load_env_file_handles_quotes_and_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text(
                'SUPABASE_URL="https://project.test"\n'
                "SUPABASE_SERVICE_ROLE_KEY='secret-value'\n"
                "# ignored\n",
                encoding="utf-8",
            )

            values = load_env_file(path)

        self.assertEqual(values["SUPABASE_URL"], "https://project.test")
        self.assertEqual(values["SUPABASE_SERVICE_ROLE_KEY"], "secret-value")


class SupabaseEvaluationClientTests(unittest.TestCase):
    def test_invoke_uses_public_apikey_and_user_jwt(self):
        with LocalApiServer() as server:
            client = SupabaseEvaluationClient(
                server.base_url,
                anon_key="public-key",
                service_role_key="service-secret",
            )

            record = client.invoke(
                "ai-search",
                {"imageBase64": "abc"},
                access_token="user-jwt",
            )

        request = next(
            item
            for item in RecordingHandler.requests
            if item["path"] == "/functions/v1/ai-search"
        )
        self.assertTrue(record["ok"])
        self.assertEqual(request["headers"]["apikey"], "public-key")
        self.assertEqual(request["headers"]["authorization"], "Bearer user-jwt")
        self.assertEqual(json.loads(request["body"]), {"imageBase64": "abc"})

    def test_download_image_returns_bytes_mime_and_filename(self):
        with LocalApiServer() as server:
            client = SupabaseEvaluationClient(
                server.base_url,
                anon_key="public-key",
                service_role_key="service-secret",
            )

            image = client.download_image(f"{server.base_url}/image.jpg")

        self.assertEqual(image.mime_type, "image/jpeg")
        self.assertEqual(image.filename, "image.jpg")
        self.assertTrue(image.data.startswith(b"\xff\xd8"))
        image_request = next(
            item
            for item in RecordingHandler.requests
            if item["path"] == "/image.jpg"
        )
        self.assertEqual(
            image_request["headers"]["user-agent"],
            "HelloVietnam-AI-Evaluation/1.0",
        )

    def test_ephemeral_user_is_premium_and_cleanup_runs_after_failure(self):
        with LocalApiServer() as server:
            client = SupabaseEvaluationClient(
                server.base_url,
                anon_key="public-key",
                service_role_key="service-secret",
            )

            with self.assertRaisesRegex(RuntimeError, "provider failed"):
                with client.ephemeral_user() as user:
                    self.assertEqual(user.user_id, "user-001")
                    self.assertEqual(user.access_token, "user-jwt")
                    raise RuntimeError("provider failed")

        requests = RecordingHandler.requests
        create_index = next(
            index
            for index, item in enumerate(requests)
            if item["path"] == "/auth/v1/admin/users"
        )
        premium_index = next(
            index
            for index, item in enumerate(requests)
            if item["path"] == "/rest/v1/premium_subscription"
            and item["method"] == "POST"
        )
        cleanup_paths = [
            item["path"] for item in requests if item["method"] == "DELETE"
        ]
        self.assertLess(create_index, premium_index)
        self.assertIn(
            "/rest/v1/premium_subscription?id_user=eq.user-001",
            cleanup_paths,
        )
        self.assertEqual(cleanup_paths[-1], "/auth/v1/admin/users/user-001")


if __name__ == "__main__":
    unittest.main()
