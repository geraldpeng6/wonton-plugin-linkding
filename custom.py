"""换成上游留的 settings 挂载点（bookmarks/settings/custom.py）：按 OIDC 的 sub 认人。

上游 linkding 用 mozilla-django-oidc 的默认后端，它按 email 找已有账号；云吞里改了邮箱就
找不到人，登录会另建一个账号。云吞的 sub 是自己的账号名，装好后不变，改邮箱不影响它。

后端类放在另一个模块里：这里在加载 settings 时就被导入，此时 Django 的 app 还没就绪，
直接 import mozilla_django_oidc.auth 会 AppRegistryNotReady。Django 认人时再按点分路径导入。
"""

# 新建账号的 username 也从 sub 来（上游的 generate_username 读这个设置）。
OIDC_USERNAME_CLAIM = "sub"

# 带 sub 的后端换掉默认的 OIDC 后端；ModelBackend 留给本地超管。
AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
    "bookmarks.oidc_backend.SubjectBackend",
]
