---
name: "wechat-desktop-message"
description: "Uses desktop WeChat to send messages (text, images, files) via local UI automation. Invoke when user asks to send a WeChat message from this computer."
---

# WeChat Desktop Message

本 Skill 用于在用户明确要求时，通过当前电脑上的桌面微信发送消息、图片或文件。它适用于"帮我给某人发微信""用微信发这段话""给某人发张图片""发个文件给某人"等场景。

## 触发条件

当用户提出以下任一请求时使用本 Skill：

- 要求通过"微信""桌面微信""WeChat"发送消息、图片或文件。
- 给指定联系人、群聊或文件传输助手发送文本、图片或文件。
- 要求把当前生成的内容转发到微信。
- 要求打开微信并准备发送某段内容。

不要在以下情况下使用：

- 用户只是询问微信功能、聊天建议或文案润色，但没有要求实际发送。
- 用户要求绕过登录、验证码、风控、人机验证或权限限制。
- 用户要求批量骚扰、垃圾营销、钓鱼、冒充他人、欺诈或发送敏感违法内容。

## 安全原则

- 用户已明确给出收件人或群名。
- 用户已明确给出要发送的消息正文、图片或文件路径。
- 不要读取、导出、总结或泄露微信聊天记录，除非用户明确要求且操作只涉及用户可见内容。
- 用户明确要求发送消息时，直接执行发送，不需要再次向用户确认。

## 推荐流程

1. 确认关键信息：
   
   - 收件人或群聊名称。
   - 消息正文、图片路径或文件路径。

2. 操作桌面微信（使用 PowerShell + .NET，不依赖任何第三方 Python 库）：
   
   - 直接调用本 Skill 目录下的通用脚本 `send_wechat.ps1`，根据内容类型传入对应参数。
    - 如果微信未登录、被锁定、需要扫码或需要安全验证，请停止自动化并提示用户手动处理。

3. 完成后反馈：
   
   - 告知用户消息已发送。
   - 如果失败，说明卡在哪一步，并给出最小可行的人工协助步骤。

## 桌面自动化实现方案

**重要：本 Skill 使用 PowerShell + .NET 实现**

本目录下已提供通用脚本 `send_wechat.ps1`，直接调用即可，不需要每次临时编写脚本。

### 调用方式



#### 发送文本消息

```powershell
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "<Skill目录>\send_wechat.ps1" -Recipient "tudou" -Message "蚊子太多"
```

#### 发送图片

```powershell
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "<Skill目录>\send_wechat.ps1" -Recipient "tudou" -ImagePath "C:\Users\kugou\Pictures\640.jpg"
```

图片通过剪贴板粘贴方式发送：将图片加载为 `System.Drawing.Image` 对象后写入剪贴板，再用 Ctrl+V 粘贴到聊天窗口。微信会弹出图片预览，按 Enter 确认发送。

#### 发送文件

```powershell
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "<Skill目录>\send_wechat.ps1" -Recipient "tudou" -FilePath "C:\Users\kugou\Pictures\docker.txt"
```

文件通过剪贴板粘贴方式发送：将文件路径写入剪贴板的 `FileDropList`，再用 Ctrl+V 粘贴到聊天窗口。微信会弹出文件发送对话框，按 Enter 确认发送。

### 脚本内部实现说明（供参考）

如果通用脚本无法满足特殊需求，可参考以下实现思路自行扩展：

- 使用 `Get-Process -Name "Weixin"` 通过进程名精确定位微信（新版微信主进程名为 `Weixin`，旧版为 `WeChat`，优先匹配 `Weixin` 并回退到 `WeChat`），不要通过窗口标题匹配（窗口标题会随聊天对象变化，容易找错窗口）。
- 过滤进程时使用 `ForEach-Object { if ($_.MainWindowHandle -ne 0) { $_ } }` 而非 `Where-Object`，确保在 TRAE 的 PowerShell 安全包装下也能正常工作。
- **文本发送**：使用 `Type-Human` 函数逐字模拟键盘输入，每个字符间隔 40-180ms（标点符号 100-250ms），单词间停顿 200-600ms，模拟真人打字节奏。最后按 `~`（Enter）发送。所有操作间隔加入 ±40% 的随机抖动。
- **图片发送**：使用 `[System.Drawing.Image]::FromFile($path)` 加载图片，再用 `[System.Windows.Forms.Clipboard]::SetImage($img)` 写入剪贴板，粘贴后微信弹出预览，按 Enter 发送。
- **文件发送**：使用 `[System.Windows.Forms.Clipboard]::SetFileDropList($list)` 将文件路径写入剪贴板的文件拖放列表，粘贴后微信弹出文件发送对话框，按 Enter 发送。
- 所有 `Start-Sleep` 通过 `Sleep-Jitter` 函数加上 ±40% 随机抖动，避免固定间隔被风控。
- 发送文本前调用 `Move-MouseSubtle` 将鼠标微移 ±8px，模拟真人发送前的小动作。
- 搜索联系人：用 SendKeys 发送 `^{f}`（Ctrl+F）打开搜索，粘贴收件人名称，等待搜索结果后按 Enter 进入会话。

## 失败处理

遇到以下情况时停止自动化并提示用户：

- 找不到微信窗口。
- 微信未登录、被锁定或要求扫码。
- 搜索结果不唯一，无法确认目标联系人。
- 当前焦点不在微信输入框。
- 消息包含用户未确认的敏感内容。
- 发送动作可能误发给错误会话。
- 图片或文件路径不存在。

## 用户沟通模板

发送成功：

```text
微信消息已发送给 <收件人>。
```

需要用户手动处理：

```text
我无法继续自动发送，因为微信需要你手动完成登录/验证。请先打开并登录桌面微信，然后告诉我继续。
```
