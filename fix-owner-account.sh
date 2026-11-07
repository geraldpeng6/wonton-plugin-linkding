#!/bin/sh
# 保证主人账号能对上 OIDC 的 sub：username 就是 sub（云吞的账号名，装好后不变），email 当资料同步成新值。
#
# 上游 mozilla-django-oidc 按 email 匹配已有账号，改邮箱后找不到人；插件换成按 sub 匹配
# （oidc-backend.py）。旧版本按邮箱建号，这里按 sub、旧邮箱（username=email）、email 找那个号改名，
# 都找不到才新建；别的本地超管不动。幂等，每次启动都跑。不设密码，只能经 OIDC 进来。
#
# /health 只查数据库连接，bootstrap 的 migrate 可能还没跑完：等 auth_user 表出现（最多 5 分钟）再动手。
set -e
SUB="${WONTON_OWNER_NAME:?}"
EMAIL="${WONTON_OWNER_EMAIL:?}"
cd /etc/linkding
i=0
until python manage.py shell -c "
from django.db import connection
print('ready' if 'auth_user' in connection.introspection.table_names() else 'wait')
" 2>/dev/null | grep -q ready; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { echo "等了 5 分钟数据库还没就绪"; exit 1; }
  sleep 5
done
python manage.py shell <<PY
from django.contrib.auth import get_user_model

User = get_user_model()
sub, email = "$SUB", "$EMAIL"
user = User.objects.filter(username=sub).first()
if user is None:
    # 旧版本的账号 username 是当时的邮箱；邮箱后来又改过时按 email 字段找。
    user = (
        User.objects.filter(username__iexact=email).first()
        or User.objects.filter(email=email).first()
    )
    if user is None:
        user = User(username=sub)
        user.set_unusable_password()
    user.username = sub
user.is_superuser = True
user.is_staff = True
user.email = email
user.save()
print("主人账号已就位：" + sub)
PY
