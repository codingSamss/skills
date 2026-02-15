---
name: bird-twitter
description: "Read X/Twitter content via Bird CLI. Actions: read tweets, search, view bookmarks, trending, news, timeline, mentions, lists. Keywords: twitter, x, tweet, trending, bookmarks, timeline."
---

# Bird Twitter Skill (Read-Only)

Read X/Twitter content using the Bird CLI tool. This skill only exposes read-only operations to avoid account suspension risks.

## When to Use This Skill

Triggered by:
- "read tweet [id/url]", "show tweet [id/url]"
- "search twitter [query]", "search x [query]"
- "my bookmarks", "twitter bookmarks"
- "trending", "twitter trends", "what's trending"
- "twitter news", "x news"
- "timeline [username]", "user tweets [username]"
- "my mentions", "twitter mentions"
- "twitter lists", "my lists"
- "home timeline", "my feed"

## Prerequisites

1. Bird CLI must be installed: `brew install steipete/tap/bird`
2. Must be logged into X/Twitter in Chrome browser
3. In this environment, network access to X should go through local proxy:
   - `HTTP_PROXY=http://127.0.0.1:7897`
   - `HTTPS_PROXY=http://127.0.0.1:7897`
4. Run `HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 whoami` to verify authentication

## Global Options

All commands should use:
- proxy env (`HTTP_PROXY` / `HTTPS_PROXY`)
- `--cookie-source chrome` to only use Chrome cookies (skip Safari/Firefox)
- `--timeout 15000` to avoid hanging requests

Recommended command prefix:
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 <command>
```

Example:
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 home -n 20
```

## Commands

### 1. Check Auth Status
**Triggers:** "twitter auth", "bird whoami", "check twitter login"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 whoami
```

### 2. Read Tweet
**Triggers:** "read tweet [id]", "show tweet [url]", "get tweet"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 read <tweet-id-or-url>
```
Options: `--plain` for stable output without emoji/color

### 3. Read Thread
**Triggers:** "read thread [id]", "show thread [url]"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 thread <tweet-id-or-url>
```

### 4. Read Replies
**Triggers:** "show replies to [id]", "tweet replies"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 replies <tweet-id-or-url> -n 20
```

### 5. Search
**Triggers:** "search twitter [query]", "search x [query]", "find tweets about"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 search "<query>" -n 10
```

### 6. View Bookmarks
**Triggers:** "my bookmarks", "twitter bookmarks", "saved tweets"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 bookmarks -n 20
```

### 7. View Trending/News
**Triggers:** "trending", "twitter trends", "what's trending", "twitter news", "x news"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 news
```

### 8. View Home Timeline
**Triggers:** "home timeline", "my feed", "for you"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 home -n 20
```

### 9. View User Tweets
**Triggers:** "tweets from [username]", "timeline [username]", "[username]'s tweets"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 user-tweets <username> -n 20
```

### 10. View Likes
**Triggers:** "my likes", "liked tweets"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 likes -n 20
```

### 11. View Mentions
**Triggers:** "my mentions", "twitter mentions", "who mentioned me"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 mentions -n 20
```

### 12. View Lists
**Triggers:** "my lists", "twitter lists"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 lists
```

### 13. View List Timeline
**Triggers:** "list timeline [id]", "tweets from list"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 list-timeline <list-id-or-url> -n 20
```

### 14. View Following
**Triggers:** "who do I follow", "my following"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 following -n 50
```

### 15. View Followers
**Triggers:** "my followers", "who follows me"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 followers -n 50
```

### 16. User Info
**Triggers:** "about [username]", "user info [username]"
```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 bird --cookie-source chrome --timeout 15000 about <username>
```

## Output Options

All commands support these flags:
- `--plain` - Stable output without emoji or color (good for parsing)
- `-n <number>` or `--count <number>` - Limit number of results (default: 10)

## Important Notes

- This skill is READ-ONLY to avoid account suspension
- Uses unofficial X GraphQL API - may break without notice
- Requires browser login to X for cookie authentication
- If authentication fails, log into X in your browser and try again

## Excluded Commands (High Risk)

The following commands are intentionally NOT exposed due to account suspension risk:
- `bird tweet` - Post new tweets
- `bird reply` - Reply to tweets
- `bird follow` / `bird unfollow` - Follow/unfollow users
- `bird unbookmark` - Remove bookmarks
