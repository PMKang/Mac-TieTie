# Mac贴贴 排查记录

## 当前状态（2026-03-21）

### ✅ 已解决
- 后端部署：Vercel Singapore (sin1) 正常
- Python 依赖：pycryptodome、fastapi、supabase 均已安装
- Supabase 数据库：表已建好，可读写
- 微信 URL 验证：`GET /api/wechat` 返回 200，微信服务器（Mozilla/4.0）可连通
- Mac App Swift 骨架：编译通过
- 测试激活码已手动插入数据库（见下方）

### ❌ 待解决：微信 POST 事件不到达

**现象**：微信后台消息推送配置正确（URL/Token/AES Key 均对），GET 验证通过，但用户关注/取消关注/发消息时，Vercel 完全收不到任何 POST 请求。

**排查过程**：
1. 初始部署在 Vercel US East (iad1) → 微信服务器无法连通
2. 改为 Singapore (sin1) → GET 验证可以通过（Mozilla/4.0 出现在日志）
3. 发现之前 GET 200 是浏览器发的（Chrome UA），不是微信服务器
4. 切换明文模式（明文模式）→ 微信真实服务器 GET 验证通过（Mozilla/4.0，直接路由到 sin1）
5. 但 POST 事件依然不到达
6. 测试：手动 curl POST → 服务器正常处理（返回 success）
7. 测试：curl 发假 subscribe 事件 → 服务器收到并处理

**结论**：服务器代码正常，问题在微信服务器侧不发送 POST 事件。

**可能原因**：
- 个人订阅号（未认证）对消息推送有特殊限制
- 微信服务器有延迟/队列积压（尝试等待无效）
- 需要用家人手机（非开发者账号）测试关注事件

### 待尝试
- [ ] 用另一个微信账号关注公众号，测试是否收到 POST
- [ ] 查看微信官方文档对个人订阅号消息推送的限制说明
- [ ] 考虑切换到微信测试号（mp.weixin.qq.com/debug/cgi-bin/sandboxinfo）

---

## 测试激活码

| 字段 | 值 |
|------|-----|
| 激活码 | `AKANGDEV` |
| openid | `DEV_AKANG_TEST_OPENID_PLACEHOLDER`（占位，后续替换为真实 openid）|
| is_following | true |
| 备注 | 开发测试用，阿康本人 |

**用法**：打开 Mac贴贴 App → 输入激活码 `AKANGDEV` → 激活

---

## 关键配置（不要提交 Git）

| 配置项 | 值 |
|--------|-----|
| 微信 AppID | `wx04e5ae602f4b8893` |
| 微信 Token | `mactietie2026` |
| 微信 AES Key | `UKnsI15qIna9dSo0BMG18pOcnPyR5PJ2C383IKotw6e` |
| 加密模式 | 明文模式（已从安全模式切换，调试中） |
| 消息推送 URL | `https://backend-ten-beta-81.vercel.app/api/wechat` |
| Supabase URL | `https://oygmbvognomuolyzwujz.supabase.co` |
| Vercel 生产域名 | `https://backend-ten-beta-81.vercel.app` |

---

## 接口速查

```bash
# 健康检查
curl https://backend-ten-beta-81.vercel.app/api/ping

# 测试激活（Mac App 调用）
curl -X POST https://backend-ten-beta-81.vercel.app/api/activate \
  -H "Content-Type: application/json" \
  -d '{"code":"AKANGDEV","device_uuid":"test-device-001"}'

# 测试验证
curl -X POST https://backend-ten-beta-81.vercel.app/api/verify \
  -H "Content-Type: application/json" \
  -d '{"code":"AKANGDEV","device_uuid":"test-device-001"}'
```
