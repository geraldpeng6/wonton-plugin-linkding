# Linkding 书签插件

开发流程见[插件开发指南](https://github.com/wontonapp/wonton-docs/blob/main/develop.md)。

这个仓库是 [Linkding](https://linkding.link) 插件：收藏网页书签，自动抓标题、描述和图标，全文搜索。登录交给云吞的
身份提供方（`sso: oidc`，上游的 mozilla-django-oidc），网页入口直接发起登录，打开就进书签页；抓书签信息
需要出网权限。

登录身份按 OIDC 的 `sub` 认（云吞的账号名，装好后不变），邮箱只当资料，每次登录同步成新值：改邮箱不会
锁在外面，也不会多出一个号。上游默认按邮箱认人，插件挂一个 `custom.py` 换掉它的匹配逻辑；管理员账号由
compose 里的一次性服务按 `sub` 预建（无密码，只能经 OIDC 进入），首次登录就是管理员。

## 图标来源与授权

`icon.png` 使用 Linkding 官方标志（上游仓库 `assets/logo.png`），未用图片模型生成；来源、版权、处理方式、上游 MIT 全文和商标说明见 [NOTICE](NOTICE)。
Linkding 名称和标志是 Linkding 项目及其权利人的商标；本插件是独立维护的云吞插件包，不代表上游官方出品、合作或背书。
