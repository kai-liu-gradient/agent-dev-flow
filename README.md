# agent-dev-flow

一套给 Claude Code 用的开发流程 skill：需求按大小自动走流程，会话随时能安全关闭，新项目一条命令装好开发规范。

## 包含的 skill

| skill | 用法 | 做什么 |
|---|---|---|
| `work` | `/work <需求>`、`/work 小/中/大 <需求>`、`/work #<issue>`、`/work coordinate #<epic>` | 判断大小后走完整流程：worktree → 实现 → 全量测试 → `/code-review` → PR → 按 A/B 级合并 → 收工。大需求会建 epic 和子 issue，并在 herdr 里自动开主控 tab |
| `wrap` | `/wrap` 或说"收工" | 提交本会话的改动、在 PR/issue 写进度、列出后台进程，告诉你能不能关、怎么恢复 |
| `agent-kit` | `/agent-kit`、`/agent-kit refresh`、`/agent-kit sessions` | 给仓库生成 `AGENTS.md`、`LESSONS.md`、`docs/agents/workflow.md`、`loops.md`、PR 模板；或清点本机所有会话 |

`agent-kit/scripts/` 下还有两个只读脚本，可以直接运行：

- `sessions.sh [过滤]`：按目录列出开着的会话，给出"可以关 / 先收工 / 先认领"的建议
- `session-index.sh [过滤]`：列出每个会话的标题、关联 PR 及状态、你最后说的话、恢复命令，并存档到 `~/.claude/session-index/`

## 安装

```bash
git clone git@github.com:kai-liu-gradient/agent-dev-flow.git ~/workspace/agent-dev-flow
cd ~/workspace/agent-dev-flow
./install.sh                    # 本仓库的 skill + 必需依赖
./install.sh --with-optional    # 再加上可选依赖（浏览器检查）
./install.sh --check            # 只检查，不安装
```

- 本仓库的 skill 默认**软链**到 `~/.claude/skills/`，之后 `git pull` 就是更新。想复制一份就加 `--copy`。
- 同名的旧 skill 会先挪到 `~/.claude/skills/.backup-<时间>/`，不会删除。
- 依赖 skill 通过 `npx skills add` 安装，已经装过的会跳过，可以反复运行。
- 访问 GitHub 慢或连不上时，先设好代理再运行，例如：
  `export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`

## 和 herdr 一起用（可选）

装了 [herdr](https://github.com/ogulcancelik/herdr) 并在里面运行时，下面这些会自动发生；没有 herdr 时都有退回做法，流程照样能走完。

| 场景 | 在 herdr 里 | 没有 herdr |
|---|---|---|
| `/work` 开始 | tab 改名为「小/中/大 + 标题」 | 提示下次用 `claude -n "<名字>"` 开会话 |
| 大需求开主控 | 自动开 tab「主控 #epic」，起好名字的会话并发出 `/work coordinate #epic` | 打印命令，你在新终端里运行 |
| 等你处理（B 级 PR、拆分方案、汇总表） | herdr 桌面通知 | macOS 系统通知，再不行响铃 |
| `/wrap` 收工 | tab 名标成「✓ 可以关」或「⚠ 未完」；`/wrap 关` 会在 5 秒后自动关掉 pane | 告诉你能不能关，由你关终端 |
| 会话清点 `session-index.sh` | 额外显示每个会话在哪个 workspace / tab | 显示终端号（ttys） |
| 批量收工 `wrap-panes.sh --tab <id>` | 给这个 tab 里的空闲会话都发 `/wrap`，等它们做完，汇总结论 | 告诉你逐个发 `/wrap` |

新 tab 如果停在"是否信任这个文件夹"的确认上，脚本不会替你选，会通知你去确认，并打印要发送的指令。

所有 herdr 调用都经过 `skills/work/scripts/hd.sh`，可以单独使用：

```bash
hd.sh available | name <标签> | notify <标题> [内容] | spawn <tab> <会话名> <首条指令> [目录] | where <会话ID> | close-self [秒]
```

## 依赖

完整清单在 [deps.json](deps.json)，`install.sh` 就是读它来安装的。

| 依赖 | 类型 | 来源 | 用途 |
|---|---|---|---|
| `grilling` | 必需 skill | mattpocock/skills | 中、大需求开工前一次性把决策问清楚 |
| `code-review` | 必需 skill | mattpocock/skills | PR 交给人之前做新上下文审查 |
| `agent-browser` | 可选 skill | vercel-labs/agent-browser | UI 改动的截图、无头检查 |
| `chrome-use` | 可选 skill | leeguooooo/chrome-use | 用你已登录的 Chrome 检查页面 |
| `git`、`gh`、`jq`、`npx` | 必需工具 | | worktree、PR、脚本、安装依赖 |
| `herdr` | 可选工具 | | 大需求时自动开主控 tab；没有就打印命令让你手动开 |

新增依赖时：在 `deps.json` 里加一项，并在用到它的 SKILL.md 开头的 `Needs:` 一行写上。

## 在一个新项目里开始

1. 在项目里打开 Claude Code，运行一次 `/agent-kit`：它读仓库，跟你确认 A/B 合并分级和部署策略，然后开一个 PR 写入规范。合并这个 PR。
2. 之后每个需求：`/work <一句话需求>`。
3. 关会话前：`/wrap`。

## 流程概要

| 大小 | 你要做的 |
|---|---|
| 小 | 无；B 级 PR 时说"合" |
| 中 | 一次性回答开头的问题；B 级 PR 时合并 |
| 大 | 回答问题、确认拆分方案；之后只在主控 tab 里看汇总表、合 B 级 PR |

部署始终由人来做。

三个习惯：开会话就起名（`claude -n "<名字>"`）；关之前 `/wrap`；同时最多 4 个工作会话。
