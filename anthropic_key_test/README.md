# Anthropic API key test

`anthropic_key_test.py` makes one live metadata request and one minimal Messages
request. It uses only Python's standard library, has no dependencies, and does
not retry, so `Ctrl-C` stops it immediately.

This is not a balance reader. A successful check means Anthropic accepted the
key for a minimal Messages request at that moment.

## Run it

```bash
python3 anthropic_key_test.py
```

Paste the key when prompted. Input is hidden and the key is never printed.

The script first discovers one model, then sends a tiny `POST /v1/messages`
request with `max_tokens: 1`. It may consume a very small amount of usage if
the request is allowed. If the account is blocked by an enforced spend cap,
the script reports Anthropic's HTTP error, message, request ID, and error
details.

Exit codes:

- `0`: minimal Messages request accepted
- `1`: local input problem
- `2`: Anthropic returned an HTTP/API error
- `3`: network or timeout failure; this does not prove the key is invalid
- `130`: interrupted with `Ctrl-C`

The script reports the HTTP status, Anthropic error type/message, request ID,
`retry-after`, and available Anthropic rate-limit headers. Do not paste your key
into an issue, chat, commit, shell history, or log.

The endpoint and required headers follow Anthropic's API documentation:

- [List Models](https://platform.claude.com/docs/en/api/models/list)
- [API errors](https://platform.claude.com/docs/en/api/errors)
