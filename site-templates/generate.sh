#!/usr/bin/env bash
# ============================================================
# 伪装静态站点生成器
# 用法: ./generate.sh <输出目录> [模板编号]
# 模板编号 1-4，留空则随机选择
# ============================================================

set -euo pipefail

# ----------------------------------------------------------
# 参数解析
# ----------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "用法: $0 <输出目录> [模板编号1-4]"
    exit 1
fi

OUTPUT_DIR="$1"
TEMPLATE_NUM="${2:-}"

# 如果未指定模板编号，随机选择 1-4
if [ -z "$TEMPLATE_NUM" ]; then
    TEMPLATE_NUM=$(( RANDOM % 4 + 1 ))
fi

# 校验模板编号
if ! [[ "$TEMPLATE_NUM" =~ ^[1-4]$ ]]; then
    echo "错误: 模板编号必须是 1-4"
    exit 1
fi

echo "==> 使用模板 ${TEMPLATE_NUM} 生成站点到 ${OUTPUT_DIR}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# ----------------------------------------------------------
# 图片 URL 生成辅助函数
# ----------------------------------------------------------
IMAGE_BASE="https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image"

# 生成图片 URL，prompt 会做 URL 编码
make_image_url() {
    local prompt="$1"
    local encoded
    # 用 python3 做 URL 编码，兼容性好
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$prompt'''))")
    echo "${IMAGE_BASE}?prompt=${encoded}&image_size=landscape_16_9"
}

# ----------------------------------------------------------
# 当前日期（用于 atom.xml 等地方）
# ----------------------------------------------------------
NOW_RFC3339=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NOW_DATE=$(date +"%Y-%m-%d")

# ----------------------------------------------------------
# 模板数据定义
# ----------------------------------------------------------

# --- 模板1: Go/Kubernetes/云原生 ---
if [ "$TEMPLATE_NUM" -eq 1 ]; then
    BLOG_NAME="云原生笔记"
    BLOG_SUBTITLE="专注云原生技术，记录容器化与微服务实践"
    AUTHOR_NAME="陈明远"
    AUTHOR_ROLE="云原生架构师"
    AUTHOR_BIO="多年 Kubernetes 与微服务架构经验，热爱开源，CNCF 贡献者。目前专注于服务网格与可观测性领域。"
    PRIMARY_COLOR="#2563eb"
    PRIMARY_LIGHT="#dbeafe"
    ACCENT_COLOR="#0ea5e9"
    BG_COLOR="#f8fafc"
    TEXT_COLOR="#1e293b"
    TEXT_SECONDARY="#64748b"
    NAV_STYLE="top"

    # 文章数据：标题|摘要|图片prompt|日期|slug
    ARTICLES=(
        "Kubernetes 1.29 新特性解读：边车容器原生支持|Kubernetes 1.29 引入了原生的边车容器支持，不再需要 hack 式的 init 容器方案。本文深入分析该特性的实现原理与迁移指南。|kubernetes containers orchestration technology blue|2024-12-15|k8s-129-sidecar"
        "使用 Cilium 替换 Calico：从网络策略到 eBPF 可观测性|分享在生产环境中将 CNI 从 Calico 迁移到 Cilium 的完整过程，包括网络策略转换、eBPF Hubble 可观测性配置。|network infrastructure server room cables|2024-11-28|cilium-migration"
        "Go 并发模式：Pipeline 与 Fan-Out/Fan-In 实战|通过实际案例讲解 Go 语言中 Pipeline 和 Fan-Out/Fan-In 并发模式的设计与实现，以及常见陷阱。|golang code programming screen dark|2024-11-10|go-concurrency-patterns"
        "ArgoCD GitOps 实践：多集群多环境交付方案|基于 ArgoCD 的 GitOps 交付方案，实现开发、测试、生产多集群的自动化部署与回滚策略。|gitops continuous deployment pipeline|2024-10-22|argocd-gitops"
        "eBPF 入门：从 Hello World 到内核追踪|从零开始学习 eBPF，编写第一个 BPF 程序，理解 map、helper 函数与内核追踪的基本概念。|linux kernel system programming|2024-10-05|ebpf-getting-started"
        "Prometheus + Thanos 构建大规模监控方案|使用 Thanos 实现 Prometheus 的高可用与长期存储，覆盖跨集群联邦查询与降采样配置。|monitoring dashboard graphs charts|2024-09-18|prometheus-thanos"
        "用 Go 实现一个简易容器运行时|从 Linux namespace 和 cgroup 出发，用 Go 实现一个能运行隔离进程的简易容器运行时。|docker container technology linux|2024-09-01|go-container-runtime"
    )

    FRIENDS=(
        "K8s 技术圈|https://k8s.example.com"
        "Go 语言中文网|https://golang.example.com"
        "云原生社区|https://cncf.example.com"
        "分布式系统笔记|https://dist.example.com"
    )

# --- 模板2: Python/数据分析/机器学习 ---
elif [ "$TEMPLATE_NUM" -eq 2 ]; then
    BLOG_NAME="数据拾遗"
    BLOG_SUBTITLE="用数据理解世界，用算法改变生活"
    AUTHOR_NAME="林晓薇"
    AUTHOR_ROLE="数据科学家"
    AUTHOR_BIO="统计学硕士，专注机器学习与数据可视化。喜欢从数据中挖掘有趣的故事，业余时间贡献开源数据分析工具。"
    PRIMARY_COLOR="#7c3aed"
    PRIMARY_LIGHT="#ede9fe"
    ACCENT_COLOR="#a855f7"
    BG_COLOR="#fafaf9"
    TEXT_COLOR="#1c1917"
    TEXT_SECONDARY="#78716c"
    NAV_STYLE="left"

    ARTICLES=(
        "用 Pandas 处理 10GB 级数据集的技巧与陷阱|分享使用 Pandas 处理大规模数据集时的内存优化策略，包括分块读取、类型优化与 Dask 替代方案。|python data analysis pandas code|2024-12-10|pandas-large-dataset"
        "从零实现一个 Transformer：理解注意力机制的本质|不依赖任何深度学习框架，用 NumPy 从零实现 Transformer 的核心组件，深入理解自注意力机制。|neural network transformer architecture diagram|2024-11-25|transformer-from-scratch"
        "时间序列异常检测实战：从统计方法到深度学习|对比 Z-Score、Isolation Forest、LSTM-AutoEncoder 三种方法在服务器监控数据上的异常检测效果。|time series anomaly detection graph|2024-11-08|timeseries-anomaly"
        "Matplotlib vs Plotly vs Altair：Python 可视化库横评|从 API 设计、交互能力、渲染性能、导出格式等维度全面对比三大 Python 可视化库。|data visualization charts colorful|2024-10-20|python-viz-comparison"
        "Scikit-learn Pipeline 最佳实践|如何用 Scikit-learn 的 Pipeline 和 ColumnTransformer 构建可复现、防泄漏的机器学习工作流。|machine learning pipeline workflow|2024-10-03|sklearn-pipeline"
        "用 SHAP 解释你的机器学习模型|介绍 SHAP 值的原理与使用方法，让你的黑盒模型决策过程变得可解释、可信赖。|machine learning explainability shap|2024-09-15|shap-explainability"
        "Jupyter Notebook 效率提升指南|分享 Jupyter 的高效使用技巧：快捷键、魔法命令、插件推荐与版本控制方案。|jupyter notebook python coding|2024-08-28|jupyter-tips"
        "特征工程的艺术：从业务理解到自动化|系统梳理特征工程方法论，涵盖数值特征、类别特征、文本特征的处理策略与 AutoML 特征生成。|feature engineering data processing|2024-08-10|feature-engineering"
    )

    FRIENDS=(
        "统计之都|https://cos.example.com"
        "机器学习笔记|https://ml.example.com"
        "Python 数据之道|https://pydata.example.com"
        "可视化图鉴|https://viz.example.com"
    )

# --- 模板3: 前端/React/TypeScript ---
elif [ "$TEMPLATE_NUM" -eq 3 ]; then
    BLOG_NAME="像素之外"
    BLOG_SUBTITLE="前端工程师的思考与实践"
    AUTHOR_NAME="苏逸凡"
    AUTHOR_ROLE="高级前端工程师"
    AUTHOR_BIO="React 核心贡献者团队成员，TypeScript 布道者。热衷于探索前端性能优化与开发者体验提升。"
    PRIMARY_COLOR="#059669"
    PRIMARY_LIGHT="#d1fae5"
    ACCENT_COLOR="#10b981"
    BG_COLOR="#f9fafb"
    TEXT_COLOR="#111827"
    TEXT_SECONDARY="#6b7280"
    NAV_STYLE="top"

    ARTICLES=(
        "React Server Components 深度解析|从架构层面理解 RSC 的工作原理，分析它与传统 SSR 的区别，以及在 Next.js App Router 中的实践。|react javascript code programming|2024-12-12|rsc-deep-dive"
        "TypeScript 5.4 类型收窄新特性全览|详解 TypeScript 5.4 中新增的类型收窄能力，包括闭包中的类型收窄与 NoInfer 工具类型。|typescript code editor screen|2024-11-30|ts54-narrowing"
        "从 Webpack 到 Vite：大型项目迁移实录|记录将一个 2000+ 模块的企业级项目从 Webpack 5 迁移到 Vite 的全过程与踩坑记录。|vite build tool modern development|2024-11-15|webpack-to-vite"
        "CSS Container Queries 实战：真正的组件级响应式|Container Queries 终于获得主流浏览器支持，本文通过实际案例展示如何实现真正的组件级响应式设计。|css responsive design layout|2024-10-28|container-queries"
        "微前端架构选型：Module Federation vs qiankun|对比 Webpack Module Federation 与 qiankun 两种微前端方案的技术原理、适用场景与性能差异。|micro frontend architecture diagram|2024-10-10|micro-frontend-compare"
        "用 Playwright 构建可靠的 E2E 测试体系|分享 Playwright 在大型前端项目中的最佳实践：页面对象模型、并行执行、视觉回归测试。|testing automation browser quality|2024-09-22|playwright-e2e"
        "Tailwind CSS v4 新特性抢先看|预览 Tailwind CSS v4 的重大变更：新的引擎、CSS-first 配置、零配置内容检测。|tailwind css design modern web|2024-09-05|tailwind-v4"
    )

    FRIENDS=(
        "前端观察|https://frontend.example.com"
        "CSS 魔法|https://css.example.com"
        "TypeScript 中文网|https://ts.example.com"
        "React 技术揭秘|https://react.example.com"
    )

# --- 模板4: Rust/系统编程/嵌入式 ---
elif [ "$TEMPLATE_NUM" -eq 4 ]; then
    BLOG_NAME="底层探索"
    BLOG_SUBTITLE="在金属与逻辑之间，寻找优雅"
    AUTHOR_NAME="赵瀚文"
    AUTHOR_ROLE="系统程序员"
    AUTHOR_BIO="Rust 布道者，嵌入式系统开发者。长期关注操作系统内核、编译器与硬件交互。坚信安全与性能可以兼得。"
    PRIMARY_COLOR="#dc2626"
    PRIMARY_LIGHT="#fee2e2"
    ACCENT_COLOR="#ef4444"
    BG_COLOR="#fafafa"
    TEXT_COLOR="#18181b"
    TEXT_SECONDARY="#71717a"
    NAV_STYLE="left"

    ARTICLES=(
        "Rust 异步运行时对比：Tokio vs async-std vs smol|从调度器设计、IO 驱动、生态系统三个维度对比 Rust 主流异步运行时的选型策略。|rust programming code ferris crab|2024-12-08|async-runtime-compare"
        "用 Rust 写一个操作系统内核（一）：从 Bootloader 到屏幕输出|从零开始用 Rust 编写一个最小的操作系统内核，实现 Bootloader 加载与 VGA 文本模式输出。|operating system kernel boot screen|2024-11-22|rust-os-kernel-1"
        "嵌入式 Rust 入门：STM32 上的第一个项目|使用 embassy 框架在 STM32F4 上开发嵌入式应用，从环境搭建到 LED 闪烁到串口通信。|embedded hardware microchip circuit|2024-11-05|embedded-rust-stm32"
        "Rust 所有权与借用检查器：从困惑到精通|系统梳理 Rust 所有权系统的设计哲学，通过大量代码示例深入理解借用检查器的工作机制。|rust ownership borrowing memory safety|2024-10-18|rust-ownership"
        "用 Rust 重写核心服务：性能提升 10 倍的实战记录|将公司核心微服务从 Go 迁移到 Rust 的完整记录，涵盖 FFI、内存管理、性能基准测试与上线过程。|server performance benchmark graph|2024-10-01|rust-rewrite-core"
        "深入理解 Rust 的 Pin 与 Unpin|为什么 async/await 需要 Pin？自引用结构体到底有什么问题？本文从底层原理讲透 Pin 机制。|rust pin unpin async diagram|2024-09-14|rust-pin-unpin"
        "Rust 与 WASM：在浏览器中运行系统级代码|探索 Rust 编译到 WebAssembly 的实践路径，包括 wasm-bindgen、wasm-pack 与性能优化技巧。|webassembly rust browser technology|2024-08-27|rust-wasm"
        "嵌入式 Linux 设备树详解|深入理解 Linux 设备树（Device Tree）的语法、编译流程与在嵌入式平台上的调试方法。|linux embedded device tree hardware|2024-08-10|device-tree-guide"
    )

    FRIENDS=(
        "Rust 语言中文社区|https://rustcc.example.com"
        "内核月报|https://kernel.example.com"
        "嵌入式前沿|https://embed.example.com"
        "系统编程志|https://sysprog.example.com"
    )
fi

# ----------------------------------------------------------
# 生成 index.html
# ----------------------------------------------------------
generate_index_html() {
    # 构建文章列表 HTML
    local articles_html=""
    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title summary img_prompt date slug <<< "$article"
        local img_url
        img_url=$(make_image_url "$img_prompt")
        local year="${date%%-*}"
        local month_day="${date#*-}"
        local display_date="${year} 年 ${month_day//-/ 月 } 日"

        articles_html+=$(cat <<ARTICLE
      <article class="post-card">
        <a href="/posts/${slug}.html" class="post-card-link">
          <div class="post-card-image">
            <img src="${img_url}" alt="${title}" loading="lazy">
          </div>
          <div class="post-card-content">
            <time class="post-card-date" datetime="${date}">${display_date}</time>
            <h2 class="post-card-title">${title}</h2>
            <p class="post-card-summary">${summary}</p>
          </div>
        </a>
      </article>
ARTICLE
        )
    done

    # 构建友链 HTML
    local friends_html=""
    for friend in "${FRIENDS[@]}"; do
        IFS='|' read -r name url <<< "$friend"
        friends_html+=$(cat <<FRIEND
          <li><a href="${url}" target="_blank" rel="noopener">${name}</a></li>
FRIEND
        )
    done

    # 根据导航风格选择布局
    local nav_html sidebar_html=""
    if [ "$NAV_STYLE" = "left" ]; then
        nav_html=$(cat <<NAV
    <aside class="sidebar">
      <div class="sidebar-inner">
        <div class="author-card">
          <div class="author-avatar">${AUTHOR_NAME:0:1}</div>
          <h1 class="author-name">${AUTHOR_NAME}</h1>
          <p class="author-role">${AUTHOR_ROLE}</p>
          <p class="author-bio">${AUTHOR_BIO}</p>
        </div>
        <nav class="nav-menu">
          <a href="/" class="nav-link active">首页</a>
          <a href="/about.html" class="nav-link">关于</a>
          <a href="/friends.html" class="nav-link">友链</a>
        </nav>
        <div class="friends-section">
          <h3>友情链接</h3>
          <ul class="friends-list">
            ${friends_html}
          </ul>
        </div>
      </div>
    </aside>
NAV
        )
        sidebar_html="has-sidebar"
    else
        nav_html=$(cat <<NAV
    <header class="top-header">
      <div class="top-header-inner">
        <a href="/" class="logo">${BLOG_NAME}</a>
        <nav class="top-nav">
          <a href="/" class="top-nav-link active">首页</a>
          <a href="/about.html" class="top-nav-link">关于</a>
          <a href="/friends.html" class="top-nav-link">友链</a>
        </nav>
      </div>
    </header>
NAV
        )
    fi

    cat > "$OUTPUT_DIR/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${BLOG_NAME} - ${BLOG_SUBTITLE}</title>
  <meta name="description" content="${BLOG_SUBTITLE}">
  <meta name="author" content="${AUTHOR_NAME}">
  <link rel="alternate" type="application/atom+xml" title="${BLOG_NAME}" href="/atom.xml">
  <style>
    /* 基础重置 */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { font-size: 16px; scroll-behavior: smooth; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: ${TEXT_COLOR};
      background: ${BG_COLOR};
      line-height: 1.7;
      -webkit-font-smoothing: antialiased;
    }
    a { color: ${PRIMARY_COLOR}; text-decoration: none; transition: color 0.2s; }
    a:hover { color: ${ACCENT_COLOR}; }
    img { max-width: 100%; height: auto; display: block; }

    /* 顶部导航布局 */
    .top-header {
      background: #fff;
      border-bottom: 1px solid #e5e7eb;
      position: sticky;
      top: 0;
      z-index: 100;
      backdrop-filter: blur(12px);
      background: rgba(255,255,255,0.85);
    }
    .top-header-inner {
      max-width: 1120px;
      margin: 0 auto;
      padding: 0 1.5rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 60px;
    }
    .logo {
      font-size: 1.25rem;
      font-weight: 700;
      color: ${PRIMARY_COLOR};
      letter-spacing: -0.02em;
    }
    .top-nav { display: flex; gap: 1.5rem; }
    .top-nav-link {
      color: ${TEXT_SECONDARY};
      font-size: 0.9rem;
      font-weight: 500;
      padding: 0.25rem 0;
      border-bottom: 2px solid transparent;
      transition: all 0.2s;
    }
    .top-nav-link:hover, .top-nav-link.active {
      color: ${PRIMARY_COLOR};
      border-bottom-color: ${PRIMARY_COLOR};
    }

    /* 侧边栏布局 */
    .sidebar {
      position: fixed;
      top: 0; left: 0; bottom: 0;
      width: 280px;
      background: #fff;
      border-right: 1px solid #e5e7eb;
      overflow-y: auto;
      z-index: 100;
    }
    .sidebar-inner { padding: 2rem 1.5rem; }
    .author-card { margin-bottom: 2rem; text-align: center; }
    .author-avatar {
      width: 80px; height: 80px;
      border-radius: 50%;
      background: ${PRIMARY_COLOR};
      color: #fff;
      font-size: 2rem;
      font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      margin: 0 auto 1rem;
    }
    .author-name { font-size: 1.1rem; font-weight: 700; margin-bottom: 0.25rem; }
    .author-role { font-size: 0.85rem; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .author-bio { font-size: 0.82rem; color: ${TEXT_SECONDARY}; line-height: 1.6; }
    .nav-menu { display: flex; flex-direction: column; gap: 0.25rem; margin-bottom: 2rem; }
    .nav-link {
      display: block;
      padding: 0.5rem 0.75rem;
      border-radius: 6px;
      color: ${TEXT_SECONDARY};
      font-size: 0.9rem;
      font-weight: 500;
      transition: all 0.2s;
    }
    .nav-link:hover, .nav-link.active {
      background: ${PRIMARY_LIGHT};
      color: ${PRIMARY_COLOR};
    }
    .friends-section h3 {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: ${TEXT_SECONDARY};
      margin-bottom: 0.75rem;
    }
    .friends-list { list-style: none; }
    .friends-list li { margin-bottom: 0.4rem; }
    .friends-list a { font-size: 0.85rem; color: ${TEXT_SECONDARY}; }
    .friends-list a:hover { color: ${PRIMARY_COLOR}; }

    /* 主内容区 */
    .main-content {
      max-width: 1120px;
      margin: 0 auto;
      padding: 2rem 1.5rem 4rem;
    }
    body.has-sidebar .main-content {
      margin-left: 280px;
      max-width: none;
      padding: 2rem 2.5rem 4rem;
    }

    /* 博客标题区（顶部导航时显示） */
    .blog-hero {
      text-align: center;
      padding: 3rem 0 2rem;
    }
    .blog-hero h1 {
      font-size: 2rem;
      font-weight: 800;
      letter-spacing: -0.03em;
      color: ${TEXT_COLOR};
      margin-bottom: 0.5rem;
    }
    .blog-hero p {
      font-size: 1.05rem;
      color: ${TEXT_SECONDARY};
    }
    body.has-sidebar .blog-hero { display: none; }

    /* 文章卡片网格 */
    .posts-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 1.5rem;
    }
    .post-card {
      background: #fff;
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid #e5e7eb;
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .post-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 30px rgba(0,0,0,0.08);
    }
    .post-card-link { display: block; color: inherit; }
    .post-card-link:hover { color: inherit; }
    .post-card-image {
      aspect-ratio: 16/9;
      overflow: hidden;
      background: ${PRIMARY_LIGHT};
    }
    .post-card-image img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 0.3s;
    }
    .post-card:hover .post-card-image img { transform: scale(1.03); }
    .post-card-content { padding: 1.25rem; }
    .post-card-date {
      font-size: 0.8rem;
      color: ${TEXT_SECONDARY};
      display: block;
      margin-bottom: 0.5rem;
    }
    .post-card-title {
      font-size: 1.05rem;
      font-weight: 700;
      line-height: 1.4;
      margin-bottom: 0.5rem;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .post-card-summary {
      font-size: 0.88rem;
      color: ${TEXT_SECONDARY};
      line-height: 1.6;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    /* 页脚 */
    .site-footer {
      text-align: center;
      padding: 2rem 1.5rem;
      border-top: 1px solid #e5e7eb;
      color: ${TEXT_SECONDARY};
      font-size: 0.82rem;
    }
    body.has-sidebar .site-footer { margin-left: 280px; }

    /* 响应式 */
    @media (max-width: 768px) {
      .sidebar { display: none; }
      body.has-sidebar .main-content { margin-left: 0; }
      body.has-sidebar .site-footer { margin-left: 0; }
      .posts-grid { grid-template-columns: 1fr; }
      .blog-hero h1 { font-size: 1.5rem; }
    }
  </style>
</head>
<body class="${sidebar_html}">
  ${nav_html}
  <main class="main-content">
    <div class="blog-hero">
      <h1>${BLOG_NAME}</h1>
      <p>${BLOG_SUBTITLE}</p>
    </div>
    <div class="posts-grid">
      ${articles_html}
    </div>
  </main>
  <footer class="site-footer">
    <p>&copy; 2024 ${BLOG_NAME} by ${AUTHOR_NAME}. All rights reserved.</p>
  </footer>
</body>
</html>
HTMLEOF
}

# ----------------------------------------------------------
# 生成 404.html
# ----------------------------------------------------------
generate_404_html() {
    cat > "$OUTPUT_DIR/404.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 - 页面未找到 | ${BLOG_NAME}</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: ${TEXT_COLOR};
      background: ${BG_COLOR};
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      line-height: 1.6;
    }
    .error-container {
      text-align: center;
      padding: 2rem;
    }
    .error-code {
      font-size: 8rem;
      font-weight: 800;
      color: ${PRIMARY_COLOR};
      line-height: 1;
      letter-spacing: -0.04em;
      opacity: 0.15;
    }
    .error-title {
      font-size: 1.5rem;
      font-weight: 700;
      margin: -2rem 0 0.75rem;
    }
    .error-message {
      color: ${TEXT_SECONDARY};
      margin-bottom: 2rem;
      font-size: 1rem;
    }
    .error-home {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.75rem 1.5rem;
      background: ${PRIMARY_COLOR};
      color: #fff;
      border-radius: 8px;
      font-weight: 600;
      font-size: 0.95rem;
      text-decoration: none;
      transition: background 0.2s;
    }
    .error-home:hover {
      background: ${ACCENT_COLOR};
      color: #fff;
    }
  </style>
</head>
<body>
  <div class="error-container">
    <div class="error-code">404</div>
    <h1 class="error-title">页面未找到</h1>
    <p class="error-message">你访问的页面不存在，可能已被移动或删除。</p>
    <a href="/" class="error-home">&larr; 返回首页</a>
  </div>
</body>
</html>
HTMLEOF
}

# ----------------------------------------------------------
# 生成 about.html
# ----------------------------------------------------------
generate_about_html() {
    # 侧边栏布局的导航
    local nav_html sidebar_class=""
    if [ "$NAV_STYLE" = "left" ]; then
        local friends_html=""
        for friend in "${FRIENDS[@]}"; do
            IFS='|' read -r name url <<< "$friend"
            friends_html+=$(echo "<li><a href=\"${url}\" target=\"_blank\" rel=\"noopener\">${name}</a></li>")
        done
        nav_html=$(cat <<NAV
    <aside class="sidebar">
      <div class="sidebar-inner">
        <div class="author-card">
          <div class="author-avatar">${AUTHOR_NAME:0:1}</div>
          <h1 class="author-name">${AUTHOR_NAME}</h1>
          <p class="author-role">${AUTHOR_ROLE}</p>
          <p class="author-bio">${AUTHOR_BIO}</p>
        </div>
        <nav class="nav-menu">
          <a href="/" class="nav-link">首页</a>
          <a href="/about.html" class="nav-link active">关于</a>
          <a href="/friends.html" class="nav-link">友链</a>
        </nav>
        <div class="friends-section">
          <h3>友情链接</h3>
          <ul class="friends-list">
            ${friends_html}
          </ul>
        </div>
      </div>
    </aside>
NAV
        )
        sidebar_class="has-sidebar"
    else
        nav_html=$(cat <<NAV
    <header class="top-header">
      <div class="top-header-inner">
        <a href="/" class="logo">${BLOG_NAME}</a>
        <nav class="top-nav">
          <a href="/" class="top-nav-link">首页</a>
          <a href="/about.html" class="top-nav-link active">关于</a>
          <a href="/friends.html" class="top-nav-link">友链</a>
        </nav>
      </div>
    </header>
NAV
        )
    fi

    cat > "$OUTPUT_DIR/about.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>关于 | ${BLOG_NAME}</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { font-size: 16px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: ${TEXT_COLOR};
      background: ${BG_COLOR};
      line-height: 1.7;
      -webkit-font-smoothing: antialiased;
    }
    a { color: ${PRIMARY_COLOR}; text-decoration: none; transition: color 0.2s; }
    a:hover { color: ${ACCENT_COLOR}; }
    .top-header {
      background: rgba(255,255,255,0.85);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid #e5e7eb;
      position: sticky; top: 0; z-index: 100;
    }
    .top-header-inner {
      max-width: 1120px; margin: 0 auto; padding: 0 1.5rem;
      display: flex; align-items: center; justify-content: space-between; height: 60px;
    }
    .logo { font-size: 1.25rem; font-weight: 700; color: ${PRIMARY_COLOR}; }
    .top-nav { display: flex; gap: 1.5rem; }
    .top-nav-link {
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500;
      padding: 0.25rem 0; border-bottom: 2px solid transparent; transition: all 0.2s;
    }
    .top-nav-link:hover, .top-nav-link.active { color: ${PRIMARY_COLOR}; border-bottom-color: ${PRIMARY_COLOR}; }
    .sidebar {
      position: fixed; top: 0; left: 0; bottom: 0; width: 280px;
      background: #fff; border-right: 1px solid #e5e7eb; overflow-y: auto; z-index: 100;
    }
    .sidebar-inner { padding: 2rem 1.5rem; }
    .author-card { margin-bottom: 2rem; text-align: center; }
    .author-avatar {
      width: 80px; height: 80px; border-radius: 50%; background: ${PRIMARY_COLOR};
      color: #fff; font-size: 2rem; font-weight: 700;
      display: flex; align-items: center; justify-content: center; margin: 0 auto 1rem;
    }
    .author-name { font-size: 1.1rem; font-weight: 700; margin-bottom: 0.25rem; }
    .author-role { font-size: 0.85rem; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .author-bio { font-size: 0.82rem; color: ${TEXT_SECONDARY}; line-height: 1.6; }
    .nav-menu { display: flex; flex-direction: column; gap: 0.25rem; margin-bottom: 2rem; }
    .nav-link {
      display: block; padding: 0.5rem 0.75rem; border-radius: 6px;
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;
    }
    .nav-link:hover, .nav-link.active { background: ${PRIMARY_LIGHT}; color: ${PRIMARY_COLOR}; }
    .friends-section h3 { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .friends-list { list-style: none; }
    .friends-list li { margin-bottom: 0.4rem; }
    .friends-list a { font-size: 0.85rem; color: ${TEXT_SECONDARY}; }
    .friends-list a:hover { color: ${PRIMARY_COLOR}; }
    .main-content { max-width: 720px; margin: 0 auto; padding: 3rem 1.5rem 4rem; }
    body.has-sidebar .main-content { margin-left: 280px; max-width: none; padding: 3rem 2.5rem 4rem; }
    .about-header { margin-bottom: 2.5rem; }
    .about-header h1 { font-size: 2rem; font-weight: 800; letter-spacing: -0.03em; margin-bottom: 0.5rem; }
    .about-header p { color: ${TEXT_SECONDARY}; font-size: 1.05rem; }
    .about-section { margin-bottom: 2rem; }
    .about-section h2 {
      font-size: 1.2rem; font-weight: 700; margin-bottom: 0.75rem;
      padding-bottom: 0.5rem; border-bottom: 2px solid ${PRIMARY_LIGHT};
    }
    .about-section p { color: ${TEXT_COLOR}; line-height: 1.8; margin-bottom: 0.75rem; }
    .about-section ul { padding-left: 1.25rem; color: ${TEXT_COLOR}; }
    .about-section li { margin-bottom: 0.4rem; line-height: 1.7; }
    .site-footer {
      text-align: center; padding: 2rem 1.5rem; border-top: 1px solid #e5e7eb;
      color: ${TEXT_SECONDARY}; font-size: 0.82rem;
    }
    body.has-sidebar .site-footer { margin-left: 280px; }
    @media (max-width: 768px) {
      .sidebar { display: none; }
      body.has-sidebar .main-content { margin-left: 0; }
      body.has-sidebar .site-footer { margin-left: 0; }
    }
  </style>
</head>
<body class="${sidebar_class}">
  ${nav_html}
  <main class="main-content">
    <div class="about-header">
      <h1>关于我</h1>
      <p>${AUTHOR_ROLE}，${BLOG_NAME}的维护者</p>
    </div>
    <div class="about-section">
      <h2>个人简介</h2>
      <p>${AUTHOR_BIO}</p>
    </div>
    <div class="about-section">
      <h2>关于本站</h2>
      <p>这是我的个人技术博客，记录学习和工作中的思考与实践。文章主要围绕我日常使用的技术栈展开，希望能对读者有所帮助。</p>
      <p>本站使用静态站点生成器构建，源码托管在 GitHub 上，通过 CI/CD 自动部署。</p>
    </div>
    <div class="about-section">
      <h2>联系方式</h2>
      <ul>
        <li>GitHub: <a href="#">github.com/example</a></li>
        <li>邮箱: <a href="mailto:hello@example.com">hello@example.com</a></li>
        <li>Twitter: <a href="#">@example</a></li>
      </ul>
    </div>
  </main>
  <footer class="site-footer">
    <p>&copy; 2024 ${BLOG_NAME} by ${AUTHOR_NAME}. All rights reserved.</p>
  </footer>
</body>
</html>
HTMLEOF
}

# ----------------------------------------------------------
# 生成 friends.html
# ----------------------------------------------------------
generate_friends_html() {
    local friends_html=""
    for friend in "${FRIENDS[@]}"; do
        IFS='|' read -r name url <<< "$friend"
        friends_html+=$(cat <<FRIEND
      <div class="friend-card">
        <div class="friend-avatar">${name:0:1}</div>
        <div class="friend-info">
          <h3><a href="${url}" target="_blank" rel="noopener">${name}</a></h3>
          <p>${url}</p>
        </div>
      </div>
FRIEND
        )
    done

    local nav_html sidebar_class=""
    if [ "$NAV_STYLE" = "left" ]; then
        local sidebar_friends=""
        for friend in "${FRIENDS[@]}"; do
            IFS='|' read -r name url <<< "$friend"
            sidebar_friends+=$(echo "<li><a href=\"${url}\" target=\"_blank\" rel=\"noopener\">${name}</a></li>")
        done
        nav_html=$(cat <<NAV
    <aside class="sidebar">
      <div class="sidebar-inner">
        <div class="author-card">
          <div class="author-avatar">${AUTHOR_NAME:0:1}</div>
          <h1 class="author-name">${AUTHOR_NAME}</h1>
          <p class="author-role">${AUTHOR_ROLE}</p>
          <p class="author-bio">${AUTHOR_BIO}</p>
        </div>
        <nav class="nav-menu">
          <a href="/" class="nav-link">首页</a>
          <a href="/about.html" class="nav-link">关于</a>
          <a href="/friends.html" class="nav-link active">友链</a>
        </nav>
        <div class="friends-section">
          <h3>友情链接</h3>
          <ul class="friends-list">
            ${sidebar_friends}
          </ul>
        </div>
      </div>
    </aside>
NAV
        )
        sidebar_class="has-sidebar"
    else
        nav_html=$(cat <<NAV
    <header class="top-header">
      <div class="top-header-inner">
        <a href="/" class="logo">${BLOG_NAME}</a>
        <nav class="top-nav">
          <a href="/" class="top-nav-link">首页</a>
          <a href="/about.html" class="top-nav-link">关于</a>
          <a href="/friends.html" class="top-nav-link active">友链</a>
        </nav>
      </div>
    </header>
NAV
        )
    fi

    cat > "$OUTPUT_DIR/friends.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>友情链接 | ${BLOG_NAME}</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { font-size: 16px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: ${TEXT_COLOR}; background: ${BG_COLOR}; line-height: 1.7; -webkit-font-smoothing: antialiased;
    }
    a { color: ${PRIMARY_COLOR}; text-decoration: none; transition: color 0.2s; }
    a:hover { color: ${ACCENT_COLOR}; }
    .top-header {
      background: rgba(255,255,255,0.85); backdrop-filter: blur(12px);
      border-bottom: 1px solid #e5e7eb; position: sticky; top: 0; z-index: 100;
    }
    .top-header-inner {
      max-width: 1120px; margin: 0 auto; padding: 0 1.5rem;
      display: flex; align-items: center; justify-content: space-between; height: 60px;
    }
    .logo { font-size: 1.25rem; font-weight: 700; color: ${PRIMARY_COLOR}; }
    .top-nav { display: flex; gap: 1.5rem; }
    .top-nav-link {
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500;
      padding: 0.25rem 0; border-bottom: 2px solid transparent; transition: all 0.2s;
    }
    .top-nav-link:hover, .top-nav-link.active { color: ${PRIMARY_COLOR}; border-bottom-color: ${PRIMARY_COLOR}; }
    .sidebar {
      position: fixed; top: 0; left: 0; bottom: 0; width: 280px;
      background: #fff; border-right: 1px solid #e5e7eb; overflow-y: auto; z-index: 100;
    }
    .sidebar-inner { padding: 2rem 1.5rem; }
    .author-card { margin-bottom: 2rem; text-align: center; }
    .author-avatar {
      width: 80px; height: 80px; border-radius: 50%; background: ${PRIMARY_COLOR};
      color: #fff; font-size: 2rem; font-weight: 700;
      display: flex; align-items: center; justify-content: center; margin: 0 auto 1rem;
    }
    .author-name { font-size: 1.1rem; font-weight: 700; margin-bottom: 0.25rem; }
    .author-role { font-size: 0.85rem; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .author-bio { font-size: 0.82rem; color: ${TEXT_SECONDARY}; line-height: 1.6; }
    .nav-menu { display: flex; flex-direction: column; gap: 0.25rem; margin-bottom: 2rem; }
    .nav-link {
      display: block; padding: 0.5rem 0.75rem; border-radius: 6px;
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;
    }
    .nav-link:hover, .nav-link.active { background: ${PRIMARY_LIGHT}; color: ${PRIMARY_COLOR}; }
    .friends-section h3 { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .friends-list { list-style: none; }
    .friends-list li { margin-bottom: 0.4rem; }
    .friends-list a { font-size: 0.85rem; color: ${TEXT_SECONDARY}; }
    .friends-list a:hover { color: ${PRIMARY_COLOR}; }
    .main-content { max-width: 800px; margin: 0 auto; padding: 3rem 1.5rem 4rem; }
    body.has-sidebar .main-content { margin-left: 280px; max-width: none; padding: 3rem 2.5rem 4rem; }
    .page-title { font-size: 2rem; font-weight: 800; letter-spacing: -0.03em; margin-bottom: 0.5rem; }
    .page-desc { color: ${TEXT_SECONDARY}; margin-bottom: 2rem; }
    .friends-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
    .friend-card {
      display: flex; align-items: center; gap: 1rem;
      background: #fff; padding: 1.25rem; border-radius: 10px;
      border: 1px solid #e5e7eb; transition: box-shadow 0.2s;
    }
    .friend-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.06); }
    .friend-avatar {
      width: 48px; height: 48px; border-radius: 50%;
      background: ${PRIMARY_LIGHT}; color: ${PRIMARY_COLOR};
      display: flex; align-items: center; justify-content: center;
      font-size: 1.2rem; font-weight: 700; flex-shrink: 0;
    }
    .friend-info h3 { font-size: 0.95rem; font-weight: 600; margin-bottom: 0.15rem; }
    .friend-info p { font-size: 0.8rem; color: ${TEXT_SECONDARY}; }
    .site-footer {
      text-align: center; padding: 2rem 1.5rem; border-top: 1px solid #e5e7eb;
      color: ${TEXT_SECONDARY}; font-size: 0.82rem;
    }
    body.has-sidebar .site-footer { margin-left: 280px; }
    @media (max-width: 768px) {
      .sidebar { display: none; }
      body.has-sidebar .main-content { margin-left: 0; }
      body.has-sidebar .site-footer { margin-left: 0; }
      .friends-grid { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body class="${sidebar_class}">
  ${nav_html}
  <main class="main-content">
    <h1 class="page-title">友情链接</h1>
    <p class="page-desc">以下是我经常阅读和推荐的技术博客与网站。</p>
    <div class="friends-grid">
      ${friends_html}
    </div>
  </main>
  <footer class="site-footer">
    <p>&copy; 2024 ${BLOG_NAME} by ${AUTHOR_NAME}. All rights reserved.</p>
  </footer>
</body>
</html>
HTMLEOF
}

# ----------------------------------------------------------
# 生成文章详情页
# ----------------------------------------------------------
generate_post_pages() {
    mkdir -p "$OUTPUT_DIR/posts"

    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title summary img_prompt date slug <<< "$article"
        local img_url
        img_url=$(make_image_url "$img_prompt")
        local year="${date%%-*}"
        local month_day="${date#*-}"
        local display_date="${year} 年 ${month_day//-/ 月 } 日"

        # 根据模板生成不同领域的文章正文段落
        local body_paragraphs=""
        case "$TEMPLATE_NUM" in
            1) # Go/Kubernetes/云原生
                body_paragraphs=$(cat <<BODY
<p>在过去的几年里，云原生技术栈经历了快速演进。从早期的 Docker 容器化，到 Kubernetes 成为事实标准，再到如今的服务网格和可观测性体系，整个生态正在走向成熟。</p>
<p>本文将从实际项目经验出发，分享我们在生产环境中遇到的问题与解决方案。希望能为正在探索相关技术的同学提供一些参考。</p>
<h2>背景与动机</h2>
<p>随着业务规模的增长，传统的部署方式已经无法满足快速迭代和高可用的需求。微服务架构带来了灵活性的同时，也引入了服务发现、流量管理、故障恢复等新的挑战。</p>
<p>我们在评估了多种方案后，最终选择了基于 Kubernetes 的云原生技术栈作为基础设施的核心。这个决策不仅解决了当下的问题，也为未来的技术演进奠定了基础。</p>
<h2>核心设计</h2>
<p>整体架构遵循了云原生的设计原则：每个服务无状态化，配置与密钥通过 ConfigMap 和 Secret 管理，通过声明式 API 描述期望状态。</p>
<p>在服务间通信方面，我们引入了服务网格来统一处理流量路由、负载均衡和熔断降级。这使得业务代码无需关心这些横切关注点。</p>
<h2>实践经验</h2>
<p>在实际落地过程中，最大的挑战不是技术本身，而是团队文化和工作方式的转变。GitOps 的工作流要求团队对声明式配置和自动化有深入的理解。</p>
<p>我们通过内部培训、文档建设和逐步迁移的方式，帮助团队平稳过渡。关键是要找到合适的切入点，用小的成功案例来建立信心。</p>
<h2>总结与展望</h2>
<p>云原生不是银弹，但它确实为现代软件交付提供了强大的基础设施支撑。未来我们会继续探索 Serverless、边缘计算等方向，持续优化交付效率与系统可靠性。</p>
BODY
                )
                ;;
            2) # Python/数据分析/机器学习
                body_paragraphs=$(cat <<BODY
<p>数据科学领域在过去几年经历了深刻的变化。从传统的统计分析到深度学习的广泛应用，工具和方法论都在不断迭代。作为从业者，保持学习和实践至关重要。</p>
<p>本文将结合具体案例，分享在数据分析和机器学习项目中的实践经验与心得体会。</p>
<h2>问题定义</h2>
<p>任何数据项目的起点都是明确的问题定义。我们经常看到团队在问题尚未清晰的情况下就急于建模，最终产出的结果难以落地。</p>
<p>好的做法是先与业务方充分沟通，明确目标指标、数据可用性和约束条件，再制定技术方案。这一步看似简单，却往往决定了项目的成败。</p>
<h2>数据工程</h2>
<p>数据质量是分析结果可靠性的基石。在真实场景中，数据清洗和特征工程往往占据项目 80% 的时间。缺失值处理、异常值检测、特征编码，每一步都需要结合业务理解。</p>
<p>我们推荐使用 Pipeline 的方式来组织数据预处理流程，确保训练和推理阶段的一致性，同时避免数据泄漏。</p>
<h2>模型选择与评估</h2>
<p>模型选择不应盲目追求复杂度。在很多场景下，简单的线性模型或树模型就能取得不错的效果。关键是要建立合理的评估体系，包括交叉验证策略和业务指标对齐。</p>
<p>可解释性也是模型选择的重要考量。SHAP 值等工具能帮助我们理解模型决策，增强业务方的信任。</p>
<h2>总结</h2>
<p>数据科学项目成功的关键在于业务理解、数据质量和工程实践的有机结合。工具和算法只是手段，真正创造价值的是对问题的深刻洞察。</p>
BODY
                )
                ;;
            3) # 前端/React/TypeScript
                body_paragraphs=$(cat <<BODY
<p>前端开发领域的变化速度之快是有目共睹的。从 jQuery 时代到三大框架鼎立，再到如今的 Server Components 和 Islands Architecture，每一次范式转换都深刻影响着我们的工作方式。</p>
<p>本文将围绕近期前端技术的几个重要趋势，分享我的理解和实践心得。</p>
<h2>技术选型的思考</h2>
<p>技术选型不是追求最新最酷，而是要在团队能力、项目需求和长期维护成本之间找到平衡。React 之所以成为主流选择，不仅因为其生态成熟，更因为其渐进式的设计哲学。</p>
<p>TypeScript 的普及则代表了前端工程化的另一个方向：通过类型系统提升代码的可靠性和开发体验。类型不仅是文档，更是重构的安全网。</p>
<h2>性能优化实践</h2>
<p>性能优化需要数据驱动。我们使用 Lighthouse 和 Web Vitals 建立性能基线，然后针对性地优化关键路径。代码分割、懒加载、资源预加载是最基础也最有效的手段。</p>
<p>在 React 应用中，合理使用 memo、useMemo 和 useCallback 可以避免不必要的重渲染。但更重要的是从架构层面减少状态依赖的复杂度。</p>
<h2>工程化与质量保障</h2>
<p>现代前端项目离不开完善的工程化体系。ESLint、Prettier 保证代码风格一致，Husky + lint-staged 实现提交检查，CI/CD 流水线确保每次变更都经过测试验证。</p>
<p>E2E 测试是保障用户体验的最后一道防线。Playwright 相比 Cypress 在多浏览器支持和执行速度上有明显优势，推荐团队尝试。</p>
<h2>展望</h2>
<p>前端技术的下一个浪潮可能来自 AI 辅助开发和 WebAssembly 的进一步普及。作为工程师，保持好奇心和学习能力，才能在变化中找到自己的定位。</p>
BODY
                )
                ;;
            4) # Rust/系统编程/嵌入式
                body_paragraphs=$(cat <<BODY
<p>系统编程正在经历一场静默的变革。Rust 语言以其独特的所有权系统，在保证内存安全的同时提供了与 C/C++ 相当的性能，正在重新定义系统级软件的开发方式。</p>
<p>本文将从实践角度出发，探讨 Rust 在不同系统编程场景中的应用与思考。</p>
<h2>为什么选择 Rust</h2>
<p>Rust 的核心价值在于编译期安全检查。所有权系统在编译阶段就消除了数据竞争、空指针解引用和缓冲区溢出等常见的安全隐患。这意味着你不需要垃圾回收器，也不需要运行时检查。</p>
<p>对于系统级软件来说，这种零成本抽象的设计哲学至关重要。你不需要在安全和性能之间做取舍——Rust 让你同时拥有两者。</p>
<h2>学习曲线与突破</h2>
<p>不可否认，Rust 的学习曲线是陡峭的。借用检查器会让初学者感到挫败，但当你理解了其背后的设计哲学后，会发现这是一种非常有价值的约束。</p>
<p>我的建议是：不要与编译器对抗，而是学会与它协作。编译器的错误提示非常友好，仔细阅读错误信息往往就能找到解决方案。</p>
<h2>嵌入式开发</h2>
<p>Rust 在嵌入式领域展现出巨大潜力。embassy 框架提供了基于 async/await 的异步编程模型，让嵌入式代码的可读性和可维护性大幅提升。相比传统的回调式或 RTOS 方案，这是一个质的飞跃。</p>
<p>当然，嵌入式 Rust 的生态还在发展中，但核心工具链已经相当成熟。从 HAL 到 RTIC，社区正在构建完整的嵌入式开发工具链。</p>
<h2>总结</h2>
<p>Rust 不仅仅是一门语言，更是一种对软件可靠性的追求。无论是操作系统内核、网络服务还是嵌入式固件，Rust 都在证明安全与性能可以兼得。这条路虽然不易，但值得坚持。</p>
BODY
                )
                ;;
        esac

        # 导航
        local nav_html sidebar_class=""
        if [ "$NAV_STYLE" = "left" ]; then
            local sidebar_friends=""
            for friend in "${FRIENDS[@]}"; do
                IFS='|' read -r fname furl <<< "$friend"
                sidebar_friends+=$(echo "<li><a href=\"${furl}\" target=\"_blank\" rel=\"noopener\">${fname}</a></li>")
            done
            nav_html=$(cat <<NAV
    <aside class="sidebar">
      <div class="sidebar-inner">
        <div class="author-card">
          <div class="author-avatar">${AUTHOR_NAME:0:1}</div>
          <h1 class="author-name">${AUTHOR_NAME}</h1>
          <p class="author-role">${AUTHOR_ROLE}</p>
          <p class="author-bio">${AUTHOR_BIO}</p>
        </div>
        <nav class="nav-menu">
          <a href="/" class="nav-link">首页</a>
          <a href="/about.html" class="nav-link">关于</a>
          <a href="/friends.html" class="nav-link">友链</a>
        </nav>
        <div class="friends-section">
          <h3>友情链接</h3>
          <ul class="friends-list">
            ${sidebar_friends}
          </ul>
        </div>
      </div>
    </aside>
NAV
            )
            sidebar_class="has-sidebar"
        else
            nav_html=$(cat <<NAV
    <header class="top-header">
      <div class="top-header-inner">
        <a href="/" class="logo">${BLOG_NAME}</a>
        <nav class="top-nav">
          <a href="/" class="top-nav-link">首页</a>
          <a href="/about.html" class="top-nav-link">关于</a>
          <a href="/friends.html" class="top-nav-link">友链</a>
        </nav>
      </div>
    </header>
NAV
            )
        fi

        cat > "$OUTPUT_DIR/posts/${slug}.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} | ${BLOG_NAME}</title>
  <meta name="description" content="${summary}">
  <meta name="author" content="${AUTHOR_NAME}">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { font-size: 16px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: ${TEXT_COLOR}; background: ${BG_COLOR}; line-height: 1.7; -webkit-font-smoothing: antialiased;
    }
    a { color: ${PRIMARY_COLOR}; text-decoration: none; transition: color 0.2s; }
    a:hover { color: ${ACCENT_COLOR}; }
    .top-header {
      background: rgba(255,255,255,0.85); backdrop-filter: blur(12px);
      border-bottom: 1px solid #e5e7eb; position: sticky; top: 0; z-index: 100;
    }
    .top-header-inner {
      max-width: 1120px; margin: 0 auto; padding: 0 1.5rem;
      display: flex; align-items: center; justify-content: space-between; height: 60px;
    }
    .logo { font-size: 1.25rem; font-weight: 700; color: ${PRIMARY_COLOR}; }
    .top-nav { display: flex; gap: 1.5rem; }
    .top-nav-link {
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500;
      padding: 0.25rem 0; border-bottom: 2px solid transparent; transition: all 0.2s;
    }
    .top-nav-link:hover, .top-nav-link.active { color: ${PRIMARY_COLOR}; border-bottom-color: ${PRIMARY_COLOR}; }
    .sidebar {
      position: fixed; top: 0; left: 0; bottom: 0; width: 280px;
      background: #fff; border-right: 1px solid #e5e7eb; overflow-y: auto; z-index: 100;
    }
    .sidebar-inner { padding: 2rem 1.5rem; }
    .author-card { margin-bottom: 2rem; text-align: center; }
    .author-avatar {
      width: 80px; height: 80px; border-radius: 50%; background: ${PRIMARY_COLOR};
      color: #fff; font-size: 2rem; font-weight: 700;
      display: flex; align-items: center; justify-content: center; margin: 0 auto 1rem;
    }
    .author-name { font-size: 1.1rem; font-weight: 700; margin-bottom: 0.25rem; }
    .author-role { font-size: 0.85rem; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .author-bio { font-size: 0.82rem; color: ${TEXT_SECONDARY}; line-height: 1.6; }
    .nav-menu { display: flex; flex-direction: column; gap: 0.25rem; margin-bottom: 2rem; }
    .nav-link {
      display: block; padding: 0.5rem 0.75rem; border-radius: 6px;
      color: ${TEXT_SECONDARY}; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;
    }
    .nav-link:hover, .nav-link.active { background: ${PRIMARY_LIGHT}; color: ${PRIMARY_COLOR}; }
    .friends-section h3 { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .friends-list { list-style: none; }
    .friends-list li { margin-bottom: 0.4rem; }
    .friends-list a { font-size: 0.85rem; color: ${TEXT_SECONDARY}; }
    .friends-list a:hover { color: ${PRIMARY_COLOR}; }
    .main-content { max-width: 760px; margin: 0 auto; padding: 2.5rem 1.5rem 4rem; }
    body.has-sidebar .main-content { margin-left: 280px; max-width: none; padding: 2.5rem 2.5rem 4rem; }
    .post-header { margin-bottom: 2rem; }
    .post-meta { font-size: 0.85rem; color: ${TEXT_SECONDARY}; margin-bottom: 0.75rem; }
    .post-title { font-size: 2rem; font-weight: 800; letter-spacing: -0.03em; line-height: 1.3; margin-bottom: 0.75rem; }
    .post-cover {
      width: 100%; aspect-ratio: 16/9; border-radius: 12px; overflow: hidden;
      margin-bottom: 2rem; background: ${PRIMARY_LIGHT};
    }
    .post-cover img { width: 100%; height: 100%; object-fit: cover; }
    .post-body { font-size: 1rem; line-height: 1.9; }
    .post-body h2 {
      font-size: 1.35rem; font-weight: 700; margin: 2rem 0 1rem;
      padding-bottom: 0.5rem; border-bottom: 1px solid #e5e7eb;
    }
    .post-body p { margin-bottom: 1rem; }
    .post-body code {
      background: ${PRIMARY_LIGHT}; color: ${PRIMARY_COLOR}; padding: 0.15em 0.4em;
      border-radius: 4px; font-size: 0.9em;
    }
    .post-body pre {
      background: #1e293b; color: #e2e8f0; padding: 1.25rem;
      border-radius: 8px; overflow-x: auto; margin: 1.5rem 0;
    }
    .post-body pre code { background: none; color: inherit; padding: 0; font-size: 0.88em; }
    .post-footer {
      margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid #e5e7eb;
      display: flex; justify-content: space-between; align-items: center;
    }
    .post-footer a { font-size: 0.9rem; font-weight: 500; }
    .site-footer {
      text-align: center; padding: 2rem 1.5rem; border-top: 1px solid #e5e7eb;
      color: ${TEXT_SECONDARY}; font-size: 0.82rem;
    }
    body.has-sidebar .site-footer { margin-left: 280px; }
    @media (max-width: 768px) {
      .sidebar { display: none; }
      body.has-sidebar .main-content { margin-left: 0; }
      body.has-sidebar .site-footer { margin-left: 0; }
      .post-title { font-size: 1.5rem; }
    }
  </style>
</head>
<body class="${sidebar_class}">
  ${nav_html}
  <main class="main-content">
    <article>
      <div class="post-header">
        <div class="post-meta">
          <time datetime="${date}">${display_date}</time> &middot; ${AUTHOR_NAME}
        </div>
        <h1 class="post-title">${title}</h1>
      </div>
      <div class="post-cover">
        <img src="${img_url}" alt="${title}">
      </div>
      <div class="post-body">
        ${body_paragraphs}
      </div>
      <div class="post-footer">
        <a href="/">&larr; 返回首页</a>
        <a href="/about.html">关于作者</a>
      </div>
    </article>
  </main>
  <footer class="site-footer">
    <p>&copy; 2024 ${BLOG_NAME} by ${AUTHOR_NAME}. All rights reserved.</p>
  </footer>
</body>
</html>
HTMLEOF
    done
}

# ----------------------------------------------------------
# 生成 sitemap.xml
# ----------------------------------------------------------
generate_sitemap() {
    local urls=""
    urls+="    <url>\n      <loc>__DOMAIN__/</loc>\n      <changefreq>weekly</changefreq>\n      <priority>1.0</priority>\n    </url>\n"
    urls+="    <url>\n      <loc>__DOMAIN__/about.html</loc>\n      <changefreq>monthly</changefreq>\n      <priority>0.5</priority>\n    </url>\n"
    urls+="    <url>\n      <loc>__DOMAIN__/friends.html</loc>\n      <changefreq>monthly</changefreq>\n      <priority>0.3</priority>\n    </url>\n"

    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title summary img_prompt date slug <<< "$article"
        urls+="    <url>\n      <loc>__DOMAIN__/posts/${slug}.html</loc>\n      <lastmod>${date}</lastmod>\n      <changefreq>monthly</changefreq>\n      <priority>0.8</priority>\n    </url>\n"
    done

    cat > "$OUTPUT_DIR/sitemap.xml" <<XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$(echo -e "$urls")
</urlset>
XMLEOF
}

# ----------------------------------------------------------
# 生成 robots.txt
# ----------------------------------------------------------
generate_robots() {
    cat > "$OUTPUT_DIR/robots.txt" <<TXTEOF
User-agent: *
Allow: /

Sitemap: __DOMAIN__/sitemap.xml
TXTEOF
}

# ----------------------------------------------------------
# 生成 atom.xml
# ----------------------------------------------------------
generate_atom() {
    local entries=""
    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title summary img_prompt date slug <<< "$article"
        # 构造 RFC 3339 时间戳（用日期的 08:00:00Z）
        local updated="${date}T08:00:00Z"
        entries+=$(cat <<ENTRY

  <entry>
    <title>${title}</title>
    <link href="__DOMAIN__/posts/${slug}.html" rel="alternate" type="text/html"/>
    <id>__DOMAIN__/posts/${slug}.html</id>
    <updated>${updated}</updated>
    <summary>${summary}</summary>
    <author>
      <name>${AUTHOR_NAME}</name>
    </author>
  </entry>
ENTRY
        )
    done

    cat > "$OUTPUT_DIR/atom.xml" <<XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>${BLOG_NAME}</title>
  <subtitle>${BLOG_SUBTITLE}</subtitle>
  <link href="__DOMAIN__/" rel="alternate" type="text/html"/>
  <link href="__DOMAIN__/atom.xml" rel="self" type="application/atom+xml"/>
  <id>__DOMAIN__/</id>
  <updated>${NOW_RFC3339}</updated>
  <author>
    <name>${AUTHOR_NAME}</name>
  </author>${entries}
</feed>
XMLEOF
}

# ----------------------------------------------------------
# 执行生成
# ----------------------------------------------------------
echo "  -> 生成 index.html"
generate_index_html

echo "  -> 生成 404.html"
generate_404_html

echo "  -> 生成 about.html"
generate_about_html

echo "  -> 生成 friends.html"
generate_friends_html

echo "  -> 生成文章详情页"
generate_post_pages

echo "  -> 生成 sitemap.xml"
generate_sitemap

echo "  -> 生成 robots.txt"
generate_robots

echo "  -> 生成 atom.xml"
generate_atom

echo "==> 站点生成完成！模板 ${TEMPLATE_NUM}，共 ${#ARTICLES[@]} 篇文章"
echo "    输出目录: ${OUTPUT_DIR}"
echo "    博客名: ${BLOG_NAME}"
echo "    作者: ${AUTHOR_NAME} (${AUTHOR_ROLE})"
