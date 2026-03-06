#!/usr/bin/env python3
"""Post a tweet via Twitter API v2 with OAuth 1.0a. Proven working on Windows."""
import urllib.request, urllib.parse, hmac, hashlib, base64, time, os, json, uuid, sys

def post_tweet(text):
    api_key = os.environ.get('TWITTER_API_KEY', '')
    api_secret = os.environ.get('TWITTER_API_SECRET', '')
    access_token = os.environ.get('TWITTER_ACCESS_TOKEN', '')
    access_secret = os.environ.get('TWITTER_ACCESS_TOKEN_SECRET', '')

    if not all([api_key, api_secret, access_token, access_secret]):
        print('ERROR: Twitter env vars not set (TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_TOKEN_SECRET)', file=sys.stderr)
        sys.exit(1)

    url = 'https://api.twitter.com/2/tweets'
    method = 'POST'
    oauth_nonce = uuid.uuid4().hex
    oauth_timestamp = str(int(time.time()))

    params = {
        'oauth_consumer_key': api_key,
        'oauth_nonce': oauth_nonce,
        'oauth_signature_method': 'HMAC-SHA256',
        'oauth_timestamp': oauth_timestamp,
        'oauth_token': access_token,
        'oauth_version': '1.0'
    }

    param_string = '&'.join(f'{urllib.parse.quote(k, safe="")}'
                            f'={urllib.parse.quote(v, safe="")}' for k, v in sorted(params.items()))
    base_string = f'{method}&{urllib.parse.quote(url, safe="")}&{urllib.parse.quote(param_string, safe="")}'
    signing_key = f'{urllib.parse.quote(api_secret, safe="")}&{urllib.parse.quote(access_secret, safe="")}'
    signature = base64.b64encode(
        hmac.new(signing_key.encode(), base_string.encode(), hashlib.sha256).digest()
    ).decode()

    auth_header = 'OAuth ' + ', '.join([
        f'oauth_consumer_key="{urllib.parse.quote(api_key, safe="")}"',
        f'oauth_nonce="{oauth_nonce}"',
        f'oauth_signature="{urllib.parse.quote(signature, safe="")}"',
        f'oauth_signature_method="HMAC-SHA256"',
        f'oauth_timestamp="{oauth_timestamp}"',
        f'oauth_token="{urllib.parse.quote(access_token, safe="")}"',
        f'oauth_version="1.0"'
    ])

    body = json.dumps({'text': text}).encode()
    req = urllib.request.Request(url, data=body, headers={
        'Authorization': auth_header,
        'Content-Type': 'application/json'
    }, method='POST')

    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read().decode())
        tweet_id = data.get('data', {}).get('id', 'unknown')
        print(json.dumps({"ok": True, "id": tweet_id}))
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(json.dumps({"ok": False, "status": e.code, "error": body}), file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python3 twitter.py "tweet text"', file=sys.stderr)
        sys.exit(1)
    post_tweet(sys.argv[1])
