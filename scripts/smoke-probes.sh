# shellcheck shell=bash
# Linkding：sso=oidc；清单没有 mcp。

web_assert() { grep -qi 'linkding'; }   # 标准输入：登录页或书签页，都是应用自己的页面

# 走完一次 OIDC：清单 webui.path 就是 OIDC 起点（/oidc/authenticate/），SMOKE_WEB_URL 带着这个
# 路径，直接请求它，核心会话在 Hydra 自动确认，回调建应用会话。
oidc_login() {
  local final try
  # 安装刚完成时 uwsgi 首个 OIDC 往返可能 502：失败等 10 秒重试，共三次。
  for try in 1 2 3; do
    final="$(curl -sS --noproxy '*' --max-time 120 -o /dev/null -w '%{url_effective}' -L --max-redirs 30 \
      -b "$SMOKE_JAR" -c "$SMOKE_JAR" "$SMOKE_WEB_URL")" || final=""
    grep -q '/bookmarks' <<<"$final" && break
    (( try < 3 )) && sleep 10
  done
  grep -q '/bookmarks' <<<"$final" || { echo "登录链没有落到应用：${final:-（空）}"; return 1; }
}

# 会话里的 /bookmarks 有 Admin 链接（只有超管有），Django admin 的用户列表里有这个账号。
ld_page() { # <应用路径>：带会话请求应用自己的路由。清单 webui.path 是 OIDC 起点，SMOKE_WEB_URL 带着它；
  # 应用的路由要拼在 SMOKE_WEB_ORIGIN 后，接在 SMOKE_WEB_URL 后会变成 /oidc/authenticate//bookmarks。
  curl -sS --noproxy '*' --max-time 120 -b "$SMOKE_JAR" -c "$SMOKE_JAR" -H 'Accept: text/html' "$SMOKE_WEB_ORIGIN$1"
}

identity_check() {
  local page
  oidc_login || return 1
  page="$(ld_page /bookmarks)" || { echo "打开书签页失败：$page"; return 1; }
  grep -q '/admin/' <<<"$page" || { echo "nav 里没有 Admin 链接，不是管理员"; return 1; }
  page="$(ld_page /admin/auth/user/)" || { echo "打开 admin 用户列表失败：$page"; return 1; }
  grep -qF ">$SMOKE_OWNER<" <<<"$page" || { echo "admin 用户列表里没有 $SMOKE_OWNER：$(head -c 200 <<<"$page")"; return 1; }
}

bookmark_url() { echo "https://example.com/$SMOKE_INSTANCE-$1"; }

# 用应用自己的 REST API 加一条书签（Django 只对带 Cookie 的写请求查 CSRF）。
data_write() {
  local csrf page
  oidc_login || return 1
  page="$(ld_page /bookmarks)" || { echo "取 CSRF Cookie 失败：$page"; return 1; }
  csrf="$(awk '$6=="ld_csrftoken"{v=$7} END{print v}' "$SMOKE_JAR")"
  [[ -n "$csrf" ]] || { echo "没有 ld_csrftoken Cookie"; return 1; }
  page="$(curl -sS --noproxy '*' --max-time 60 --fail-with-body -b "$SMOKE_JAR" -c "$SMOKE_JAR" -X POST \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H "X-CSRFToken: $csrf" -H "Referer: $SMOKE_WEB_ORIGIN/" \
    -d "{\"url\":\"$(bookmark_url smoke)\",\"title\":\"wonton smoke\"}" \
    "$SMOKE_WEB_ORIGIN/api/bookmarks/")" || { echo "建书签失败：$page"; return 1; }
  jq -e --arg u "$(bookmark_url smoke)" '.url == $u' <<<"$page" >/dev/null || { echo "书签没建成：$page"; return 1; }
}

# 重装以后还搜得到。
data_check() {
  local found
  oidc_login || return 1
  found="$(curl -sS --noproxy '*' --max-time 120 -b "$SMOKE_JAR" -H 'Accept: application/json' \
    "$SMOKE_WEB_ORIGIN/api/bookmarks/?q=$SMOKE_INSTANCE-smoke")" || { echo "搜索失败：$found"; return 1; }
  jq -e --arg u "$(bookmark_url smoke)" 'any(.results[]; .url == $u)' <<<"$found" >/dev/null ||
    { echo "搜不到数据检查用的书签：$found"; return 1; }
}
