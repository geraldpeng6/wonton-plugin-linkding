"""OIDC 按 sub 认人，邮箱只当资料，每次登录同步成新值。

上游 linkding 用 mozilla-django-oidc 的默认后端，它按 email 找已有账号
（mozilla_django_oidc.auth.OIDCAuthenticationBackend.filter_users_by_claims），
云吞里改了邮箱就找不到人，登录会另建一个账号。云吞的 sub 是自己的账号名，装好后不变，
改邮箱不影响它；新建账号的 username 也用它。

旧版本按邮箱建号（username 就是当时的邮箱），sub 找不到时按 username=email 再找一次，
找到就在登录时把 username 改成 sub，账号和书签都跟着过来。

挂到 bookmarks/oidc_backend.py。Django 只在认人时导入它（settings 加载时 Django 还没就绪，
在 custom.py 里直接导入 mozilla_django_oidc.auth 会 AppRegistryNotReady）。
"""

from mozilla_django_oidc.auth import OIDCAuthenticationBackend


class SubjectBackend(OIDCAuthenticationBackend):
    def filter_users_by_claims(self, claims):
        sub = claims.get("sub")
        if not sub:
            return self.UserModel.objects.none()
        users = self.UserModel.objects.filter(username__iexact=sub)
        if users:
            return users
        email = claims.get("email")
        return self.UserModel.objects.filter(username__iexact=email) if email else users

    def update_user(self, user, claims):
        fields = []
        sub = claims.get("sub")
        if sub and user.username != sub:
            user.username = sub
            fields.append("username")
        email = claims.get("email")
        if email and user.email != email:
            user.email = email
            fields.append("email")
        if fields:
            user.save(update_fields=fields)
        return user
