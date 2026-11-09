# agent-dev-flow

[English](README.md) | **简体中文**

一套给 Claude Code 用的开发流程 skill：需求不管大小，一个命令走完对应的流程；每个会话都能放心关掉；新仓库一步装好给 agent 用的开发规范。

## 安装

### 让 agent 帮你装（一句话）

把这句发给 Claude Code：

```text
安装 agent-dev-flow：按 https://github.com/kai-liu-gradient/agent-dev-flow/blob/main/README.md 里 "For agents" 一节的步骤来
```

### 或者自己装

```bash
gh repo clone kai-liu-gradient/agent-dev-flow ~/workspace/agent-dev-flow
cd ~/workspace/agent-dev-flow && ./install.sh --with-optional
```

| 参数 | 作用 |
|---|---|
| （不加） | 链接本仓库的 skill，安装必需依赖 |
| `--with-optional` | 再装上可选依赖（浏览器检查） |
| `--copy` | 复制 skill，而不是软链 |
| `--check` | 只检查装了什么、缺什么，不做任何改动 |

- skill 默认**软链**到 `~/.claude/skills/`，之后在本仓库 `git pull` 就是更新。
- 已有的同名 skill 会先挪到 `~/.claude/skills/.backup-<时间>/`，不会删除。
- 依赖 skill 用 `npx skills add` 安装，已经装过的会跳过，可以反复运行。
- 访问 GitHub 慢或连不上时，先设代理再运行，例如：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`。

## 包含什么

| skill | 用法 | 做什么 |
|---|---|---|
| `work` | `/work <需求>`、`/work 小/中/大 <需求>`、`/work #<issue>`、`/work merge-batch #a #b ...`、`/work baseline`、`/work coordinate #<epic>` | 先判断大小，再走完整流程：worktree → 实现 → 全量测试 → `/code-review` → PR → 按 A/B 级合并 → 收工。大需求会建成 epic 和子 issue，交给一个主控会话推进 |
| `wrap` | `/wrap`，或说"收工" | 提交本会话自己的改动，在 PR 或 issue 里写进度，列出后台进程，然后告诉你能不能关、怎么恢复 |
| `agent-kit` | `/agent-kit`、`/agent-kit refresh`、`/agent-kit sessions` | 从仓库本身读出信息，生成 `AGENTS.md`、`LESSONS.md`、`docs/agents/workflow.md`、`docs/agents/loops.md` 和 PR 模板；或者清点这台机器上开着的 Claude 会话 |

`skills/agent-kit/scripts/` 下的只读脚本：

- `sessions.sh [过滤]`：按目录列出开着的会话，给出建议：可以关 / 先收工 / 先找出改动是谁的。
- `session-index.sh [过滤]`：每个会话的标题、关联的 PR 及状态、你最后说的话、恢复命令；同时存档到 `~/.claude/session-index/`。
- `wrap-panes.sh`：仅限 herdr，给选中的会话发 `/wrap` 并汇总它们的结论。

## 多个会话共用一台机器

几个会话同时干活时，把电脑压垮的主要是全量测试。不是每个 PR 都需要跑全量：

| 档位 | PR 改了什么 | 开 PR 前跑的测试 |
|---|---|---|
| T0 | 只有文档 | 不跑 |
| T1 | 只有前端 | 相关测试、lint、build |
| T2 | 后端普通代码 | 和改动相关的测试（`jest --changedSince=origin/<默认分支>`）、lint |
| T3 | 公共底座、schema、测试配置，或改动超过 1000 行 | T2 + 全量跑一次 |

每次合并仍然会跑全量，只是一批跑一次：`/work merge-batch #a #b #c` 把准备好的 PR 叠到默认分支上（`scripts/merge-batch.sh build`），跑一次全量；有新增失败时，找出它依赖的是哪个 PR（`merge-batch.sh blame`），把那个 PR 拿掉，其余照合。合完后 `/work baseline` 记录默认分支上的失败，供后续对比。

任何全量测试都遵守：

- 写代码时只跑相关测试；全量测试只在开 PR 前跑一次。
- 全量测试通过 `skills/work/scripts/test-lock.sh <命令>` 运行：整台机器同一时间只跑一个（设 `TEST_LOCK_SLOTS=2` 可以放宽），其余排队。`test-lock.sh --status` 查看当前是谁在跑。
- jest 和 vitest 都加 `--maxWorkers=2`；每个 worktree 同一时间只跑一次；review 不跑测试。
- 默认分支上本来就失败的测试，每个 commit 用 `skills/work/scripts/test-baseline.sh put` 记录一次；每个 PR 用 `test-baseline.sh new` 和它对比，不再各自重跑默认分支。

