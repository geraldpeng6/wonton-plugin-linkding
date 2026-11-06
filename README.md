# Linkding 书签插件

开发流程见[插件开发指南](https://github.com/geraldpeng6/wonton-docs/blob/main/develop.md)。

这个仓库是 [Linkding](https://linkding.link) 插件：收藏网页书签，自动抓标题、描述和图标，全文搜索。登录交给云吞的
身份提供方（`sso: oidc`，上游的 mozilla-django-oidc），网页入口直接发起登录，打开就进书签页；抓书签信息
需要出网权限。

上游按邮箱认用户（`OIDC_USERNAME_CLAIM` 默认 `email`，不覆盖）：云吞里要先配好邮箱，否则装不上——compose 用
`${WONTON_OWNER_EMAIL:?}` 在安装时就挡下来。管理员账号由 compose 写进上游自带的 `LD_SUPERUSER_NAME`（bootstrap
启动时建好，无密码，只能经 OIDC 进入）；首次 OIDC 登录按邮箱对上这个号，打开就是管理员。

## 图标来源与授权

`icon.png` 使用 Linkding 官方标志（上游仓库 `assets/logo.png`），未用图片模型生成；来源、版权、处理方式、上游 MIT 全文和商标说明见 [NOTICE](NOTICE)。
Linkding 名称和标志是 Linkding 项目及其权利人的商标；本插件是独立维护的云吞插件包，不代表上游官方出品、合作或背书。
