#!/bin/sh
# 补上预建管理员的 email：上游 create_initial_superuser 只设 username，而 OIDC 按
# User.email 匹配用户（mozilla-django-oidc 的 filter_users_by_claims），
# email 空时登录会走 create_user 撞 username 的 UNIQUE 约束（500）。幂等：email 已对就跳过。
# /health 只查数据库连接，bootstrap 的 migrate 可能还没跑完：等 auth_user 表出现（最多 5 分钟）再动手。
set -e
cd /etc/linkding
i=0
until python manage.py shell -c "
from django.db import connection
print('ready' if connection.introspection.table_names() and 'auth_user' in connection.introspection.table_names() else 'wait')
" 2>/dev/null | grep -q ready; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { echo "等了 5 分钟数据库还没就绪"; exit 1; }
  sleep 5
done
python manage.py shell <<PY
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.filter(username="$LD_SUPERUSER_NAME").first()
if u is None:
    print("superuser 不存在，跳过")
elif (u.email or "") == "$WONTON_OWNER_EMAIL":
    print("email 已就位")
else:
    u.email = "$WONTON_OWNER_EMAIL"
    u.save(update_fields=["email"])
    print("email 已补上")
PY