## 在一个仓库里开始

1. 在仓库里打开 Claude Code，运行一次 `/agent-kit`。它读仓库，请你确认合并分级和部署策略，然后开一个 PR 把规范写进去。合并这个 PR。
2. 之后每个需求：`/work <一句话>`。
3. 关会话之前：`/wrap`。

任何 GitHub 上的仓库都能用：测试命令、热点文件、分级、PR 语言都从那个仓库自己的 `AGENTS.md` 读，不写死在这个包里。

## 流程

| 大小 | 自动做什么 | 你要做的 |
|---|---|---|
| 小 | worktree → 实现 → 测试 → review → PR → A 级自动合并 → 收工 | B 级 PR 时说"合" |
| 中 | 一次性问完问题 → 建 issue → 走"小"的流程 | 一次性回答问题；合并 B 级 PR |
| 大 | 问完问题 → 给出拆分方案 → 建 epic 和子 issue → 主控会话派 Worker、审它们的 PR，并在 epic 上维护状态表 | 回答问题、确认拆分方案；之后看主控的汇总表、合并 B 级 PR |

**A 级**（agent 可以自己合）：纯 UI 展示、文档、测试，行数在上限内，测试和 review 都通过。**B 级**（由人合）：其他所有改动。每个仓库在自己的 `AGENTS.md` 里定义分级。部署始终由人来做。

三个习惯：开会话就起名（`claude -n "<名字>"`）；关之前 `/wrap`；同时最多 4 个工作会话。

## 和 herdr 一起用（可选）

在 [herdr](https://herdr.dev/tui/)里运行时，下面这些会自动发生；没有 herdr 时，每一步都有能用的退回做法。

| 场景 | 在 herdr 里 | 没有 herdr |
|---|---|---|
| `/work` 开始 | tab 改名为「大小 + 标题」 | 提示下次用 `claude -n "<名字>"` 开会话 |
| 大需求 | 自动开 tab「主控 #epic」，起好名字的会话，并发出 `/work coordinate #epic` | 打印命令，由你运行 |
| 等你处理 | herdr 通知 | macOS 系统通知，再不行就响铃 |
| `/wrap` | tab 标成「✓ 可以关」或「⚠ 未完」；`/wrap 关` 会在 5 秒后关掉这个 pane | 告诉你能不能关终端 |
| `session-index.sh` | 显示每个会话在哪个 workspace / tab | 显示终端号 |
| 一次关很多会话 | `wrap-panes.sh --tab <id>` 给这个 tab 里空闲的会话都发 `/wrap`，再汇总结论 | 提示你逐个发 `/wrap` |

新 tab 如果停在 Claude Code 的"是否信任这个文件夹"确认上，脚本不会替你选：它会通知你，并打印你确认后要发送的指令。

所有 herdr 调用都经过 `skills/work/scripts/hd.sh`，也可以单独使用：

```bash
hd.sh available | name <标签> | notify <标题> [内容] | spawn <tab> <会话名> <首条指令> [目录] | where <会话ID> | close-self [秒]
```

## 依赖

完整清单见 [deps.json](deps.json)，`install.sh` 就是读它来安装的。

| 依赖 | 类型 | 来源 | 用途 |
|---|---|---|---|
| `grilling` | 必需 skill | mattpocock/skills | 中、大需求开工前一次性把决策问清楚 |
| `code-review` | 必需 skill | mattpocock/skills | PR 交给人之前，做一次新上下文的审查 |
| `agent-browser` | 可选 skill | vercel-labs/agent-browser | UI 改动的截图和无头检查 |
| `chrome-use` | 可选 skill | leeguooooo/chrome-use | 在你已登录的 Chrome 里检查页面 |
| `git`、`gh`、`jq`、`npx` | 必需工具 | | worktree、issue 和 PR、脚本、安装 skill |
| `herdr`、`lsof` | 可选工具 | | herdr 集成；查找会话所在目录 |

前提：仓库托管在 GitHub，并且 `gh` 已登录。

新增依赖时：在 `deps.json` 里加一项，并在用到它的每个 SKILL.md 开头的 `Needs:` 一行写上。

## 给 agent 的安装步骤

见英文版 [For agents](README.md#for-agents) 一节。保留英文是为了让任何 agent 都按同一份步骤执行。

## 许可

暂未添加许可证文件，按默认版权处理。需要的话请提 issue。
