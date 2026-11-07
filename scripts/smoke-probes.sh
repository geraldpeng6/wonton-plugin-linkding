# shellcheck shell=bash
# Linkding：sso=oidc；清单没有 mcp。

web_assert() { grep -qi 'linkding'; }   # 标准输入：登录页或书签页，都是应用自己的页面

# 走完一次 OIDC：/oidc/authenticate/ 跳到 Hydra，核心会话自动确认，回调建应用会话。
# web_login 只走到应用根路径，linkding 根路径不发起 OIDC，所以每个要会话的探针都自己登一次。
oidc_login() {
  local final
  # 先打一下应用根路径，网关才发插件域的会话 Cookie（web_login 也做了这一步）。
  curl -sS --noproxy '*' --max-time 60 -o /dev/null -L -H 'Accept: text/html' \
    -b "$SMOKE_JAR" -c "$SMOKE_JAR" "$SMOKE_WEB_URL/" || { echo "打不开应用根路径"; return 1; }
  final="$(curl -sS --noproxy '*' --max-time 120 -o /dev/null -w '%{url_effective}' -L --max-redirs 30 \
    -b "$SMOKE_JAR" -c "$SMOKE_JAR" "$SMOKE_WEB_URL/oidc/authenticate/")" || final=""
  grep -q '/bookmarks' <<<"$final" || { echo "登录链没有落到应用：${final:-（空）}"; return 1; }
}

# 会话里的 /bookmarks 有 Admin 链接（只有超管有），Django admin 的用户列表里有这个账号。
identity_check() {
  local page
  oidc_login || return 1
  page="$(web_get /bookmarks)" || { echo "打开书签页失败：$page"; return 1; }
  grep -q '/admin/' <<<"$page" || { echo "nav 里没有 Admin 链接，不是管理员"; return 1; }
  page="$(web_get /admin/auth/user/)" || { echo "打开 admin 用户列表失败：$page"; return 1; }
  grep -qF ">$SMOKE_OWNER<" <<<"$page" || { echo "admin 用户列表里没有 $SMOKE_OWNER：$(head -c 200 <<<"$page")"; return 1; }
}

bookmark_url() { echo "https://example.com/$SMOKE_INSTANCE-$1"; }

# 用应用自己的 REST API 加一条书签（Django 只对带 Cookie 的写请求查 CSRF）。
data_write() {
  local csrf page
  oidc_login || return 1
  page="$(web_get /bookmarks)" || { echo "取 CSRF Cookie 失败：$page"; return 1; }
  csrf="$(awk '$6=="ld_csrftoken"{v=$7} END{print v}' "$SMOKE_JAR")"
  [[ -n "$csrf" ]] || { echo "没有 ld_csrftoken Cookie"; return 1; }
  page="$(curl -sS --noproxy '*' --max-time 60 --fail-with-body -b "$SMOKE_JAR" -c "$SMOKE_JAR" -X POST \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H "X-CSRFToken: $csrf" -H "Referer: $SMOKE_WEB_URL/" \
    -d "{\"url\":\"$(bookmark_url smoke)\",\"title\":\"wonton smoke\"}" \
    "$SMOKE_WEB_URL/api/bookmarks/")" || { echo "建书签失败：$page"; return 1; }
  jq -e --arg u "$(bookmark_url smoke)" '.url == $u' <<<"$page" >/dev/null || { echo "书签没建成：$page"; return 1; }
}

# 重装以后还搜得到。
data_check() {
  local found
  oidc_login || return 1
  found="$(web_get "/api/bookmarks/?q=$SMOKE_INSTANCE-smoke")" || { echo "搜索失败：$found"; return 1; }
  jq -e --arg u "$(bookmark_url smoke)" 'any(.results[]; .url == $u)' <<<"$found" >/dev/null ||
    { echo "搜不到数据检查用的书签：$found"; return 1; }
}
