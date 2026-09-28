#!/usr/bin/env python3
"""Make one low-cost, live check of an Anthropic API key.

The script discovers one model and makes one minimal Messages request. It never
retries and uses only Python's standard library.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from getpass import getpass
from typing import Any


MODELS_URL = "https://api.anthropic.com/v1/models"
MESSAGES_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
DEFAULT_TIMEOUT_SECONDS = 15


def read_api_key() -> str:
    return getpass("Paste Anthropic API key (input hidden): ").strip()


def extract_error(body: bytes) -> tuple[str, str, str | None, dict[str, Any]]:
    """Return Anthropic error type, message, request ID, and error details."""
    try:
        payload: Any = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return "unknown_error", body.decode("utf-8", errors="replace").strip(), None, {}

    error = payload.get("error", {}) if isinstance(payload, dict) else {}
    error_type = error.get("type", "unknown_error")
    message = error.get("message", "No error message returned.")
    request_id = payload.get("request_id") if isinstance(payload, dict) else None
    details = error.get("details", {}) if isinstance(error, dict) else {}
    if not isinstance(details, dict):
        details = {}
    return str(error_type), str(message), request_id, details


def response_headers(headers: Any) -> dict[str, str]:
    """Keep useful diagnostics without dumping unrelated response headers."""
    wanted = {"request-id", "retry-after"}
    result: dict[str, str] = {}
    for name, value in headers.items():
        lower_name = name.lower()
        if lower_name in wanted or lower_name.startswith("anthropic-ratelimit"):
            result[lower_name] = value
    return result


def diagnosis(
    status: int,
    error_type: str,
    message: str,
    details: dict[str, Any] | None = None,
) -> str:
    lower_message = message.lower()
    error_code = (details or {}).get("error_code")

    if error_code == "enforced_spend_limit_reached":
        return "Anthropic says the organization has reached its enforced API spend/usage limit."

    if status == 401:
        return "The key is invalid, revoked, expired, or malformed."
    if status == 402:
        return "Anthropic reported a billing or payment problem for this organization."
    if status == 403:
        return "The key is recognized, but it does not have permission for this endpoint."
    if status == 429:
        return (
            "Anthropic reported a rate limit or usage/spend cap. "
            "A 429 alone cannot distinguish those cases; inspect the message and retry-after header."
        )
    if status == 400 and any(
        term in lower_message for term in ("spend", "usage", "limit", "credit", "billing")
    ):
        return "The request was rejected because an organization/workspace usage or spend limit may have been reached."
    if status in (500, 504, 529):
        return "This looks temporary: Anthropic reported a server, timeout, or overload error."
    if status == 404:
        return "The endpoint was not found; check that this is a direct Anthropic API key, not a different provider's key."
    if error_type == "unknown_error":
        return "Anthropic returned an unrecognized error; use the message and request ID for diagnosis."
    return "The key was not accepted for this request; use the returned error details for diagnosis."


def http_error_result(error: urllib.error.HTTPError, endpoint: str) -> tuple[int, dict[str, Any]]:
    raw_body = error.read()
    error_type, message, body_request_id, details = extract_error(raw_body)
    headers = response_headers(error.headers)
    request_id = headers.get("request-id") or body_request_id
    return 2, {
        "ok": False,
        "status": error.code,
        "endpoint": endpoint,
        "error_type": error_type,
        "message": message,
        "details": details,
        "diagnosis": diagnosis(error.code, error_type, message, details),
        "request_id": request_id,
        "headers": headers,
    }


def probe_messages(api_key: str, model_id: str, timeout: float) -> tuple[int, dict[str, Any]]:
    """Test the actual inference endpoint with at most one output token."""
    body = json.dumps(
        {
            "model": model_id,
            "max_tokens": 1,
            "messages": [{"role": "user", "content": "Reply with OK."}],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        MESSAGES_URL,
        data=body,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "anthropic-version": ANTHROPIC_VERSION,
            "x-api-key": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
            usage = payload.get("usage", {}) if isinstance(payload, dict) else {}
            return 0, {
                "ok": True,
                "status": response.status,
                "check": "messages",
                "endpoint": MESSAGES_URL,
                "model": model_id,
                "input_tokens": usage.get("input_tokens"),
                "output_tokens": usage.get("output_tokens"),
                "request_id": response.headers.get("request-id"),
                "headers": response_headers(response.headers),
                "message": "The Messages API accepted a minimal live inference request.",
            }
    except urllib.error.HTTPError as error:
        return http_error_result(error, MESSAGES_URL)
    except urllib.error.URLError as error:
        return 3, {
            "ok": False,
            "status": None,
            "endpoint": MESSAGES_URL,
            "error_type": "network_error",
            "message": str(error.reason),
            "diagnosis": "The request did not receive an HTTP response from Anthropic.",
            "request_id": None,
            "headers": {},
        }
    except TimeoutError:
        return 3, {
            "ok": False,
            "status": None,
            "endpoint": MESSAGES_URL,
            "error_type": "timeout",
            "message": f"No response within {timeout:g} seconds.",
            "diagnosis": "Increase --timeout or check the network, then try once more.",
            "request_id": None,
            "headers": {},
        }


def check_key(
    api_key: str, timeout: float, probe_messages_endpoint: bool = False
) -> tuple[int, dict[str, Any]]:
    query = urllib.parse.urlencode({"limit": "1"})
    request = urllib.request.Request(
        f"{MODELS_URL}?{query}",
        headers={
            "Accept": "application/json",
            "anthropic-version": ANTHROPIC_VERSION,
            "x-api-key": api_key,
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw_body = response.read()
            payload = json.loads(raw_body.decode("utf-8"))
            models = payload.get("data", []) if isinstance(payload, dict) else []
            model_id = None
            if isinstance(models, list) and models and isinstance(models[0], dict):
                model_id = models[0].get("id")

            if probe_messages_endpoint and model_id:
                return probe_messages(api_key, str(model_id), timeout)

            if probe_messages_endpoint and not model_id:
                return 2, {
                    "ok": False,
                    "status": 200,
                    "endpoint": MODELS_URL,
                    "error_type": "no_models_available",
                    "message": "The key was accepted, but no model was returned for the Messages probe.",
                    "diagnosis": "No model was available to test the inference endpoint.",
                    "request_id": response.headers.get("request-id"),
                    "headers": response_headers(response.headers),
                }

            return 0, {
                "ok": True,
                "status": response.status,
                "check": "models",
                "endpoint": MODELS_URL,
                "models_returned": len(models) if isinstance(models, list) else 0,
                "model": model_id,
                "request_id": response.headers.get("request-id"),
                "headers": response_headers(response.headers),
                "message": "The key was accepted by Anthropic's live Models API. Inference was not tested.",
            }
    except urllib.error.HTTPError as error:
        return http_error_result(error, MODELS_URL)
    except urllib.error.URLError as error:
        reason = str(error.reason)
        return 3, {
            "ok": False,
            "status": None,
            "error_type": "network_error",
            "message": reason,
            "diagnosis": "The request did not receive an HTTP response from Anthropic.",
            "request_id": None,
            "headers": {},
        }
    except TimeoutError:
        return 3, {
            "ok": False,
            "status": None,
            "error_type": "timeout",
            "message": f"No response within {timeout:g} seconds.",
            "diagnosis": "Increase --timeout or check the network, then try once more.",
            "request_id": None,
            "headers": {},
        }


def print_human_result(exit_code: int, result: dict[str, Any]) -> None:
    print("\n" + "=" * 62)
    if exit_code == 0 and result.get("check") == "messages":
        print("STATUS: MESSAGES API ACCEPTED")
    elif exit_code == 0:
        print("STATUS: METADATA API ACCEPTED (INFERENCE NOT TESTED)")
    elif result.get("status") is None:
        print("STATUS: NO HTTP RESPONSE")
    else:
        print(f"STATUS: CHECK FAILED (HTTP {result['status']})")
    print("=" * 62)

    if exit_code == 0 and result.get("check") == "messages":
        print(result["message"])
        print(f"Model tested: {result['model']}")
        if result.get("input_tokens") is not None:
            print(f"Input tokens used: {result['input_tokens']}")
        if result.get("output_tokens") is not None:
            print(f"Output tokens used: {result['output_tokens']}")
    elif exit_code == 0:
        print(result["message"])
        print(f"Models visible to this key: {result['models_returned']}")
        print("No prompt was sent and no model inference was tested.")
    else:
        if result.get("endpoint"):
            print(f"Endpoint:   {result['endpoint']}")
        print(f"Error type: {result['error_type']}")
        print(f"Message:    {result['message']}")
        print(f"Diagnosis:  {result['diagnosis']}")
        if result.get("details"):
            print(f"Details:    {json.dumps(result['details'])}")

    if result.get("request_id"):
        print(f"Request ID: {result['request_id']}")
    if result.get("headers"):
        print("Useful response headers:")
        for name, value in result["headers"].items():
            print(f"  {name}: {value}")

    if exit_code == 3:
        print("\nThis was a connectivity failure, not evidence that the key is invalid.")


def main() -> int:
    try:
        api_key = read_api_key()
    except (KeyboardInterrupt, EOFError):
        print("\nAborted.", file=sys.stderr)
        return 130
    except ValueError as error:
        print(f"Input error: {error}", file=sys.stderr)
        return 1

    if not api_key:
        print("No key provided. Exiting.", file=sys.stderr)
        return 1

    print(
        "\nMaking one live metadata request plus one minimal Messages request (no retries)..."
    )
    try:
        exit_code, result = check_key(api_key, DEFAULT_TIMEOUT_SECONDS, True)
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        return 130

    print_human_result(exit_code, result)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
