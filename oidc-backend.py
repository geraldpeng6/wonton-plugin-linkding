"""OIDC 按 sub 认人，邮箱只当资料，每次登录同步成新值。

上游 linkding 用 mozilla-django-oidc 的默认后端，它按 email 找已有账号
（mozilla_django_oidc.auth.OIDCAuthenticationBackend.filter_users_by_claims），
云吞里改了邮箱就找不到人，登录会另建一个账号。云吞的 sub 是自己的账号名，装好后不变，
改邮箱不影响它；LD_SUPERUSER_NAME 和新建账号的 username 都用它。

挂到 bookmarks/oidc_backend.py。Django 只在认人时导入它（settings 加载时 Django 还没就绪，
在 custom.py 里直接导入 mozilla_django_oidc.auth 会 AppRegistryNotReady）。
"""

from mozilla_django_oidc.auth import OIDCAuthenticationBackend


class SubjectBackend(OIDCAuthenticationBackend):
    def filter_users_by_claims(self, claims):
        sub = claims.get("sub")
        if not sub:
            return self.UserModel.objects.none()
        return self.UserModel.objects.filter(username__iexact=sub)

    def update_user(self, user, claims):
        email = claims.get("email")
        if email and user.email != email:
            user.email = email
            user.save(update_fields=["email"])
        return user
