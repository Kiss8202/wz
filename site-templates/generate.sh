#!/bin/bash
# ============================================================
# 个人技术博客静态站点生成器
# 用法: ./generate.sh <输出目录> [模板编号1-4]
# 模板编号留空则随机选择
# ============================================================

set -e

# 检查参数
OUTPUT_DIR="${1:-}"
TEMPLATE_NUM="${2:-}"

if [ -z "$OUTPUT_DIR" ]; then
    echo "用法: $0 <输出目录> [模板编号1-4]"
    exit 1
fi

# 随机选择模板
if [ -z "$TEMPLATE_NUM" ]; then
    TEMPLATE_NUM=$((RANDOM % 4 + 1))
fi

if ! [[ "$TEMPLATE_NUM" =~ ^[1-4]$ ]]; then
    echo "错误: 模板编号必须是 1-4"
    exit 1
fi

echo "正在生成模板 ${TEMPLATE_NUM} 到 ${OUTPUT_DIR} ..."

# 创建输出目录
mkdir -p "$OUTPUT_DIR/posts"

# 创建临时目录存放文章正文
BODY_DIR=$(mktemp -d)
trap "rm -rf $BODY_DIR" EXIT

# ============================================================
# 模板数据定义
# ============================================================

# 模板1: Go/Kubernetes/云原生 - 蓝色主题
if [ "$TEMPLATE_NUM" -eq 1 ]; then
    BLOG_NAME="云原生笔记"
    BLOGGER_NAME="陈明远"
    BLOGGER_BIO="云原生架构师，专注于 Kubernetes、容器化和微服务领域。热爱开源，坚信基础设施即代码的力量。"
    BLOGGER_SKILLS="Go, Kubernetes, Docker, Helm, Istio, Prometheus, Terraform"
    BLOGGER_EMAIL="chenmingyuan@outlook.com"
    BLOGGER_GITHUB="https://github.com/chenmingyuan"
    PRIMARY_COLOR="#2563eb"
    PRIMARY_LIGHT="#3b82f6"
    PRIMARY_DARK="#1d4ed8"
    BG_COLOR="#f0f5ff"
    CARD_BG="#ffffff"
    TEXT_COLOR="#1e293b"
    TEXT_SECONDARY="#64748b"
    CODE_BG="#1e293b"
    CODE_TEXT="#e2e8f0"
    ACCENT="#0ea5e9"
    NAV_BG="#1e3a5f"
    NAV_TEXT="#e0f2fe"

    CATEGORIES=("Go语言" "Kubernetes" "云原生" "DevOps" "微服务" "容器技术")
    TAGS=("Go" "Kubernetes" "Docker" "Helm" "Istio" "Prometheus" "gRPC" "etcd" "Operator" "CRD" "Service Mesh" "CI/CD" "ArgoCD" "Terraform" "云原生" "微服务" "容器" "DevOps" "监控" "日志")

    # 文章元数据：标题|摘要|分类|标签|日期
    ARTICLES=(
        "使用 Kubebuilder 开发自定义 Operator|Kubernetes 的 Operator 模式让我们可以像原生资源一样管理复杂应用。本文从零开始，使用 Kubebuilder 框架开发一个完整的自定义 Operator，包括 CRD 定义、Controller 逻辑和 Webhook 配置。|Kubernetes|Go Kubebuilder Operator CRD|2025-12-15"
        "Go 语言并发模式：从 Pipeline 到 Worker Pool|Go 语言的 goroutine 和 channel 为并发编程提供了优雅的原语。本文深入探讨几种经典的并发模式，包括 Pipeline、Worker Pool、Fan-in/Fan-out，并结合实际场景给出最佳实践。|Go语言|Go 并发 goroutine channel|2025-11-28"
        "Istio 流量治理实战：灰度发布与流量镜像|Istio 作为 Service Mesh 的事实标准，其流量治理能力是核心亮点。本文通过实际案例演示如何利用 VirtualService 和 DestinationRule 实现金丝雀发布和流量镜像。|云原生|Istio Service Mesh 灰度发布 流量镜像|2025-11-10"
        "Prometheus 监控体系搭建：从指标采集到告警配置|一个完善的监控体系是保障服务稳定性的基石。本文详细介绍 Prometheus 的部署配置、自定义 Exporter 开发、PromQL 查询优化以及 AlertManager 告警规则编写。|DevOps|Prometheus 监控 告警 DevOps|2025-10-22"
        "Docker 多阶段构建优化镜像体积|生产环境的容器镜像体积直接影响部署速度和安全性。本文介绍 Docker 多阶段构建的多种技巧，包括基础镜像选择、层缓存优化和安全加固。|容器技术|Docker 容器 镜像优化|2025-10-05"
        "基于 ArgoCD 的 GitOps 持续交付实践|GitOps 正在成为云原生交付的标准模式。本文分享如何使用 ArgoCD 实现 Kubernetes 应用的声明式持续交付，包括多集群管理和 ApplicationSet 的高级用法。|DevOps|ArgoCD GitOps CI/CD|2025-09-18"
        "深入理解 etcd：从 Raft 共识到实践调优|etcd 是 Kubernetes 的核心存储，理解其内部机制对集群稳定性至关重要。本文从 Raft 协议出发，分析 etcd 的读写流程、性能调优和运维最佳实践。|Kubernetes|etcd Raft Kubernetes 存储|2025-09-01"
        "gRPC 在微服务通信中的最佳实践|微服务间的通信效率直接影响系统性能。本文对比 gRPC 与 REST 的优劣，分享 gRPC 在生产环境中的流控、超时、重试和负载均衡策略。|微服务|gRPC 微服务 负载均衡|2025-08-15"
    )

    ARTICLE_SLUGS=(
        "kubebuilder-custom-operator"
        "go-concurrency-patterns"
        "istio-traffic-management"
        "prometheus-monitoring-setup"
        "docker-multi-stage-build"
        "argocd-gitops-practice"
        "etcd-raft-deep-dive"
        "grpc-microservices-best-practices"
    )

    # 写入文章正文到临时文件
    cat > "$BODY_DIR/0.html" << 'BODYEOF'
<p>Kubernetes 的 Operator 模式将运维知识编码为软件，让我们可以像管理原生资源一样管理复杂的有状态应用。Kubebuilder 作为官方推荐的 Operator 开发框架，提供了脚手架生成、CRD 管理和 Controller 运行时等完整工具链。</p>

<p>首先，我们使用 Kubebuilder 初始化项目并创建 API：</p>

<pre><code># 初始化项目
kubebuilder init --domain my.domain --repo my.domain/guestbook

# 创建 API（包含 CRD 和 Controller）
kubebuilder create api --group webapp --version v1 --kind Guestbook</code></pre>

<p>生成的 CRD 定义在 <code>api/v1/guestbook_types.go</code> 中，我们需要定义资源的期望状态（Spec）和实际状态（Status）：</p>

<pre><code>// GuestbookSpec 定义期望状态
type GuestbookSpec struct {
    // 前端副本数
    FrontendReplicas int32 `json:"frontendReplicas"`
    // Redis 主从配置
    Redis RedisSpec `json:"redis"`
}

// GuestbookStatus 定义观察到的状态
type GuestbookStatus struct {
    AvailableReplicas int32 `json:"availableReplicas"`
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}</code></pre>

<p>Controller 的核心是 Reconcile 循环，它不断将实际状态调谐到期望状态。在 Reconcile 方法中，我们需要处理资源的创建、更新和删除，并确保子资源（Deployment、Service 等）与 CRD 的声明一致。这种声明式的设计让 Operator 具备了自愈能力——当某个 Pod 异常退出时，Controller 会自动重建。</p>

<p>最后，通过 <code>kubebuilder generate crd</code> 生成 CRD 清单，<code>kubebuilder generate webhook</code> 添加准入控制。部署时，将 Manager 以 Deployment 形式运行在集群中，RBAC 权限通过 kubebuilder 注解自动生成。</p>
BODYEOF

    cat > "$BODY_DIR/1.html" << 'BODYEOF'
<p>Go 语言的并发模型基于 CSP（Communicating Sequential Processes），goroutine 轻量级的用户态线程和 channel 类型安全的通信机制，使得并发编程变得直观而高效。本文将深入几种在生产环境中广泛使用的并发模式。</p>

<p>Pipeline 模式将复杂处理拆分为多个阶段，每个阶段通过 channel 串联：</p>

<pre><code>func gen(nums ...int) &lt;-chan int {
    out := make(chan int)
    go func() {
        for _, n := range nums {
            out &lt;- n
        }
        close(out)
    }()
    return out
}

func square(in &lt;-chan int) &lt;-chan int {
    out := make(chan int)
    go func() {
        for n := range in {
            out &lt;- n * n
        }
        close(out)
    }()
    return out
}

// 串联: gen -&gt; square -&gt; 消费
pipeline := square(square(gen(2, 3)))</code></pre>

<p>Worker Pool 模式通过固定数量的 goroutine 处理任务，避免无限制创建 goroutine 导致的资源耗尽：</p>

<pre><code>func worker(id int, jobs &lt;-chan int, results chan&lt;- int) {
    for j := range jobs {
        results &lt;- j * j
    }
}

// 启动 3 个 worker
for w := 1; w &lt;= 3; w++ {
    go worker(w, jobs, results)
}</code></pre>

<p>Fan-in/Fan-out 模式将一个 channel 的数据分发到多个处理 goroutine，再将结果汇聚到一个输出 channel。这种模式在需要并行处理大量独立任务时特别有效，比如批量 HTTP 请求或数据转换。关键是要正确处理 channel 的关闭和 context 的取消，确保 goroutine 不会泄漏。</p>

<p>在实际项目中，这些模式往往组合使用。例如我们的日志处理管道就采用了 Pipeline + Worker Pool 的混合架构，单机 QPS 从 5000 提升到了 28000，同时内存占用保持在可控范围内。</p>
BODYEOF

    cat > "$BODY_DIR/2.html" << 'BODYEOF'
<p>Istio 的流量治理能力是它成为 Service Mesh 事实标准的核心原因。通过 VirtualService 和 DestinationRule 的配合，我们可以实现精细化的流量控制，无需修改任何业务代码。</p>

<p>金丝雀发布是最常见的灰度策略，以下配置将 10% 的流量导向新版本：</p>

<pre><code>apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
            subset: v1
          weight: 90
        - destination:
            host: my-service
            subset: v2
          weight: 10</code></pre>

<p>流量镜像（Traffic Mirroring）是另一个强大的功能，它将实时流量的副本发送到镜像服务，不影响正常请求的响应。这让我们可以在真实流量下验证新版本，而不承担任何风险：</p>

<pre><code>apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
            subset: v1
      mirror:
        host: my-service
        subset: v2
      mirrorPercentage:
        value: 100.0</code></pre>

<p>在我们的实践中，流量镜像帮助团队在上线前发现了一个只在特定请求头组合下才会触发的 bug，避免了可能影响 20% 用户的线上事故。配合 Grafana 仪表盘实时对比 v1 和 v2 的延迟和错误率，灰度发布变得可观测、可回滚。</p>
BODYEOF

    cat > "$BODY_DIR/3.html" << 'BODYEOF'
<p>监控是 SRE 工作的基础，而 Prometheus 凭借其强大的多维数据模型和 PromQL 查询语言，已成为云原生监控的事实标准。本文从零开始搭建一套完整的监控体系。</p>

<p>首先部署 Prometheus 核心组件，配置服务发现自动采集 Kubernetes 集群指标：</p>

<pre><code>global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "kubernetes-pods"
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true</code></pre>

<p>自定义 Exporter 的开发也很简单，以下是一个使用 Go 实现的业务指标采集器：</p>

<pre><code>var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
    promhttp.Handler().ServeHTTP(w, r)
}</code></pre>

<p>AlertManager 的告警规则需要精心设计，避免告警风暴。我们采用了分级策略：P0 级别（服务不可用）立即通知值班人员，P1 级别（延迟升高）5 分钟内通知，P2 级别（资源使用率偏高）仅在工作时间通知。配合路由分组和抑制规则，确保每条告警都有价值。</p>
BODYEOF

    cat > "$BODY_DIR/4.html" << 'BODYEOF'
<p>容器镜像的体积直接影响拉取速度、存储成本和攻击面。多阶段构建（Multi-stage Build）是优化镜像体积最有效的手段之一，它允许我们在一个 Dockerfile 中使用多个 FROM 指令，每个 FROM 开始一个新的构建阶段。</p>

<p>以 Go 应用为例，典型的多阶段构建如下：</p>

<pre><code># 构建阶段
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server .

# 运行阶段
FROM scratch
COPY --from=builder /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]</code></pre>

<p>这个 Dockerfile 最终生成的镜像只有二进制文件本身，通常在 10-20MB。而如果不使用多阶段构建，基于 golang 镜像的最终产物可能超过 800MB。对于 Node.js 应用，我们可以使用类似策略：</p>

<pre><code>FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/main.js"]</code></pre>

<p>除了多阶段构建，还有一些实用技巧：使用 Alpine 或 distroless 作为基础镜像、合并 RUN 指令减少层数、利用 .dockerignore 排除无关文件、以及使用 BuildKit 的缓存挂载加速依赖安装。在我们的项目中，综合运用这些技巧后，平均镜像体积减少了 75%。</p>
BODYEOF

    cat > "$BODY_DIR/5.html" << 'BODYEOF'
<p>GitOps 的核心理念是：Git 仓库是应用部署状态的唯一事实来源。ArgoCD 作为 Kubernetes 原生的持续交付工具，完美践行了这一理念——它持续监控 Git 仓库的变更，并自动将集群状态同步到声明式配置。</p>

<p>ArgoCD 的核心资源是 Application，以下是一个典型的应用定义：</p>

<pre><code>apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-manifests.git
    targetRevision: main
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true</code></pre>

<p>对于多集群场景，ApplicationSet 提供了强大的模板化能力。我们可以用 Generator 自动为每个集群生成 Application：</p>

<pre><code>apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app-clusters
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: production
  template:
    metadata:
      name: "{{name}}-my-app"
    spec:
      source:
        repoURL: https://github.com/org/k8s-manifests.git
        path: overlays/production
      destination:
        server: "{{server}}"
        namespace: production</code></pre>

<p>在我们的实践中，ArgoCD 的自助回滚功能多次拯救了团队。当一次有问题的提交导致集群状态偏离时，ArgoCD 检测到健康检查失败并自动回滚到上一个已知良好的状态。配合 Slack 通知和 ArgoCD Rollouts 的渐进式交付，我们的发布流程既安全又高效。</p>
BODYEOF

    cat > "$BODY_DIR/6.html" << 'BODYEOF'
<p>etcd 是 Kubernetes 集群的"大脑"，所有集群状态数据都存储其中。理解 etcd 的内部机制，对于保障 Kubernetes 集群的稳定性至关重要。本文从 Raft 共识协议出发，逐步深入 etcd 的架构和实践。</p>

<p>Raft 协议通过领导者选举和日志复制确保分布式一致性。etcd 在 Raft 之上实现了 MVCC 存储引擎，每次修改都生成一个新的修订版本：</p>

<pre><code># 查看修订版本
etcdctl get / --prefix -w json | jq .header.revision

# 基于修订版本的事务
etcdctl txn &lt;&lt;EOF
mod("key1") &gt; "0"
then
  put key1 "new_value"
else
  put key1 "initial_value"
EOF</code></pre>

<p>etcd 的性能调优需要关注几个关键参数。首先，调整心跳间隔和选举超时以适应网络延迟：</p>

<pre><code># 在 etcd 配置中
heartbeat-interval: 100    # 默认100ms，跨机房部署建议200ms
election-timeout: 1000     # 默认1000ms，跨机房部署建议2000ms
snapshot-count: 10000      # 快照触发阈值
quota-backend-bytes: 8589934592  # 8GB 存储配额</code></pre>

<p>运维方面，定期备份数据是重中之重。我们使用 etcdctl snapshot save 定期备份到对象存储，并在预发环境定期演练恢复流程。同时，通过 etcdctl endpoint status --write-out=table 监控各成员的 Raft 索引差异，确保集群健康。记住：etcd 的延迟直接影响 Kubernetes API 的响应速度，任何超过 100ms 的慢查询都需要排查。</p>
BODYEOF

    cat > "$BODY_DIR/7.html" << 'BODYEOF'
<p>微服务架构下，服务间通信的效率直接影响系统整体性能。gRPC 基于 HTTP/2 和 Protocol Buffers，相比传统 REST+JSON 方案，在吞吐量和延迟上都有显著优势。本文分享我们在生产环境中使用 gRPC 的实践经验。</p>

<p>首先定义 protobuf 服务契约：</p>

<pre><code>syntax = "proto3";

package order;

service OrderService {
  rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
  rpc ListOrders(ListOrdersRequest) returns (stream Order);
  rpc CreateOrders(stream CreateOrderRequest) returns (stream CreateOrderResponse);
}</code></pre>

<p>gRPC 内置了多种负载均衡策略。在 Kubernetes 环境中，我们推荐使用客户端负载均衡 + Headless Service：</p>

<pre><code>// Go 客户端配置
resolver, _ := resolver.NewBuilder()
cc, _ := grpc.Dial(
    "dns:///order-service.default.svc.cluster.local:9090",
    grpc.WithDefaultServiceConfig(`{
        "loadBalancingConfig": [{"round_robin":{}}]
    }`),
    grpc.WithResolvers(resolver),
)</code></pre>

<p>超时和重试是保障服务稳定性的关键。我们使用 gRPC 的透明重试和应用层重试相结合的策略：对幂等操作配置最多 3 次重试，指数退避间隔从 100ms 开始。同时，通过 OpenTelemetry 采集 gRPC 指标，在 Grafana 中建立延迟百分位数和错误率的实时监控面板。在我们的订单系统中，引入 gRPC 后 P99 延迟从 120ms 降到了 35ms，吞吐量提升了 3 倍。</p>
BODYEOF

    # 友链数据
    FRIENDS=(
        "K8s技术圈|https://kubernetes.io|Kubernetes官方文档|https://picsum.photos/seed/k8s-friend/60/60"
        "Go语言中文网|https://go.dev|Go语言官方网站|https://picsum.photos/seed/golang-friend/60/60"
        "云原生实验室|https://www.cncf.io|云原生基金会|https://picsum.photos/seed/cncf-friend/60/60"
        "DevOps之路|https://stackoverflow.com|开发者问答社区|https://picsum.photos/seed/devops-friend/60/60"
    )

# 模板2: Python/数据分析/机器学习 - 紫色主题
elif [ "$TEMPLATE_NUM" -eq 2 ]; then
    BLOG_NAME="数据拾遗"
    BLOGGER_NAME="林晓薇"
    BLOGGER_BIO="数据科学家，专注于机器学习与数据可视化。相信数据中蕴藏着改变世界的力量，致力于让复杂的数据变得可理解。"
    BLOGGER_SKILLS="Python, PyTorch, Pandas, Scikit-learn, Matplotlib, SQL, Spark"
    BLOGGER_EMAIL="linxiaowei@outlook.com"
    BLOGGER_GITHUB="https://github.com/linxiaowei"
    PRIMARY_COLOR="#7c3aed"
    PRIMARY_LIGHT="#8b5cf6"
    PRIMARY_DARK="#6d28d9"
    BG_COLOR="#faf5ff"
    CARD_BG="#ffffff"
    TEXT_COLOR="#1e1b4b"
    TEXT_SECONDARY="#6b7280"
    CODE_BG="#1e1b4b"
    CODE_TEXT="#e0e7ff"
    ACCENT="#a78bfa"
    NAV_BG="#3b0764"
    NAV_TEXT="#ede9fe"

    CATEGORIES=("机器学习" "数据分析" "Python" "深度学习" "数据可视化" "自然语言处理")
    TAGS=("Python" "PyTorch" "Pandas" "Scikit-learn" "NLP" "Transformer" "CNN" "数据清洗" "特征工程" "模型调优" "Matplotlib" "Seaborn" "Spark" "SQL" "时间序列" "推荐系统" "异常检测" "A/B测试" "数据可视化" "MLOps")

    ARTICLES=(
        "用 Transformer 构建中文文本分类模型|Transformer 架构在 NLP 领域的革命性影响已经无需多言。本文从零实现一个基于 Transformer 的中文文本分类模型，涵盖分词、词嵌入、多头注意力到分类头的完整流程。|自然语言处理|Python Transformer NLP 深度学习|2025-12-10"
        "Pandas 高效数据清洗的 20 个技巧|数据清洗占据了数据分析 80% 的时间。本文总结了 20 个实用的 Pandas 数据清洗技巧，从缺失值处理到字符串规范化，帮你大幅提升数据预处理效率。|数据分析|Python Pandas 数据清洗|2025-11-25"
        "PyTorch 实战：图像分割从入门到部署|图像分割是计算机视觉的核心任务之一。本文使用 PyTorch 实现 U-Net 分割模型，从数据增强到模型训练，再到 ONNX 导出和 TensorRT 部署，覆盖完整工程链路。|深度学习|PyTorch CNN 图像分割 部署|2025-11-08"
        "特征工程的艺术：从业务理解到自动化|好的特征工程往往比模型选择更重要。本文结合金融风控场景，系统介绍特征工程的思路和方法，包括时序特征、交叉特征和自动化特征生成。|机器学习|特征工程 Scikit-learn 模型调优|2025-10-20"
        "Matplotlib 与 Seaborn 数据可视化进阶|一图胜千言。本文深入 Matplotlib 和 Seaborn 的高级用法，包括自定义主题、多子图布局、动画可视化和交互式图表，让你的数据分析报告更专业。|数据可视化|Python Matplotlib Seaborn 数据可视化|2025-10-03"
        "时间序列预测：从 ARIMA 到 Prophet|时间序列预测在业务决策中至关重要。本文对比传统统计方法和现代机器学习方法，详细介绍 ARIMA、Prophet 和 LSTM 在不同场景下的表现。|数据分析|时间序列 ARIMA Prophet Python|2025-09-15"
        "推荐系统实战：协同过滤到深度学习|推荐系统是互联网产品的核心引擎。本文从经典的协同过滤出发，逐步过渡到基于深度学习的推荐模型，包括 Wide&Deep、DIN 和双塔模型。|机器学习|推荐系统 协同过滤 深度学习|2025-08-28"
        "Spark 大规模数据处理最佳实践|当数据量超过单机处理能力时，Spark 是首选方案。本文分享 Spark 在生产环境中的调优经验，包括内存管理、数据倾斜处理和广播变量优化。|数据分析|Spark Python 大数据 性能调优|2025-08-10"
    )

    ARTICLE_SLUGS=(
        "transformer-chinese-text-classification"
        "pandas-data-cleaning-tips"
        "pytorch-image-segmentation"
        "feature-engineering-art"
        "matplotlib-seaborn-advanced-viz"
        "time-series-arima-prophet"
        "recommendation-system-practice"
        "spark-big-data-best-practices"
    )

    cat > "$BODY_DIR/0.html" << 'BODYEOF'
<p>Transformer 架构自 2017 年提出以来，彻底改变了 NLP 的面貌。相比 RNN 的序列依赖，Transformer 的自注意力机制可以并行处理所有位置，大幅提升训练效率。本文从零实现一个中文文本分类模型。</p>

<p>首先进行中文分词和词表构建：</p>

<pre><code>import torch
from torch.utils.data import Dataset, DataLoader

class TextDataset(Dataset):
    def __init__(self, texts, labels, vocab, max_len=128):
        self.texts = texts
        self.labels = labels
        self.vocab = vocab
        self.max_len = max_len

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        tokens = list(self.texts[idx])  # 字级别分词
        ids = [self.vocab.get(t, 1) for t in tokens[:self.max_len]]
        ids = ids + [0] * (self.max_len - len(ids))
        return torch.tensor(ids), torch.tensor(self.labels[idx])</code></pre>

<p>多头注意力是 Transformer 的核心组件：</p>

<pre><code>class MultiHeadAttention(nn.Module):
    def __init__(self, d_model, n_heads):
        super().__init__()
        self.d_k = d_model // n_heads
        self.n_heads = n_heads
        self.W_q = nn.Linear(d_model, d_model)
        self.W_k = nn.Linear(d_model, d_model)
        self.W_v = nn.Linear(d_model, d_model)
        self.W_o = nn.Linear(d_model, d_model)

    def forward(self, Q, K, V, mask=None):
        scores = torch.matmul(Q, K.transpose(-2, -1)) / math.sqrt(self.d_k)
        if mask is not None:
            scores = scores.masked_fill(mask == 0, -1e9)
        attn = F.softmax(scores, dim=-1)
        return self.W_o(torch.matmul(attn, V))</code></pre>

<p>在 THUCNews 数据集上的实验表明，我们的模型在 10 分类任务上达到了 94.2% 的准确率，比 TextCNN 提升了 2.1 个百分点。关键优化包括：使用学习率预热策略、标签平滑正则化和混合精度训练。</p>
BODYEOF

    cat > "$BODY_DIR/1.html" << 'BODYEOF'
<p>数据清洗是数据分析的第一步，也是最耗时的环节。掌握高效的 Pandas 技巧，可以让你的数据预处理效率提升数倍。本文总结了 20 个最实用的技巧。</p>

<p>缺失值处理是最常见的清洗任务：</p>

<pre><code># 智能填充：根据分组均值填充缺失值
df["salary"] = df.groupby("department")["salary"].transform(
    lambda x: x.fillna(x.median())
)

# 多列联合判断缺失
df_clean = df.dropna(subset=["email", "phone"], how="all")

# 前向填充 + 插值组合
df["value"] = df["value"].fillna(method="ffill").interpolate()</code></pre>

<p>字符串规范化是另一个常见痛点：</p>

<pre><code># 统一电话号码格式
df["phone"] = df["phone"].str.replace(r"\D", "", regex=True)

# 提取邮箱域名
df["email_domain"] = df["email"].str.extract(r"@([\w.]+)")

# 拆分复合字段
df[["city", "district"]] = df["address"].str.split("市", n=1, expand=True)</code></pre>

<p>对于重复数据处理，<code>drop_duplicates</code> 配合 <code>subset</code> 参数可以精确控制去重逻辑。而 <code>merge</code> 时的重复列名问题，可以通过 <code>suffixes</code> 参数优雅解决。在处理百万级数据时，将 <code>object</code> 类型转为 <code>category</code> 可以节省 90% 以上的内存，这是最容易被忽视的优化技巧。</p>

<p>最后，建议将常用的清洗步骤封装为函数，配合 <code>pipe</code> 方法实现链式调用，让代码更清晰、更可复用。</p>
BODYEOF

    cat > "$BODY_DIR/2.html" << 'BODYEOF'
<p>图像分割要求模型对每个像素进行分类，是计算机视觉中最精细的任务之一。U-Net 以其编码器-解码器结构和跳跃连接，成为医学图像和遥感图像分割的首选架构。</p>

<p>U-Net 的核心实现：</p>

<pre><code>class UNet(nn.Module):
    def __init__(self, in_channels=3, num_classes=2):
        super().__init__()
        # 编码器
        self.enc1 = self.conv_block(in_channels, 64)
        self.enc2 = self.conv_block(64, 128)
        self.enc3 = self.conv_block(128, 256)
        # 解码器
        self.dec3 = self.up_block(256, 128)
        self.dec2 = self.up_block(128, 64)
        self.final = nn.Conv2d(64, num_classes, 1)

    def conv_block(self, in_c, out_c):
        return nn.Sequential(
            nn.Conv2d(in_c, out_c, 3, padding=1),
            nn.BatchNorm2d(out_c),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_c, out_c, 3, padding=1),
            nn.BatchNorm2d(out_c),
            nn.ReLU(inplace=True),
        )</code></pre>

<p>数据增强对分割任务至关重要。我们使用 Albumentations 库实现同步的图像和掩码增强：</p>

<pre><code>transform = A.Compose([
    A.RandomCrop(256, 256),
    A.HorizontalFlip(p=0.5),
    A.RandomBrightnessContrast(p=0.3),
    A.ElasticTransform(p=0.3),
    A.Normalize(),
])</code></pre>

<p>模型部署方面，我们通过 ONNX 导出和 TensorRT 优化，将推理延迟从 45ms 降低到 8ms，满足了实时分割的需求。关键步骤包括：固定 BatchNorm、融合卷积层、选择 FP16 精度模式。</p>
BODYEOF

    cat > "$BODY_DIR/3.html" << 'BODYEOF'
<p>在机器学习项目中，特征工程往往比模型选择更能决定最终效果。好的特征可以化繁为简，让简单模型也能取得优异表现。本文结合金融风控场景，系统梳理特征工程的方法论。</p>

<p>时序特征是金融场景最重要的特征类型：</p>

<pre><code># 滑动窗口统计特征
for window in [7, 14, 30]:
    df[f"amount_mean_{window}d"] = (
        df.groupby("user_id")["amount"]
        .transform(lambda x: x.rolling(window, min_periods=1).mean())
    )
    df[f"amount_std_{window}d"] = (
        df.groupby("user_id")["amount"]
        .transform(lambda x: x.rolling(window, min_periods=1).std())
    )

# 距离特征：距上次交易的天数
df["days_since_last"] = df.groupby("user_id")["date"].diff().dt.days</code></pre>

<p>交叉特征可以捕捉特征间的交互效应：</p>

<pre><code>from sklearn.preprocessing import PolynomialFeatures

# 二阶交叉
poly = PolynomialFeatures(degree=2, interaction_only=True, include_bias=False)
cross_features = poly.fit_transform(df[["amount", "hour", "is_weekend"]])</code></pre>

<p>自动化特征工程方面，Featuretools 是一个强大的工具，它可以自动从关系型数据中生成深层特征。但要注意特征选择——过多的特征会导致维度灾难和过拟合。我们使用基于树模型的重要性排序和递归特征消除（RFE），将 500+ 特征精简到 80 个关键特征，模型 AUC 反而从 0.82 提升到了 0.87。</p>
BODYEOF

    cat > "$BODY_DIR/4.html" << 'BODYEOF'
<p>数据可视化是数据分析的"最后一公里"，好的图表能让洞察一目了然。Matplotlib 的灵活性加上 Seaborn 的统计图表，足以应对绝大多数可视化需求。</p>

<p>自定义主题让你的图表风格统一：</p>

<pre><code>import matplotlib.pyplot as plt
import seaborn as sns

# 自定义主题
plt.rcParams.update({
    "figure.facecolor": "#fafafa",
    "axes.facecolor": "#fafafa",
    "axes.grid": True,
    "grid.alpha": 0.3,
    "font.family": "sans-serif",
    "font.size": 12,
})

# Seaborn 配色
sns.set_palette("husl")</code></pre>

<p>多子图布局是复杂报告的常见需求：</p>

<pre><code>fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# 分布对比
sns.histplot(data=df, x="price", hue="category", ax=axes[0, 0])

# 箱线图
sns.boxplot(data=df, x="category", y="price", ax=axes[0, 1])

# 散点矩阵
sns.scatterplot(data=df, x="feature1", y="feature2",
                size="price", hue="category", ax=axes[1, 0])

# 热力图
corr = df.select_dtypes(include="number").corr()
sns.heatmap(corr, annot=True, fmt=".2f", cmap="RdBu_r", ax=axes[1, 1])

plt.tight_layout()
plt.savefig("report.png", dpi=150, bbox_inches="tight")</code></pre>

<p>对于交互式可视化，Plotly 和 Altair 是更好的选择。但在生成报告和论文图表时，Matplotlib 的像素级控制能力无可替代。建议将常用的图表模板封装为函数，配合 Jupyter Magic 命令，实现一键生成标准化报告。</p>
BODYEOF

    cat > "$BODY_DIR/5.html" << 'BODYEOF'
<p>时间序列预测在销售预测、容量规划和金融分析中有着广泛应用。从经典的 ARIMA 到现代的 Prophet 和 LSTM，不同方法各有优劣，选择合适的方法是关键。</p>

<p>ARIMA 模型需要先确定 p、d、q 参数：</p>

<pre><code>from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.stattools import adfuller

# 平稳性检验
result = adfuller(df["value"])
print(f"ADF Statistic: {result[0]:.4f}")
print(f"p-value: {result[1]:.4f}")

# 差分阶数确定
if result[1] > 0.05:
    d = 1  # 需要一阶差分

# 拟合 ARIMA
model = ARIMA(df["value"], order=(2, 1, 2))
results = model.fit()
forecast = results.forecast(steps=30)</code></pre>

<p>Facebook 的 Prophet 更适合业务场景，它自动处理趋势变化点和季节性：</p>

<pre><code>from prophet import Prophet

df_prophet = df.rename(columns={"date": "ds", "value": "y"})
model = Prophet(
    yearly_seasonality=True,
    weekly_seasonality=True,
    changepoint_prior_scale=0.05,
)
model.fit(df_prophet)
future = model.make_future_dataframe(periods=90)
forecast = model.predict(future)
fig = model.plot_components(forecast)</code></pre>

<p>在我们的销售预测项目中，Prophet 在日粒度数据上表现最好（MAPE 8.2%），LSTM 在捕捉长期依赖方面有优势但训练成本高，ARIMA 在短期预测上依然稳健。实际生产中，我们采用了 Prophet + LSTM 的集成方案，加权平均后 MAPE 降到了 6.5%。</p>
BODYEOF

    cat > "$BODY_DIR/6.html" << 'BODYEOF'
<p>推荐系统是电商、内容平台和社交媒体的核心技术。从基于记忆的协同过滤到深度学习模型，推荐技术经历了多次范式演进。本文沿着这条演进路线，逐步构建更强大的推荐模型。</p>

<p>协同过滤是最经典的推荐方法：</p>

<pre><code>from scipy.sparse import csr_matrix
from sklearn.metrics.pairwise import cosine_similarity

# 构建用户-物品矩阵
user_item = csr_matrix((ratings["rating"], (ratings["user_id"], ratings["item_id"])))

# 基于物品的协同过滤
item_sim = cosine_similarity(user_item.T)

def recommend(user_id, top_k=10):
    user_ratings = user_item[user_id].toarray().flatten()
    scores = user_ratings @ item_sim
    scores[user_ratings > 0] = 0  # 排除已交互物品
    return np.argsort(scores)[-top_k:][::-1]</code></pre>

<p>深度学习推荐模型以 Wide&amp;Deep 为起点：</p>

<pre><code>class WideAndDeep(nn.Module):
    def __init__(self, num_users, num_items, embed_dim=64):
        super().__init__()
        self.wide = nn.Linear(num_items, 1)
        self.user_embed = nn.Embedding(num_users, embed_dim)
        self.item_embed = nn.Embedding(num_items, embed_dim)
        self.deep = nn.Sequential(
            nn.Linear(embed_dim * 2, 128),
            nn.ReLU(),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Linear(64, 1),
        )

    def forward(self, user_ids, item_ids, wide_input):
        wide_out = self.wide(wide_input)
        deep_out = self.deep(
            torch.cat([self.user_embed(user_ids), self.item_embed(item_ids)], dim=1)
        )
        return torch.sigmoid(wide_out + deep_out)</code></pre>

<p>在实际部署中，双塔模型因其推理效率成为工业界主流。用户塔和物品塔分别产出向量，在线服务只需计算向量相似度即可完成推荐，延迟控制在 10ms 以内。</p>
BODYEOF

    cat > "$BODY_DIR/7.html" << 'BODYEOF'
<p>当数据量达到 TB 级别，单机的 Pandas 就无能为力了。Apache Spark 凭借分布式计算能力和丰富的 API，成为大数据处理的事实标准。本文分享 Spark 在生产环境中的最佳实践。</p>

<p>数据倾斜是 Spark 最常见的问题：</p>

<pre><code># 检测倾斜：查看各分区的数据量
df.rdd.mapPartitions(lambda x: [sum(1 for _ in x)]).collect()

# 方案1：加盐打散
from pyspark.sql.functions import col, concat, lit, rand

salted = df.withColumn("salted_key",
    concat(col("skew_key"), lit("_"), (rand() * 10).cast("int")))

# 方案2：广播小表
from pyspark.sql.functions import broadcast

result = large_df.join(broadcast(small_df), "key")</code></pre>

<p>内存管理是另一个关键调优点：</p>

<pre><code># Spark 配置优化
spark.conf.set("spark.sql.shuffle.partitions", "200")
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.memory.fraction", "0.8")
spark.conf.set("spark.memory.storageFraction", "0.3")</code></pre>

<p>AQE（自适应查询执行）是 Spark 3.0 的重要特性，它可以在运行时根据实际数据量动态调整执行计划。在我们的日志分析管道中，启用 AQE 后，由于自动合并小分区和动态切换 Join 策略，整体执行时间减少了 40%。结合 Delta Lake 的事务保证和时间旅行功能，我们的数据管道终于实现了端到端的可靠性。</p>
BODYEOF

    FRIENDS=(
        "Python数据之道|https://realpython.com|Python实战教程|https://picsum.photos/seed/realpython-friend/60/60"
        "机器学习笔记|https://python.org|Python官方网站|https://picsum.photos/seed/python-friend/60/60"
        "数据可视化工坊|https://stackoverflow.com|开发者问答社区|https://picsum.photos/seed/dataviz-friend/60/60"
        "深度学习前沿|https://github.com|开源代码托管|https://picsum.photos/seed/github-friend/60/60"
    )

# 模板3: 前端/React/TypeScript - 绿色主题
elif [ "$TEMPLATE_NUM" -eq 3 ]; then
    BLOG_NAME="像素之外"
    BLOGGER_NAME="苏逸凡"
    BLOGGER_BIO="前端架构师，React 核心贡献者。痴迷于像素级的完美，相信好的用户体验来自对细节的极致追求。"
    BLOGGER_SKILLS="React, TypeScript, Next.js, Tailwind CSS, Webpack, Node.js"
    BLOGGER_EMAIL="suyifan@outlook.com"
    BLOGGER_GITHUB="https://github.com/suyifan"
    PRIMARY_COLOR="#16a34a"
    PRIMARY_LIGHT="#22c55e"
    PRIMARY_DARK="#15803d"
    BG_COLOR="#f0fdf4"
    CARD_BG="#ffffff"
    TEXT_COLOR="#14532d"
    TEXT_SECONDARY="#6b7280"
    CODE_BG="#0f172a"
    CODE_TEXT="#e2e8f0"
    ACCENT="#10b981"
    NAV_BG="#14532d"
    NAV_TEXT="#dcfce7"

    CATEGORIES=("React" "TypeScript" "前端工程化" "CSS" "性能优化" "Node.js")
    TAGS=("React" "TypeScript" "Next.js" "Tailwind" "Webpack" "Vite" "SSR" "Hooks" "Redux" "Zustand" "CSS" "动画" "性能优化" "PWA" "微前端" "Monorepo" "ESLint" "Vitest" "Storybook" "Figma")

    ARTICLES=(
        "React 19 新特性深度解析|React 19 带来了期待已久的编译器、Server Components 和 Actions 等重磅特性。本文逐一解析这些新特性的设计动机和使用方式，帮助你快速上手。|React|React Server Components Hooks 编译器|2025-12-08"
        "TypeScript 5.x 类型体操实战指南|TypeScript 的类型系统是图灵完备的，掌握高级类型技巧可以大幅提升代码的类型安全性。本文通过实际案例，深入条件类型、映射类型和模板字面量类型。|TypeScript|TypeScript 类型体操 条件类型|2025-11-22"
        "Next.js App Router 架构设计与实践|Next.js 13 引入的 App Router 彻底改变了应用的组织方式。本文分享从 Pages Router 迁移到 App Router 的架构设计思路和踩坑记录。|React|Next.js App Router SSR 架构|2025-11-05"
        "Tailwind CSS 实战：从抵触到真香|从最初的不理解到现在的深度使用，本文分享 Tailwind CSS 在大型项目中的实践经验，包括自定义设计系统、组件封装和性能优化。|CSS|Tailwind CSS 设计系统 组件化|2025-10-18"
        "前端性能优化：从指标到实践|性能是用户体验的基石。本文系统梳理 Core Web Vitals 的优化策略，从 LCP、FID 到 CLS，每个指标都给出可落地的优化方案。|性能优化|性能优化 Core Web Vitals LCP|2025-10-01"
        "Vite 插件开发：打造自己的构建工具链|Vite 的插件机制灵活而强大。本文从零开发一个 Vite 插件，深入理解 Rollup 插件兼容、HMR 更新和虚拟模块等核心概念。|前端工程化|Vite 插件 Rollup HMR|2025-09-12"
        "微前端架构落地：Module Federation 实战|微前端让大型应用可以独立开发部署。本文基于 Webpack 5 的 Module Federation，分享微前端架构的落地方案和踩坑经验。|前端工程化|微前端 Module Federation 架构|2025-08-25"
        "CSS 容器查询：响应式设计的新范式|容器查询让组件可以根据自身容器大小响应式调整，彻底改变了响应式设计的思路。本文全面介绍容器查询的语法和最佳实践。|CSS|CSS 容器查询 响应式 组件化|2025-08-08"
    )

    ARTICLE_SLUGS=(
        "react-19-features"
        "typescript-type-gymnastics"
        "nextjs-app-router-architecture"
        "tailwind-css-in-practice"
        "frontend-performance-optimization"
        "vite-plugin-development"
        "micro-frontend-module-federation"
        "css-container-queries"
    )

    cat > "$BODY_DIR/0.html" << 'BODYEOF'
<p>React 19 是近年来最重要的版本更新，它不仅带来了新的 API，更重要的是改变了我们思考和编写 React 应用的方式。编译器的引入让 React 终于可以自动优化重渲染，无需手动使用 useMemo 和 useCallback。</p>

<p>Server Components 是 React 19 的核心特性，它让组件可以在服务端渲染，减少客户端 JavaScript 体积：</p>

<pre><code>// Server Component - 默认在服务端渲染
async function ArticleList() {
    const articles = await db.query("SELECT * FROM articles");
    return (
        &lt;ul&gt;
            {articles.map(article =&gt; (
                &lt;li key={article.id}&gt;
                    &lt;h2&gt;{article.title}&lt;/h2&gt;
                    &lt;p&gt;{article.excerpt}&lt;/p&gt;
                &lt;/li&gt;
            ))}
        &lt;/ul&gt;
    );
}</code></pre>

<p>Actions 简化了表单处理和数据变更：</p>

<pre><code>function CreateArticle() {
    async function handleSubmit(formData: FormData) {
        "use server";
        const title = formData.get("title") as string;
        await db.insert({ title, createdAt: new Date() });
        revalidatePath("/articles");
    }

    return (
        &lt;form action={handleSubmit}&gt;
            &lt;input name="title" placeholder="文章标题" /&gt;
            &lt;button type="submit"&gt;发布&lt;/button&gt;
        &lt;/form&gt;
    );
}</code></pre>

<p>React 编译器通过静态分析自动识别组件的渲染依赖，在编译时插入细粒度的记忆化代码。在我们的基准测试中，编译器优化后的应用重渲染次数减少了 70%，而开发者无需编写任何优化代码。这意味着 React 终于在开发体验和运行时性能之间找到了平衡。</p>
BODYEOF

    cat > "$BODY_DIR/1.html" << 'BODYEOF'
<p>TypeScript 的类型系统远比大多数人想象的强大。掌握高级类型技巧，可以让你在编译期就捕获更多错误，减少运行时 bug。本文通过一系列递进案例，带你进入类型体操的世界。</p>

<p>条件类型是高级类型的基础：</p>

<pre><code>// 提取 Promise 内部类型
type UnwrapPromise&lt;T&gt; = T extends Promise&lt;infer U&gt; ? U : T;

type Result = UnwrapPromise&lt;Promise&lt;string&gt;&gt;; // string

// 递归解包
type DeepUnwrap&lt;T&gt; = T extends Promise&lt;infer U&gt;
    ? DeepUnwrap&lt;U&gt;
    : T;

type Nested = DeepUnwrap&lt;Promise&lt;Promise&lt;number&gt;&gt;&gt;; // number</code></pre>

<p>模板字面量类型可以生成精确的字符串类型：</p>

<pre><code>// CSS 属性类型
type CSSProperty = keyof React.CSSProperties;

// 事件处理器类型
type EventHandler&lt;T extends string&gt; = `on${Capitalize&lt;T&gt;}`;

type ClickHandler = EventHandler&lt;"click"&gt;; // "onClick"
type ChangeHandler = EventHandler&lt;"change"&gt;; // "onChange"

// 路由参数提取
type ExtractParams&lt;T extends string&gt; =
    T extends `${string}:${infer Param}/${infer Rest}`
        ? { [K in Param | keyof ExtractParams&lt;Rest&gt;]: string }
        : T extends `${string}:${infer Param}`
        ? { [K in Param]: string }
        : {};</code></pre>

<p>映射类型结合条件类型，可以实现强大的类型转换：</p>

<pre><code>// 将所有可选属性变为必需，并添加默认值
type WithDefaults&lt;T, Defaults extends Partial&lt;T&gt;&gt; = {
    [K in keyof T]-?: T[K] | Defaults[K];
};

// 深层 Partial
type DeepPartial&lt;T&gt; = {
    [K in keyof T]?: T[K] extends object ? DeepPartial&lt;T[K]&gt; : T[K];
};</code></pre>

<p>这些技巧在我们的组件库开发中发挥了巨大作用。通过精确的类型定义，我们实现了 100% 的类型覆盖，IDE 自动补全体验大幅提升，组件 API 的误用在编译期就能被发现。</p>
BODYEOF

    cat > "$BODY_DIR/2.html" << 'BODYEOF'
<p>Next.js 的 App Router 基于 React Server Components 构建，它用文件系统路由替代了 Pages Router 的约定式路由，带来了更灵活的布局嵌套和更高效的数据获取方式。</p>

<p>App Router 的核心是布局嵌套：</p>

<pre><code>// app/layout.tsx - 根布局
export default function RootLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        &lt;html lang="zh"&gt;
            &lt;body&gt;
                &lt;nav&gt;{/* 导航栏，跨路由保持状态 */}&lt;/nav&gt;
                {children}
            &lt;/body&gt;
        &lt;/html&gt;
    );
}

// app/blog/layout.tsx - 博客布局
export default function BlogLayout({ children }) {
    return (
        &lt;div className="flex"&gt;
            &lt;aside&gt;{/* 侧边栏 */}&lt;/aside&gt;
            &lt;main&gt;{children}&lt;/main&gt;
        &lt;/div&gt;
    );
}</code></pre>

<p>数据获取从 getServerSideProps 变为直接在组件中 async/await：</p>

<pre><code>// app/blog/page.tsx
async function BlogPage() {
    const posts = await fetch("https://api.example.com/posts", {
        next: { revalidate: 3600 }, // ISR: 每小时重新验证
    }).then(r =&gt; r.json());

    return (
        &lt;section&gt;
            {posts.map(post =&gt; (
                &lt;article key={post.id}&gt;
                    &lt;h2&gt;{post.title}&lt;/h2&gt;
                    &lt;p&gt;{post.excerpt}&lt;/p&gt;
                &lt;/article&gt;
            ))}
        &lt;/section&gt;
    );
}</code></pre>

<p>迁移过程中最大的坑是客户端组件和服务端组件的边界划分。原则是：默认使用 Server Component，只在需要交互（useState、useEffect、事件处理）时才添加 "use client" 指令。我们通过将交互逻辑抽离为叶子组件，成功将客户端 JS 体积减少了 60%。</p>
BODYEOF

    cat > "$BODY_DIR/3.html" << 'BODYEOF'
<p>初遇 Tailwind CSS 时，我和很多人一样抵触——在 className 里写一堆工具类，这和内联样式有什么区别？但随着深入使用，我逐渐理解了它的设计哲学：约束带来一致性，原子类组合出无限可能。</p>

<p>自定义设计系统是 Tailwind 在大型项目中成功的关键：</p>

<pre><code>// tailwind.config.ts
import type { Config } from "tailwindcss";

export default {
    theme: {
        extend: {
            colors: {
                brand: {
                    50: "#eff6ff",
                    500: "#3b82f6",
                    900: "#1e3a8a",
                },
            },
            spacing: {
                18: "4.5rem",
                88: "22rem",
            },
            fontSize: {
                "2xs": ["0.625rem", { lineHeight: "0.875rem" }],
            },
        },
    },
} satisfies Config;</code></pre>

<p>组件封装避免 className 重复：</p>

<pre><code>// Button 组件
const buttonVariants = cva("inline-flex items-center rounded-lg font-medium", {
    variants: {
        intent: {
            primary: "bg-brand-500 text-white hover:bg-brand-600",
            secondary: "bg-gray-100 text-gray-700 hover:bg-gray-200",
            danger: "bg-red-500 text-white hover:bg-red-600",
        },
        size: {
            sm: "px-3 py-1.5 text-sm",
            md: "px-4 py-2 text-base",
            lg: "px-6 py-3 text-lg",
        },
    },
    defaultVariants: {
        intent: "primary",
        size: "md",
    },
});</code></pre>

<p>在性能方面，Tailwind 的 JIT 引擎只生成使用到的工具类，生产构建的 CSS 通常不超过 10KB。配合 Prettier 插件自动排序 className，开发体验已经非常流畅。我们团队从 SASS 迁移到 Tailwind 后，样式代码量减少了 40%，UI 一致性显著提升。</p>
BODYEOF

    cat > "$BODY_DIR/4.html" << 'BODYEOF'
<p>Core Web Vitals 已经成为搜索引擎排名的重要因素，性能优化不再只是锦上添花，而是关乎产品存亡。本文系统梳理三大核心指标的优化策略。</p>

<p>LCP（最大内容绘制）优化：</p>

<pre><code>// Next.js 图片优化
import Image from "next/image";

&lt;Image
    src="/hero.jpg"
    alt="首页横幅"
    width={1200}
    height={600}
    priority  // 预加载，提升 LCP
    placeholder="blur"
/&gt;

// 字体优化 - 避免布局偏移
import { Inter } from "next/font/google";
const inter = Inter({
    subsets: ["latin"],
    display: "swap",  // 字体交换策略
});</code></pre>

<p>CLS（累积布局偏移）优化：</p>

<pre><code>/* 为动态内容预留空间 */
.ad-slot {
    min-height: 250px;
}

/* 图片/视频指定宽高比 */
.responsive-img {
    aspect-ratio: 16 / 9;
    width: 100%;
    height: auto;
}

/* 避免动态注入内容 */
/* 错误：在现有内容上方插入元素 */
/* 正确：使用固定位置或预留空间 */</code></pre>

<p>INP（交互到下一次绘制）优化需要减少主线程阻塞：</p>

<pre><code>// 长任务拆分
function processLargeArray(items) {
    const chunkSize = 50;
    let index = 0;

    function processChunk() {
        const end = Math.min(index + chunkSize, items.length);
        for (let i = index; i &lt; end; i++) {
            processItem(items[i]);
        }
        index = end;
        if (index &lt; items.length) {
            requestIdleCallback(processChunk);
        }
    }
    processChunk();
}</code></pre>

<p>在我们的电商项目中，通过以上优化，LCP 从 4.2s 降到 1.8s，CLS 从 0.35 降到 0.05，INP 从 350ms 降到 120ms。搜索排名提升了 15 位，转化率提高了 12%。</p>
BODYEOF

    cat > "$BODY_DIR/5.html" << 'BODYEOF'
<p>Vite 的成功很大程度上归功于其灵活的插件系统。它兼容 Rollup 插件接口的同时，扩展了 Vite 特有的钩子用于开发服务器的增强。本文从零开发一个 Markdown 导入插件，深入理解插件机制。</p>

<p>插件的基本结构：</p>

<pre><code>import { Plugin } from "vite";

export default function markdownPlugin(): Plugin {
    return {
        name: "vite-plugin-markdown",

        // 解析 Markdown 文件的 import
        async transform(code, id) {
            if (!id.endsWith(".md")) return null;

            const html = await renderMarkdown(code);
            return {
                code: `export default ${JSON.stringify(html)}`,
                map: null,
            };
        },

        // 开发服务器热更新
        handleHotUpdate({ file, server }) {
            if (file.endsWith(".md")) {
                server.ws.send({ type: "full-reload" });
            }
        },
    };
}</code></pre>

<p>虚拟模块是 Vite 插件的强大特性：</p>

<pre><code>export default function virtualRoutesPlugin(): Plugin {
    const virtualId = "virtual:routes";

    return {
        name: "vite-plugin-virtual-routes",
        resolveId(id) {
            if (id === virtualId) return "\0" + virtualId;
        },
        async load(id) {
            if (id !== "\0" + virtualId) return null;

            const pages = await glob("./src/pages/**/*.{tsx,jsx}");
            const imports = pages.map((p, i) =>
                `import Page${i} from "${p}";`
            ).join("\n");

            return `${imports}\nexport const routes = [${pages.map((p, i) =>
                `{ path: "${toRoute(p)}", component: Page${i} }`
            ).join(",")}];`;
        },
    };
}</code></pre>

<p>我们基于这个思路开发了团队的组件文档插件，它可以自动扫描组件目录、提取 Props 类型信息、生成 Storybook 风格的文档页面。配合 HMR，组件开发效率提升了 3 倍。</p>
BODYEOF

    cat > "$BODY_DIR/6.html" << 'BODYEOF'
<p>微前端架构让大型前端应用可以拆分为独立开发、独立部署的子应用。Webpack 5 的 Module Federation 提供了运行时模块共享的能力，是目前最成熟的微前端方案之一。</p>

<p>主机应用配置：</p>

<pre><code>// webpack.config.js (主机应用)
const { ModuleFederationPlugin } = require("webpack").container;

module.exports = {
    plugins: [
        new ModuleFederationPlugin({
            name: "host",
            remotes: {
                catalog: "catalog@http://cdn.example.com/catalog/remoteEntry.js",
                cart: "cart@http://cdn.example.com/cart/remoteEntry.js",
            },
            shared: {
                react: { singleton: true, requiredVersion: "^18.0.0" },
                "react-dom": { singleton: true, requiredVersion: "^18.0.0" },
            },
        }),
    ],
};</code></pre>

<p>远程应用配置：</p>

<pre><code>// webpack.config.js (远程应用 - 商品目录)
module.exports = {
    plugins: [
        new ModuleFederationPlugin({
            name: "catalog",
            filename: "remoteEntry.js",
            exposes: {
                "./ProductList": "./src/components/ProductList",
                "./ProductDetail": "./src/components/ProductDetail",
            },
            shared: {
                react: { singleton: true, eager: false },
                "react-dom": { singleton: true, eager: false },
            },
        }),
    ],
};</code></pre>

<p>在消费远程组件时，使用 React.lazy 实现按需加载：</p>

<pre><code>const ProductList = React.lazy(() =&gt; import("catalog/ProductList"));

function App() {
    return (
        &lt;Suspense fallback={&lt;Loading /&gt;}&gt;
            &lt;ProductList /&gt;
        &lt;/Suspense&gt;
    );
}</code></pre>

<p>踩坑经验：共享依赖版本冲突是最常见的问题，我们通过严格锁定 React 版本和配置 singleton 解决。另外，远程组件的类型安全需要通过 TypeScript 的 path mapping 和类型包发布来保障。</p>
BODYEOF

    cat > "$BODY_DIR/7.html" << 'BODYEOF'
<p>容器查询（Container Queries）是 CSS 近年来最重要的新特性之一。与媒体查询基于视口不同，容器查询让组件可以根据自身容器的大小响应式调整，真正实现了组件级别的响应式设计。</p>

<p>定义容器上下文：</p>

<pre><code>/* 父容器声明为容器 */
.card-wrapper {
    container-type: inline-size;
    container-name: card;
}

/* 基于容器宽度调整布局 */
@container card (min-width: 400px) {
    .card {
        display: grid;
        grid-template-columns: 200px 1fr;
        gap: 1rem;
    }
}

@container card (min-width: 600px) {
    .card {
        grid-template-columns: 250px 1fr 200px;
    }
}

/* 小容器：垂直堆叠 */
@container card (max-width: 399px) {
    .card {
        display: flex;
        flex-direction: column;
    }
}</code></pre>

<p>容器查询单位让尺寸随容器缩放：</p>

<pre><code>.card-title {
    font-size: clamp(1rem, 3cqi, 1.5rem);
    /* cqi = 容器内联尺寸的 1% */
}

.card-image {
    width: 100%;
    aspect-ratio: 16 / 9;
    object-fit: cover;
    border-radius: 0.5cqi;
}</code></pre>

<p>容器查询与媒体查询的配合使用是最佳实践。媒体查询处理页面级布局（如侧边栏显隐），容器查询处理组件级布局（如卡片内部排列）。在我们的设计系统中，容器查询让组件真正变成了"自适应积木"，无论放在什么容器中都能优雅展示，复用率提升了 3 倍。</p>
BODYEOF

    FRIENDS=(
        "React中文社区|https://ruanyifeng.com|阮一峰的网络日志|https://picsum.photos/seed/ruanyifeng-friend/60/60"
        "CSS魔法|https://css-tricks.com|CSS技巧与教程|https://picsum.photos/seed/css-tricks-friend/60/60"
        "前端早读课|https://smashingmagazine.com|前端设计与开发|https://picsum.photos/seed/smashing-friend/60/60"
        "TypeScript修炼|https://dev.to|开发者社区|https://picsum.photos/seed/devto-friend/60/60"
    )

# 模板4: Rust/系统编程/嵌入式 - 暗色主题
elif [ "$TEMPLATE_NUM" -eq 4 ]; then
    BLOG_NAME="底层探索"
    BLOGGER_NAME="赵瀚文"
    BLOGGER_BIO="系统程序员，Rust 布道者。痴迷于底层实现细节，相信对硬件的理解是写出高效软件的前提。"
    BLOGGER_SKILLS="Rust, C, 汇编, Linux内核, 嵌入式, WebAssembly"
    BLOGGER_EMAIL="zhaohanwen@outlook.com"
    BLOGGER_GITHUB="https://github.com/zhaohanwen"
    PRIMARY_COLOR="#f97316"
    PRIMARY_LIGHT="#fb923c"
    PRIMARY_DARK="#ea580c"
    BG_COLOR="#0f172a"
    CARD_BG="#1e293b"
    TEXT_COLOR="#e2e8f0"
    TEXT_SECONDARY="#94a3b8"
    CODE_BG="#0c0a09"
    CODE_TEXT="#fde68a"
    ACCENT="#fb923c"
    NAV_BG="#0c0a09"
    NAV_TEXT="#fdba74"

    CATEGORIES=("Rust" "系统编程" "嵌入式" "Linux内核" "WebAssembly" "性能优化")
    TAGS=("Rust" "内存安全" "零成本抽象" "嵌入式" "ARM" "RISC-V" "Linux" "内核" "eBPF" "WebAssembly" "WASM" "并发" "async" "FFI" "C互操作" "性能" "SIMD" "汇编" "驱动开发" "RTOS")

    ARTICLES=(
        "Rust 异步运行时：从 Future 到 Tokio 的实现原理|Rust 的 async/await 语法糖背后是一套精巧的状态机转换机制。本文深入剖析 Future trait、Pin 机制和 Waker 唤醒链路，理解 Tokio 运行时的调度策略。|Rust|Rust async Future Tokio 运行时|2025-12-12"
        "用 Rust 编写 Linux 内核模块|Linux 6.1 正式引入 Rust 支持，开启了内核开发的新纪元。本文手把手教你用 Rust 编写一个可加载的内核模块，包括内核 API 绑定和安全抽象。|Linux内核|Rust Linux 内核模块 驱动|2025-11-26"
        "嵌入式 Rust：从零搭建 no_std 环境|在资源受限的微控制器上运行 Rust，需要理解 no_std 生态和底层配置。本文以 STM32 为例，从工具链搭建到外设驱动开发，完整走一遍嵌入式 Rust 开发流程。|嵌入式|Rust 嵌入式 no_std STM32|2025-11-08"
        "Rust 与 C 的互操作：FFI 实战指南|在系统编程中，Rust 与 C 的互操作是不可避免的。本文详解 FFI 的安全封装模式，包括内存所有权传递、回调函数和复杂数据结构的跨语言边界处理。|系统编程|Rust FFI C互操作 内存安全|2025-10-21"
        "WebAssembly 与 Rust：高性能 Web 运行时|WebAssembly 让 Rust 代码可以在浏览器中接近原生速度运行。本文分享用 Rust 开发 WASM 模块的经验，包括 wasm-bindgen、wasm-pack 和性能调优。|WebAssembly|Rust WebAssembly wasm-bindgen 性能|2025-10-04"
        "深入 Rust 内存模型：从栈帧到堆分配|理解 Rust 的内存模型是写出高效代码的基础。本文从汇编层面分析栈帧布局、堆分配策略和自定义分配器的实现。|Rust|Rust 内存模型 栈帧 分配器|2025-09-16"
        "eBPF 网络可观测性：用 Rust 编写高性能探针|eBPF 正在改变内核可观测性的方式。本文使用 Aya 框架用 Rust 编写 eBPF 程序，实现网络包过滤和延迟分析。|Linux内核|eBPF Rust Aya 网络可观测性|2025-08-29"
        "Rust SIMD 编程：从手动向量化到便携式抽象|SIMD 指令可以大幅提升数据并行计算的吞吐量。本文从手写 intrinsics 到使用 std::simd，探索 Rust 中不同层次的 SIMD 编程方法。|性能优化|Rust SIMD 向量化 性能|2025-08-11"
    )

    ARTICLE_SLUGS=(
        "rust-async-runtime-tokio"
        "rust-linux-kernel-module"
        "rust-embedded-nostd-stm32"
        "rust-ffi-c-interop-guide"
        "rust-webassembly-performance"
        "rust-memory-model-deep-dive"
        "ebpf-rust-network-observability"
        "rust-simd-vectorization"
    )

    cat > "$BODY_DIR/0.html" << 'BODYEOF'
<p>Rust 的 async/await 是零成本抽象的典范——编译器将 async 函数转换为状态机，避免了运行时的协程开销。但这种转换背后的机制并不简单，理解它对编写高效的异步代码至关重要。</p>

<p>Future trait 是异步计算的核心抽象：</p>

<pre><code>pub trait Future {
    type Output;
    fn poll(self: Pin&lt;&amp;mut Self&gt;, cx: &amp;mut Context&lt;'_&gt;) -&gt; Poll&lt;Self::Output&gt;;
}

pub enum Poll&lt;T&gt; {
    Ready(T),
    Pending,
}</code></pre>

<p>async 函数被编译为状态机，每次 poll 推进状态：</p>

<pre><code>async fn fetch_data(url: &amp;str) -&gt; Vec&lt;u8&gt; {
    let response = http_get(url).await;  // 状态1: 等待HTTP响应
    let body = response.read_body().await;  // 状态2: 等待body读取
    body  // 状态3: 完成
}

// 等价的状态机（简化版）
enum FetchDataFuture {
    State1 { url: String },
    State2 { response: HttpResponse },
    Done,
}</code></pre>

<p>Pin 机制确保自引用结构的安全：</p>

<pre><code>// 自引用 Future 需要 Pin 保证不被移动
let future = async {
    let data = vec![1, 2, 3];
    let reference = &amp;data;  // 引用栈上数据
    some_async_op(reference).await;
};

// Pin 确保 future 不会被移动，引用始终有效
let mut pinned = Box::pin(future);
pinned.as_mut().poll(&amp;mut cx);</code></pre>

<p>Tokio 的调度器采用 work-stealing 策略，每个工作线程维护一个本地队列，当本地队列为空时从其他线程"窃取"任务。这种设计在多核场景下实现了良好的负载均衡。在我们的网络服务中，Tokio 的多线程调度器比单线程调度器吞吐量提升了 4 倍。</p>
BODYEOF

    cat > "$BODY_DIR/1.html" << 'BODYEOF'
<p>Linux 6.1 合并了初始的 Rust 支持，这是内核开发史上的里程碑事件。Rust 的内存安全保证可以在编译期消除整类 bug，这对内核这种对安全性要求极高的代码尤为重要。</p>

<p>一个最简的 Rust 内核模块：</p>

<pre><code>// SPDX-License-Identifier: GPL-2.0

//! Rust 内核模块示例

use kernel::prelude::*;

module! {
    type: HelloRust,
    name: "hello_rust",
    author: "赵瀚文",
    description: "Rust 内核模块示例",
    license: "GPL",
}

struct HelloRust;

impl kernel::Module for HelloRust {
    fn init(_name: &amp;str) -&gt; Result&lt;Self&gt; {
        pr_info!("Hello from Rust kernel module!");
        Ok(HelloRust)
    }
}

impl Drop for HelloRust {
    fn drop(&amp;mut self) {
        pr_info!("Goodbye from Rust kernel module!");
    }
}</code></pre>

<p>安全地封装内核 API 是 Rust 内核开发的核心挑战：</p>

<pre><code>use kernel::{
    file::File,
    io_buffer::IoBufferWriter,
    miscdev::Registration,
    sync::smutex::Mutex,
    sync::Ref,
};

struct Device {
    registration: Registration&lt;Device&gt;,
    data: Mutex&lt;Vec&lt;u8&gt;&gt;,
}

impl kernel::file::Operations for Device {
    fn write(
        this: &amp;Self,
        _file: &amp;File,
        reader: &amp;mut impl IoBufferReader,
        _offset: u64,
    ) -&gt; Result&lt;usize&gt; {
        let mut data = this.data.lock();
        let len = reader.read_all(&amp;mut *data, 0)?;
        Ok(len)
    }
}</code></pre>

<p>目前 Rust 内核支持还处于早期阶段，可用的子系统绑定有限。但网络驱动和文件系统已经可以用 Rust 实现。社区正在积极推进更多子系统的 Rust 绑定，预计在 Linux 7.x 时代，Rust 将成为内核开发的主流选择之一。</p>
BODYEOF

    cat > "$BODY_DIR/2.html" << 'BODYEOF'
<p>嵌入式开发长期被 C 语言主导，但 Rust 的零成本抽象和内存安全保证，使其成为嵌入式开发的有力竞争者。本文以 STM32F4 为目标平台，从零搭建嵌入式 Rust 开发环境。</p>

<p>项目初始化和配置：</p>

<pre><code># 安装交叉编译目标和工具
rustup target add thumbv7em-none-eabihf
cargo install cargo-flash probe-rs

# Cargo.toml
[package]
name = "stm32-blink"
edition = "2021"

[dependencies]
cortex-m = "0.7"
cortex-m-rt = "0.7"
stm32f4xx-hal = { version = "0.20", features = ["stm32f407"] }
panic-halt = "0.2"</code></pre>

<p>LED 闪烁程序：</p>

<pre><code>#![no_std]
#![no_main]

use cortex_m_rt::entry;
use stm32f4xx_hal::{pac, prelude::*};

#[entry]
fn main() -&gt; ! {
    let dp = pac::Peripherals::take().unwrap();
    let gpioa = dp.GPIOA.split();
    let mut led = gpioa.pa5.into_push_pull_output();

    let rcc = dp.RCC.constrain();
    let clocks = rcc.cfgr.sysclk(48.MHz()).freeze();

    let mut delay = dp.TIM1.delay_us(&amp;clocks);

    loop {
        led.set_high();
        delay.delay_ms(500_u32);
        led.set_low();
        delay.delay_ms(500_u32);
    }
}</code></pre>

<p>嵌入式 Rust 的生态正在快速发展。对于中断处理，我们使用 <code>cortex-m-rt</code> 的 <code>#[interrupt]</code> 宏；对于异步操作，<code>embassy</code> 框架提供了基于 executors 的异步运行时，可以在极低内存占用下实现高效的并发。在我们的项目中，使用 Embassy 后，同样的功能代码量减少了 40%，RAM 占用从 32KB 降到了 18KB。</p>
BODYEOF

    cat > "$BODY_DIR/3.html" << 'BODYEOF'
<p>在系统编程领域，Rust 很少能完全避开与 C 代码的交互。无论是调用系统库、集成遗留代码，还是为 C 项目提供 Rust 实现，FFI（Foreign Function Interface）都是必须掌握的技能。</p>

<p>基础 FFI 调用：</p>

<pre><code>use std::os::raw::c_int;

extern "C" {
    fn abs(input: c_int) -&gt; c_int;
}

fn rust_abs(x: i32) -&gt; i32 {
    unsafe { abs(x) }
}</code></pre>

<p>安全封装是 FFI 的核心原则：</p>

<pre><code>use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// C 库接口
extern "C" {
    fn process_string(input: *const c_char) -&gt; *mut c_char;
    fn free_string(s: *mut c_char);
}

// 安全的 Rust 封装
fn safe_process_string(input: &amp;str) -&gt; Result&lt;String, std::ffi::NulError&gt; {
    let c_input = CString::new(input)?;
    let result = unsafe {
        let ptr = process_string(c_input.as_ptr());
        if ptr.is_null() {
            return Ok(String::new());
        }
        let c_str = CStr::from_ptr(ptr);
        let output = c_str.to_string_lossy().into_owned();
        free_string(ptr);  // 释放 C 分配的内存
        output
    };
    Ok(result)
}</code></pre>

<p>回调函数的跨语言传递需要特别小心：</p>

<pre><code>type Callback = extern "C" fn(i32) -&gt; i32;

extern "C" {
    fn register_callback(cb: Callback);
}

extern "C" fn my_callback(x: i32) -&gt; i32 {
    x * 2
}

fn main() {
    unsafe { register_callback(my_callback); }
}</code></pre>

<p>关键原则：在 unsafe 块的边界处建立安全不变量，让调用者无需关心底层的 C 代码。我们用这个模式封装了 50+ 个 C 库函数，上层 Rust 代码完全不包含 unsafe。</p>
BODYEOF

    cat > "$BODY_DIR/4.html" << 'BODYEOF'
<p>WebAssembly 为 Rust 打开了浏览器的大门。Rust 编译到 WASM 后，可以在浏览器中以接近原生的速度运行，这为计算密集型 Web 应用带来了全新的可能。</p>

<p>使用 wasm-bindgen 桥接 Rust 和 JavaScript：</p>

<pre><code>use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct Fibonacci {
    values: Vec&lt;u64&gt;,
}

#[wasm_bindgen]
impl Fibonacci {
    #[wasm_bindgen(constructor)]
    pub fn new() -&gt; Self {
        Fibonacci { values: vec![0, 1] }
    }

    pub fn compute(&amp;mut self, n: usize) -&gt; u64 {
        if n &lt; self.values.len() {
            return self.values[n];
        }
        while self.values.len() &lt;= n {
            let next = self.values[self.values.len() - 1]
                .wrapping_add(self.values[self.values.len() - 2]);
            self.values.push(next);
        }
        self.values[n]
    }
}</code></pre>

<p>与 DOM 交互：</p>

<pre><code>use wasm_bindgen::prelude::*;
use web_sys::{Document, HtmlElement};

#[wasm_bindgen(start)]
pub fn run() -&gt; Result&lt;(), JsValue&gt; {
    let document: Document = window().document().unwrap();
    let body = document.body().unwrap();

    let p: HtmlElement = document.create_element("p")?.unchecked_into();
    p.set_text_content(Some("Hello from Rust WASM!"));
    body.append_child(&amp;p)?;

    Ok(())
}</code></pre>

<p>性能调优方面，有几个关键技巧：使用 <code>wasm-opt</code> 进行二进制优化、启用 LTO 减少体积、避免频繁的 JS-WASM 边界跨越。在我们的图像处理应用中，Rust WASM 模块比纯 JavaScript 实现快 15 倍，wasm 体积仅 28KB。</p>
BODYEOF

    cat > "$BODY_DIR/5.html" << 'BODYEOF'
<p>Rust 的所有权系统在语言层面保证了内存安全，但理解底层的内存布局对于编写高性能代码同样重要。本文从汇编层面深入分析 Rust 的内存模型。</p>

<p>栈帧布局分析：</p>

<pre><code>struct Point {
    x: f64,
    y: f64,
}

fn process(p: Point) -&gt; f64 {
    p.x * p.x + p.y * p.y
}

// 编译后的汇编（x86_64）
// process:
//     movsd   xmm2, xmm0     ; x
//     mulsd   xmm2, xmm0     ; x * x
//     movsd   xmm3, xmm1     ; y
//     mulsd   xmm3, xmm1     ; y * y
//     addsd   xmm2, xmm3     ; x*x + y*y
//     movapd  xmm0, xmm2     ; 返回值
//     ret</code></pre>

<p>自定义全局分配器：</p>

<pre><code>use std::alloc::{GlobalAlloc, Layout, System};

struct TrackingAllocator;

unsafe impl GlobalAlloc for TrackingAllocator {
    unsafe fn alloc(&amp;self, layout: Layout) -&gt; *mut u8 {
        let ptr = System.alloc(layout);
        if !ptr.is_null() {
            // 记录分配信息
            ALLOC_TRACKER.track(layout.size(), ptr);
        }
        ptr
    }

    unsafe fn dealloc(&amp;self, ptr: *mut u8, layout: Layout) {
        ALLOC_TRACKER.untrack(ptr);
        System.dealloc(ptr, layout);
    }
}

#[global_allocator]
static GLOBAL: TrackingAllocator = TrackingAllocator;</code></pre>

<p>Rust 的枚举在内存中的表示也值得深入研究。Option&lt;Box&lt;T&gt;&gt; 利用空指针优化，与裸指针占用相同的内存。而普通的 Option&lt;&amp;T&gt; 同样利用引用的非空保证实现了零开销的 None 表示。理解这些底层细节，可以帮助你在性能敏感场景做出更好的数据结构选择。</p>
BODYEOF

    cat > "$BODY_DIR/6.html" << 'BODYEOF'
<p>eBPF（extended Berkeley Packet Filter）允许在内核中安全地运行沙箱程序，而无需修改内核源码或加载模块。结合 Rust 的安全性保证，eBPF 程序开发变得更加可靠。</p>

<p>使用 Aya 框架编写 eBPF 程序：</p>

<pre><code>#![no_std]
#![no_main]

use aya_bpf::{
    bindings::TC_ACT_OK,
    programs::TcContext,
    macros::classifier,
};

#[classifier]
pub fn tc_egress(ctx: TcContext) -&gt; i32 {
    // 解析以太网头
    let eth_proto = ctx.load::&lt;u16&gt;(12).unwrap_or(0);
    if eth_proto != 0x0800 {
        return TC_ACT_OK; // 非IPv4，放行
    }

    // 解析IP头
    let ip_proto = ctx.load::&lt;u8&gt;(23).unwrap_or(0);
    if ip_proto != 6 {
        return TC_ACT_OK; // 非TCP，放行
    }

    // 记录TCP流量
    let src_port = ctx.load::&lt;u16&gt;(34).unwrap_or(0);
    let dst_port = ctx.load::&lt;u16&gt;(36).unwrap_or(0);

    unsafe {
        TCP_COUNTER.increment(1);
    }

    TC_ACT_OK
}</code></pre>

<p>用户空间程序加载和附加 eBPF 程序：</p>

<pre><code>use aya::{Bpf, programs::TcAttachType};

#[tokio::main]
async fn main() -&gt; Result&lt;(), anyhow::Error&gt; {
    // 加载编译好的 eBPF 字节码
    let mut bpf = Bpf::load(include_bytes_aligned!(
        "../target/bpfel-unknown-none/release/ebpf-prog"
    ))?;

    // 附加到网络接口
    let program = bpf.program_mut("tc_egress")
        .ok_or_else(|| anyhow!("program not found"))?;
    program.load()?;

    let link = program.attach("eth0", TcAttachType::Egress)?;

    // 读取计数器
    loop {
        let count = unsafe { TCP_COUNTER.get(0) };
        println!("TCP packets: {}", count);
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}</code></pre>

<p>Aya 的优势在于 eBPF 程序和用户空间程序都用 Rust 编写，共享类型定义，避免了 C 版本中常见的头文件同步问题。在我们的生产环境中，这套 eBPF 探针每秒处理 100 万个包，CPU 开销不到 2%。</p>
BODYEOF

    cat > "$BODY_DIR/7.html" << 'BODYEOF'
<p>SIMD（Single Instruction Multiple Data）指令可以一条指令同时处理多个数据，是数据并行计算的核心加速手段。Rust 提供了从底层 intrinsics 到高层便携抽象的多种 SIMD 编程方式。</p>

<p>使用 std::simd（便携式 SIMD）：</p>

<pre><code>#![feature(portable_simd)]
use std::simd::f64x4;

fn sum_arrays(a: &amp;[f64], b: &amp;[f64], c: &amp;mut [f64]) {
    for ((a_chunk, b_chunk), c_chunk) in a.chunks(4)
        .zip(b.chunks(4))
        .zip(c.chunks_mut(4))
    {
        let va = f64x4::from_slice(a_chunk);
        let vb = f64x4::from_slice(b_chunk);
        let result = va + vb;
        result.copy_to_slice(c_chunk);
    }
}</code></pre>

<p>手动 intrinsics 实现更精细的控制：</p>

<pre><code>#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

#[target_feature(enable = "avx2")]
unsafe fn dot_product_avx2(a: &amp;[f32], b: &amp;[f32]) -&gt; f32 {
    let mut sum = _mm256_setzero_ps();
    for i in (0..a.len()).step_by(8) {
        let va = _mm256_loadu_ps(a.as_ptr().add(i));
        let vb = _mm256_loadu_ps(b.as_ptr().add(i));
        sum = _mm256_fmadd_ps(va, vb, sum);
    }

    // 水平求和
    let hi = _mm256_extractf128_ps(sum, 1);
    let lo = _mm256_castps256_ps128(sum);
    let sum128 = _mm_add_ps(hi, lo);
    let shuf = _mm_movehl_ps(sum128, sum128);
    let sums = _mm_add_ss(sum128, shuf);
    _mm_cvtss_f32(sums)
}</code></pre>

<p>性能对比结果令人振奋：在向量点积基准测试中，标量版本 120ms，便携式 SIMD 版本 32ms（3.75x 加速），手动 AVX2 版本 28ms（4.3x 加速）。便携式 SIMD 已经接近手写 intrinsics 的性能，同时代码可移植到 ARM NEON 等平台。在我们的图像处理管线中，SIMD 优化让关键热点的吞吐量提升了 4 倍。</p>
BODYEOF

    FRIENDS=(
        "Rust语言中文社区|https://rust-lang.org|Rust编程语言官网|https://picsum.photos/seed/rustlang-friend/60/60"
        "Linux内核探秘|https://tokio.rs|Tokio异步运行时|https://picsum.photos/seed/tokio-friend/60/60"
        "嵌入式杂谈|https://golang.google.cn|Go语言中文站|https://picsum.photos/seed/golang-cn-friend/60/60"
        "系统编程志|https://hackernews.ycombinator.com|Hacker News|https://picsum.photos/seed/hackernews-friend/60/60"
    )
fi

# ============================================================
# 辅助函数
# ============================================================

# 生成导航栏（参数：当前页面标识）
generate_nav() {
    local current="$1"
    cat << NAV_EOF
    <nav class="main-nav">
        <div class="nav-container">
            <a href="index.html" class="nav-brand">${BLOG_NAME}</a>
            <button class="nav-toggle" aria-label="菜单" onclick="document.querySelector('.nav-links').classList.toggle('active')">
                <span></span><span></span><span></span>
            </button>
            <div class="nav-links">
NAV_EOF

    local items="首页|index.html 归档|archives.html 分类|categories.html 标签|tags.html 友链|friends.html 关于|about.html"
    for item in $items; do
        local label="${item%%|*}"
        local href="${item##*|}"
        if [ "$label" = "$current" ]; then
            echo "                <a href=\"${href}\" class=\"nav-link active\">${label}</a>"
        else
            echo "                <a href=\"${href}\" class=\"nav-link\">${label}</a>"
        fi
    done

    cat << NAV_EOF
            </div>
        </div>
    </nav>
NAV_EOF
}

# 生成页脚
generate_footer() {
    local year=$(date +%Y)
    cat << FOOTER_EOF
    <footer class="site-footer">
        <div class="container">
            <p>&copy; ${year} ${BLOG_NAME} | 由 ${BLOGGER_NAME} 用 &#x2764;&#xFE0F; 构建</p>
        </div>
    </footer>
FOOTER_EOF
}

# 生成 CSS
generate_css() {
    cat << 'CSS_EOF'
/* ===== 基础重置 ===== */
*, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    --primary: PRIMARY_COLOR_PLACEHOLDER;
    --primary-light: PRIMARY_LIGHT_PLACEHOLDER;
    --primary-dark: PRIMARY_DARK_PLACEHOLDER;
    --bg: BG_COLOR_PLACEHOLDER;
    --card-bg: CARD_BG_PLACEHOLDER;
    --text: TEXT_COLOR_PLACEHOLDER;
    --text-secondary: TEXT_SECONDARY_PLACEHOLDER;
    --code-bg: CODE_BG_PLACEHOLDER;
    --code-text: CODE_TEXT_PLACEHOLDER;
    --accent: ACCENT_PLACEHOLDER;
    --nav-bg: NAV_BG_PLACEHOLDER;
    --nav-text: NAV_TEXT_PLACEHOLDER;
    --radius: 8px;
    --shadow: 0 2px 8px rgba(0,0,0,0.08);
    --shadow-hover: 0 8px 24px rgba(0,0,0,0.15);
}

html {
    scroll-behavior: smooth;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans SC", sans-serif;
    font-size: 16px;
    line-height: 1.8;
    color: var(--text);
    background: var(--bg);
    min-height: 100vh;
    display: flex;
    flex-direction: column;
}

a {
    color: var(--primary);
    text-decoration: none;
    transition: color 0.2s;
}

a:hover {
    color: var(--primary-dark);
}

img {
    max-width: 100%;
    height: auto;
}

/* ===== 容器 ===== */
.container {
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 20px;
}

/* ===== 导航栏 ===== */
.main-nav {
    background: var(--nav-bg);
    position: sticky;
    top: 0;
    z-index: 100;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.nav-container {
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 60px;
}

.nav-brand {
    font-size: 1.3rem;
    font-weight: 700;
    color: #fff !important;
    letter-spacing: 0.5px;
}

.nav-links {
    display: flex;
    gap: 8px;
}

.nav-link {
    color: var(--nav-text);
    padding: 8px 16px;
    border-radius: 6px;
    font-size: 0.95rem;
    transition: background 0.2s, color 0.2s;
}

.nav-link:hover {
    background: rgba(255,255,255,0.1);
    color: #fff;
}

.nav-link.active {
    background: var(--primary);
    color: #fff;
}

.nav-toggle {
    display: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: 8px;
}

.nav-toggle span {
    display: block;
    width: 24px;
    height: 2px;
    background: #fff;
    margin: 5px 0;
    transition: 0.3s;
}

/* ===== 主内容区 ===== */
.main-content {
    flex: 1;
    padding: 40px 0;
}

/* ===== 页面标题 ===== */
.page-header {
    text-align: center;
    margin-bottom: 40px;
}

.page-header h1 {
    font-size: 2rem;
    color: var(--text);
    margin-bottom: 8px;
}

.page-header p {
    color: var(--text-secondary);
    font-size: 1.1rem;
}

/* ===== 文章卡片 ===== */
.article-card {
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    overflow: hidden;
    margin-bottom: 24px;
    transition: box-shadow 0.3s, transform 0.3s;
}

.article-card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-2px);
}

.article-card-image {
    width: 100%;
    height: 200px;
    object-fit: cover;
}

.img-fallback .article-card-image {
    display: none;
}

.article-card.img-fallback {
    background: linear-gradient(135deg, var(--primary-light), var(--accent));
    min-height: 200px;
}

.article-card-body {
    padding: 24px;
}

.article-card-body h2 {
    font-size: 1.3rem;
    margin-bottom: 8px;
}

.article-card-body h2 a {
    color: var(--text);
}

.article-card-body h2 a:hover {
    color: var(--primary);
}

.article-meta {
    display: flex;
    gap: 16px;
    color: var(--text-secondary);
    font-size: 0.85rem;
    margin-bottom: 12px;
}

.article-excerpt {
    color: var(--text-secondary);
    line-height: 1.7;
    margin-bottom: 12px;
}

.article-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
}

.tag {
    display: inline-block;
    padding: 2px 10px;
    background: var(--primary-light);
    color: #fff;
    border-radius: 12px;
    font-size: 0.75rem;
    transition: background 0.2s;
}

.tag:hover {
    background: var(--primary-dark);
    color: #fff;
}

/* ===== 文章正文 ===== */
.post-content {
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 40px;
    line-height: 1.8;
    font-size: 16px;
}

.post-content p {
    margin-bottom: 1.2em;
}

.post-content h2 {
    font-size: 1.5rem;
    margin: 2em 0 1em;
    padding-bottom: 0.3em;
    border-bottom: 2px solid var(--primary-light);
}

.post-content h3 {
    font-size: 1.25rem;
    margin: 1.5em 0 0.8em;
}

.post-content pre {
    background: var(--code-bg);
    color: var(--code-text);
    border-radius: var(--radius);
    padding: 20px;
    overflow-x: auto;
    margin: 1.5em 0;
    font-size: 0.9rem;
    line-height: 1.6;
}

.post-content code {
    font-family: "Fira Code", "JetBrains Mono", "Source Code Pro", Consolas, monospace;
}

.post-content :not(pre) > code {
    background: var(--primary-light);
    color: #fff;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 0.88em;
}

.post-content img {
    border-radius: var(--radius);
    margin: 1.5em 0;
    box-shadow: var(--shadow);
}

.post-content blockquote {
    border-left: 4px solid var(--primary);
    padding: 12px 20px;
    margin: 1.5em 0;
    background: var(--bg);
    border-radius: 0 var(--radius) var(--radius) 0;
    color: var(--text-secondary);
}

.post-content ul, .post-content ol {
    margin: 1em 0;
    padding-left: 2em;
}

.post-content li {
    margin-bottom: 0.5em;
}

/* ===== 文章导航（上下篇） ===== */
.post-nav {
    display: flex;
    justify-content: space-between;
    gap: 20px;
    margin-top: 40px;
    padding-top: 20px;
    border-top: 1px solid rgba(128,128,128,0.2);
}

.post-nav-item {
    flex: 1;
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 16px 20px;
    transition: box-shadow 0.3s;
}

.post-nav-item:hover {
    box-shadow: var(--shadow-hover);
}

.post-nav-item.next {
    text-align: right;
}

.post-nav-label {
    font-size: 0.8rem;
    color: var(--text-secondary);
    margin-bottom: 4px;
}

.post-nav-title {
    font-weight: 600;
    color: var(--primary);
}

/* ===== 归档时间线 ===== */
.timeline {
    position: relative;
    padding-left: 30px;
}

.timeline::before {
    content: "";
    position: absolute;
    left: 8px;
    top: 0;
    bottom: 0;
    width: 3px;
    background: var(--primary-light);
    border-radius: 2px;
}

.timeline-year {
    font-size: 1.4rem;
    font-weight: 700;
    color: var(--primary);
    margin: 30px 0 16px;
    position: relative;
}

.timeline-year::before {
    content: "";
    position: absolute;
    left: -26px;
    top: 8px;
    width: 12px;
    height: 12px;
    background: var(--primary);
    border-radius: 50%;
    border: 3px solid var(--bg);
}

.timeline-month {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--text);
    margin: 20px 0 10px;
}

.timeline-item {
    padding: 8px 0 8px 16px;
    border-left: 2px solid transparent;
    transition: border-color 0.2s;
}

.timeline-item:hover {
    border-left-color: var(--primary-light);
}

.timeline-item a {
    color: var(--text);
    font-size: 1rem;
}

.timeline-item a:hover {
    color: var(--primary);
}

.timeline-date {
    color: var(--text-secondary);
    font-size: 0.85rem;
    margin-right: 12px;
}

/* ===== 分类网格 ===== */
.category-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 20px;
}

.category-card {
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 24px;
    transition: box-shadow 0.3s, transform 0.3s;
    border-top: 4px solid var(--primary);
}

.category-card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-2px);
}

.category-card h3 {
    font-size: 1.2rem;
    margin-bottom: 8px;
}

.category-card h3 a {
    color: var(--text);
}

.category-card h3 a:hover {
    color: var(--primary);
}

.category-count {
    color: var(--text-secondary);
    font-size: 0.9rem;
}

.category-articles {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid rgba(128,128,128,0.15);
    list-style: none;
}

.category-articles li {
    padding: 4px 0;
    font-size: 0.9rem;
}

.category-articles li a {
    color: var(--text-secondary);
}

.category-articles li a:hover {
    color: var(--primary);
}

/* ===== 标签云 ===== */
.tag-cloud {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    justify-content: center;
    padding: 20px;
}

.tag-cloud .tag-item {
    display: inline-block;
    padding: 6px 16px;
    background: var(--card-bg);
    border-radius: 20px;
    box-shadow: var(--shadow);
    color: var(--text);
    transition: all 0.3s;
}

.tag-cloud .tag-item:hover {
    background: var(--primary);
    color: #fff;
    transform: scale(1.05);
}

/* ===== 友链卡片 ===== */
.friend-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
}

.friend-card {
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 24px;
    display: flex;
    gap: 16px;
    align-items: center;
    transition: box-shadow 0.3s, transform 0.3s;
}

.friend-card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-2px);
}

.friend-avatar {
    width: 60px;
    height: 60px;
    border-radius: 50%;
    object-fit: cover;
    flex-shrink: 0;
}

.friend-info h3 {
    font-size: 1.05rem;
    margin-bottom: 4px;
}

.friend-info h3 a {
    color: var(--text);
}

.friend-info h3 a:hover {
    color: var(--primary);
}

.friend-info p {
    color: var(--text-secondary);
    font-size: 0.85rem;
    line-height: 1.5;
}

/* ===== 关于页面 ===== */
.about-card {
    background: var(--card-bg);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 40px;
    max-width: 700px;
    margin: 0 auto;
}

.about-avatar {
    width: 120px;
    height: 120px;
    border-radius: 50%;
    object-fit: cover;
    display: block;
    margin: 0 auto 20px;
    border: 4px solid var(--primary-light);
}

.about-name {
    text-align: center;
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: 8px;
}

.about-bio {
    text-align: center;
    color: var(--text-secondary);
    margin-bottom: 24px;
    line-height: 1.7;
}

.about-section {
    margin-bottom: 24px;
}

.about-section h3 {
    font-size: 1.1rem;
    color: var(--primary);
    margin-bottom: 10px;
    padding-bottom: 6px;
    border-bottom: 2px solid var(--primary-light);
}

.skill-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
}

.skill-tag {
    padding: 4px 14px;
    background: var(--primary-light);
    color: #fff;
    border-radius: 16px;
    font-size: 0.85rem;
}

.contact-list {
    list-style: none;
}

.contact-list li {
    padding: 8px 0;
    display: flex;
    align-items: center;
    gap: 10px;
}

.contact-list li::before {
    content: "\2192";
    color: var(--primary);
    font-weight: bold;
}

/* ===== 404 页面 ===== */
.not-found {
    text-align: center;
    padding: 80px 20px;
}

.not-found h1 {
    font-size: 6rem;
    color: var(--primary);
    margin-bottom: 16px;
}

.not-found p {
    color: var(--text-secondary);
    font-size: 1.2rem;
    margin-bottom: 24px;
}

.not-found a {
    display: inline-block;
    padding: 12px 32px;
    background: var(--primary);
    color: #fff;
    border-radius: var(--radius);
    font-size: 1rem;
    transition: background 0.2s;
}

.not-found a:hover {
    background: var(--primary-dark);
    color: #fff;
}

/* ===== 页脚 ===== */
.site-footer {
    background: var(--nav-bg);
    color: var(--nav-text);
    text-align: center;
    padding: 20px;
    margin-top: auto;
}

.site-footer p {
    font-size: 0.9rem;
    opacity: 0.9;
}

/* ===== 分页 ===== */
.pagination {
    display: flex;
    justify-content: center;
    gap: 8px;
    margin-top: 32px;
}

.pagination a, .pagination span {
    display: inline-block;
    padding: 8px 16px;
    border-radius: var(--radius);
    font-size: 0.9rem;
}

.pagination a {
    background: var(--card-bg);
    box-shadow: var(--shadow);
    color: var(--text);
}

.pagination a:hover {
    background: var(--primary);
    color: #fff;
}

.pagination .current {
    background: var(--primary);
    color: #fff;
}

/* ===== 回到顶部 ===== */
.back-to-top {
    position: fixed;
    bottom: 30px;
    right: 30px;
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: var(--primary);
    color: #fff;
    border: none;
    font-size: 1.2rem;
    cursor: pointer;
    box-shadow: var(--shadow-hover);
    z-index: 99;
    transition: background 0.2s, transform 0.2s;
}
.back-to-top:hover {
    background: var(--primary-dark);
    transform: scale(1.1);
}

/* ===== 文章正文图片 ===== */
.post-content figure {
    margin: 1.5em 0;
    text-align: center;
}
.post-content figure img {
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    max-width: 100%;
    height: auto;
}
.post-content figcaption {
    color: var(--text-secondary);
    font-size: 0.9rem;
    margin-top: 0.5em;
}

/* ===== 响应式 ===== */
@media (max-width: 768px) {
    .nav-toggle {
        display: block;
    }

    .nav-links {
        display: none;
        position: absolute;
        top: 60px;
        left: 0;
        right: 0;
        background: var(--nav-bg);
        flex-direction: column;
        padding: 16px 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }

    .nav-links.active {
        display: flex;
    }

    .nav-link {
        padding: 12px 16px;
    }

    .post-content {
        padding: 20px;
    }

    .post-nav {
        flex-direction: column;
    }

    .category-grid {
        grid-template-columns: 1fr;
    }

    .friend-grid {
        grid-template-columns: 1fr;
    }

    .about-card {
        padding: 24px;
    }

    .page-header h1 {
        font-size: 1.5rem;
    }
}
CSS_EOF
}

# ============================================================
# 生成首页
# ============================================================
generate_index() {
    local output_file="$OUTPUT_DIR/index.html"

    cat > "$output_file" << INDEX_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "首页")
    <main class="main-content">
        <div class="container">
            <div class="page-header">
                <h1>最新文章</h1>
                <p>记录技术，分享思考</p>
            </div>
INDEX_HEAD

    # 文章列表
    local count=0
    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title excerpt category tags date <<< "$article"
        local slug="${ARTICLE_SLUGS[$count]}"
        local tag_list=""
        for tag in $tags; do
            tag_list="${tag_list}<span class=\"tag\">${tag}</span>"
        done

        # 阅读时间估算
        local read_time=$(( (${#excerpt} / 400) + 1 ))
        if [ "$read_time" -eq 0 ]; then
            read_time=1
        fi

        cat >> "$output_file" << ARTICLE_CARD

            <article class="article-card">
                <img src="https://picsum.photos/seed/${slug}/800/400" alt="${title}" class="article-card-image" loading="lazy" onerror="this.style.display='none';this.parentElement.classList.add('img-fallback')">
                <div class="article-card-body">
                    <h2><a href="posts/${slug}.html">${title}</a></h2>
                    <div class="article-meta">
                        <span>&#x1F4C5; ${date}</span>
                        <span>&#x1F4C1; ${category}</span>
                        <span>&#x23F1; 约 ${read_time} 分钟</span>
                    </div>
                    <p class="article-excerpt">${excerpt}</p>
                    <div class="article-tags">${tag_list}</div>
                </div>
            </article>
ARTICLE_CARD

        count=$((count + 1))
    done

    # 分页感
    cat >> "$output_file" << PAGINATION

            <div class="pagination">
                <span class="current">1</span>
                <a href="#">2</a>
                <a href="#">3</a>
                <a href="#">下一页 &#x2192;</a>
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
PAGINATION
}

# ============================================================
# 生成关于页面
# ============================================================
generate_about() {
    local output_file="$OUTPUT_DIR/about.html"

    cat > "$output_file" << ABOUT_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>关于 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="关于 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/about.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "关于")
    <main class="main-content">
        <div class="container">
            <div class="about-card">
                <img src="https://picsum.photos/seed/avatar-${BLOGGER_NAME}/120/120" alt="${BLOGGER_NAME}" class="about-avatar" onerror="this.style.display='none'">
                <h2 class="about-name">${BLOGGER_NAME}</h2>
                <p class="about-bio">${BLOGGER_BIO}</p>

                <div class="about-section">
                    <h3>技能栈</h3>
                    <div class="skill-tags">
ABOUT_HEAD

    for skill in ${BLOGGER_SKILLS//, / }; do
        echo "                        <span class=\"skill-tag\">${skill}</span>" >> "$output_file"
    done

    cat >> "$output_file" << ABOUT_FOOT
                    </div>
                </div>

                <div class="about-section">
                    <h3>联系方式</h3>
                    <ul class="contact-list">
                        <li>邮箱：${BLOGGER_EMAIL}</li>
                        <li>GitHub：<a href="${BLOGGER_GITHUB}" target="_blank">${BLOGGER_GITHUB}</a></li>
                    </ul>
                </div>
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
ABOUT_FOOT
}

# ============================================================
# 生成归档页面
# ============================================================
generate_archives() {
    local output_file="$OUTPUT_DIR/archives.html"

    cat > "$output_file" << ARCH_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>归档 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="归档 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/archives.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "归档")
    <main class="main-content">
        <div class="container">
            <div class="page-header">
                <h1>文章归档</h1>
                <p>按时间线浏览所有文章</p>
            </div>
            <div class="timeline">
ARCH_HEAD

    local current_year=""
    local current_month=""
    local arch_idx=0

    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title excerpt category tags date <<< "$article"
        local slug="${ARTICLE_SLUGS[$arch_idx]}"
        local year="${date%%-*}"
        local rest="${date#*-}"
        local month="${rest%%-*}"

        if [ "$year" != "$current_year" ]; then
            echo "                <div class=\"timeline-year\">${year} 年</div>" >> "$output_file"
            current_year="$year"
            current_month=""
        fi

        if [ "$month" != "$current_month" ]; then
            echo "                <div class=\"timeline-month\">${month} 月</div>" >> "$output_file"
            current_month="$month"
        fi

        echo "                <div class=\"timeline-item\"><span class=\"timeline-date\">${date}</span><a href=\"posts/${slug}.html\">${title}</a></div>" >> "$output_file"
        arch_idx=$((arch_idx + 1))
    done

    cat >> "$output_file" << ARCH_FOOT
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
ARCH_FOOT
}

# ============================================================
# 生成分类页面
# ============================================================
generate_categories() {
    local output_file="$OUTPUT_DIR/categories.html"

    cat > "$output_file" << CAT_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>分类 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="分类 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/categories.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "分类")
    <main class="main-content">
        <div class="container">
            <div class="page-header">
                <h1>文章分类</h1>
                <p>按主题浏览文章</p>
            </div>
            <div class="category-grid">
CAT_HEAD

    for cat in "${CATEGORIES[@]}"; do
        local cat_count=0
        local cat_articles=""
        local cat_idx=0

        for article in "${ARTICLES[@]}"; do
            IFS='|' read -r title excerpt category tags date <<< "$article"
            if [ "$category" = "$cat" ]; then
                local slug="${ARTICLE_SLUGS[$cat_idx]}"
                cat_count=$((cat_count + 1))
                cat_articles="${cat_articles}<li><a href=\"posts/${slug}.html\">${title}</a></li>"
            fi
            cat_idx=$((cat_idx + 1))
        done

        if [ "$cat_count" -gt 0 ]; then
            cat >> "$output_file" << CAT_CARD
                <div class="category-card">
                    <h3><a href="#">${cat}</a></h3>
                    <span class="category-count">${cat_count} 篇文章</span>
                    <ul class="category-articles">
                        ${cat_articles}
                    </ul>
                </div>
CAT_CARD
        fi
    done

    cat >> "$output_file" << CAT_FOOT
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
CAT_FOOT
}

# ============================================================
# 生成标签页面
# ============================================================
generate_tags() {
    local output_file="$OUTPUT_DIR/tags.html"

    cat > "$output_file" << TAG_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>标签 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="标签 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/tags.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "标签")
    <main class="main-content">
        <div class="container">
            <div class="page-header">
                <h1>标签云</h1>
                <p>按标签浏览文章</p>
            </div>
            <div class="tag-cloud">
TAG_HEAD

    # 标签云不同大小
    local sizes=(0.85 0.9 0.95 1.0 1.1 1.2 1.35 1.5)
    local size_idx=0

    for tag in "${TAGS[@]}"; do
        local size="${sizes[$((size_idx % ${#sizes[@]}))]}"
        echo "                <a href=\"#\" class=\"tag-item\" style=\"font-size: ${size}rem\">${tag}</a>" >> "$output_file"
        size_idx=$((size_idx + 1))
    done

    cat >> "$output_file" << TAG_FOOT
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
TAG_FOOT
}

# ============================================================
# 生成友链页面
# ============================================================
generate_friends() {
    local output_file="$OUTPUT_DIR/friends.html"

    cat > "$output_file" << FRIEND_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>友链 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="友链 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/friends.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "友链")
    <main class="main-content">
        <div class="container">
            <div class="page-header">
                <h1>友情链接</h1>
                <p>志同道合的朋友们</p>
            </div>
            <div class="friend-grid">
FRIEND_HEAD

    for friend in "${FRIENDS[@]}"; do
        IFS='|' read -r name url desc avatar <<< "$friend"
        cat >> "$output_file" << FRIEND_CARD
                <div class="friend-card">
                    <img src="${avatar}" alt="${name}" class="friend-avatar" loading="lazy" onerror="this.style.display='none'">
                    <div class="friend-info">
                        <h3><a href="${url}" target="_blank">${name}</a></h3>
                        <p>${desc}</p>
                    </div>
                </div>
FRIEND_CARD
    done

    cat >> "$output_file" << FRIEND_FOOT
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
FRIEND_FOOT
}

# ============================================================
# 生成文章页面
# ============================================================
generate_posts() {
    local total=${#ARTICLES[@]}
    local idx=0

    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title excerpt category tags date <<< "$article"
        local slug="${ARTICLE_SLUGS[$idx]}"
        local output_file="$OUTPUT_DIR/posts/${slug}.html"

        # 读取文章正文
        local body=""
        if [ -f "$BODY_DIR/${idx}.html" ]; then
            body=$(cat "$BODY_DIR/${idx}.html")
        fi

        # 阅读时间估算（基于正文长度）
        local read_time=$(( ($(wc -c < "$BODY_DIR/${idx}.html" 2>/dev/null || echo 200) / 600) + 1 ))

        # 上下篇导航
        local prev_nav=""
        local next_nav=""

        if [ "$idx" -gt 0 ]; then
            local prev_article="${ARTICLES[$((idx - 1))]}"
            IFS='|' read -r prev_title _ _ _ _ <<< "$prev_article"
            local prev_slug="${ARTICLE_SLUGS[$((idx - 1))]}"
            prev_nav="<div class=\"post-nav-item prev\"><div class=\"post-nav-label\">&#x2190; 上一篇</div><a href=\"${prev_slug}.html\" class=\"post-nav-title\">${prev_title}</a></div>"
        fi

        if [ "$idx" -lt $((total - 1)) ]; then
            local next_article="${ARTICLES[$((idx + 1))]}"
            IFS='|' read -r next_title _ _ _ _ <<< "$next_article"
            local next_slug="${ARTICLE_SLUGS[$((idx + 1))]}"
            next_nav="<div class=\"post-nav-item next\"><div class=\"post-nav-label\">下一篇 &#x2192;</div><a href=\"${next_slug}.html\" class=\"post-nav-title\">${next_title}</a></div>"
        fi

        # 标签列表
        local tag_html=""
        for tag in $tags; do
            tag_html="${tag_html}<span class=\"tag\">${tag}</span>"
        done

        # 写入文章页面
        cat > "$output_file" << POST_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="article">
    <meta property="og:title" content="${title}">
    <meta property="og:description" content="${excerpt}">
    <meta property="og:url" content="https://__DOMAIN__/posts/${slug}.html">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="../style.css">
</head>
<body>
    <nav class="main-nav">
        <div class="nav-container">
            <a href="../index.html" class="nav-brand">${BLOG_NAME}</a>
            <button class="nav-toggle" aria-label="菜单" onclick="document.querySelector('.nav-links').classList.toggle('active')">
                <span></span><span></span><span></span>
            </button>
            <div class="nav-links">
                <a href="../index.html" class="nav-link">首页</a>
                <a href="../archives.html" class="nav-link">归档</a>
                <a href="../categories.html" class="nav-link">分类</a>
                <a href="../tags.html" class="nav-link">标签</a>
                <a href="../friends.html" class="nav-link">友链</a>
                <a href="../about.html" class="nav-link">关于</a>
            </div>
        </div>
    </nav>
    <main class="main-content">
        <div class="container">
            <article class="post-content">
                <h1>${title}</h1>
                <div class="article-meta" style="margin-bottom:24px;">
                    <span>&#x1F4C5; ${date}</span>
                    <span>&#x1F4C1; ${category}</span>
                    <span>&#x23F1; 约 ${read_time} 分钟</span>
                </div>
                <img src="https://picsum.photos/seed/${slug}/800/400" alt="${title}" style="width:100%;border-radius:var(--radius);margin-bottom:24px;" onerror="this.style.display='none'">
POST_HEAD

        # 在文章正文中插入图片（在第二个 </p> 后）
        local post_body_file="$BODY_DIR/${idx}.html"
        local tmp_body_file="$BODY_DIR/${idx}_img.html"
        awk -v img='<figure><img src="https://picsum.photos/seed/'${slug}'-fig1/720/400" alt="示意图" loading="lazy"><figcaption>示意图</figcaption></figure>' 'BEGIN{c=0} /<\/p>/{c++; if(c==2){print; print img; next}} {print}' "$post_body_file" > "$tmp_body_file"
        cat "$tmp_body_file" >> "$output_file"

        cat >> "$output_file" << POST_FOOT
                <div class="article-tags" style="margin-top:24px;">
                    ${tag_html}
                </div>
            </article>
            <div class="post-nav">
                ${prev_nav}
                ${next_nav}
            </div>
        </div>
    </main>
    <footer class="site-footer">
        <div class="container">
            <p>&copy; $(date +%Y) ${BLOG_NAME} | 由 ${BLOGGER_NAME} 用 &#x2764;&#xFE0F; 构建</p>
        </div>
    </footer>
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
POST_FOOT

        idx=$((idx + 1))
    done
}

# ============================================================
# 生成 404 页面
# ============================================================
generate_404() {
    local output_file="$OUTPUT_DIR/404.html"

    cat > "$output_file" << NOTFOUND_HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - 页面未找到 - ${BLOG_NAME}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="404 - 页面未找到 - ${BLOG_NAME}">
    <meta property="og:description" content="${BLOGGER_BIO}">
    <meta property="og:url" content="https://__DOMAIN__/">
    <meta name="twitter:card" content="summary">
    <link rel="stylesheet" href="style.css">
</head>
<body>
$(generate_nav "首页")
    <main class="main-content">
        <div class="container">
            <div class="not-found">
                <h1>404</h1>
                <p>抱歉，你访问的页面不存在或已被移除。</p>
                <a href="index.html">返回首页</a>
            </div>
        </div>
    </main>
$(generate_footer)
<button class="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="回到顶部">&#x2191;</button>
<script>
(function(){var b=document.querySelector('.back-to-top');window.addEventListener('scroll',function(){b.style.display=window.scrollY>300?'block':'none'});b.style.display='none'})()
</script>
</body>
</html>
NOTFOUND_HTML
}

# ============================================================
# 生成 sitemap.xml
# ============================================================
generate_sitemap() {
    local output_file="$OUTPUT_DIR/sitemap.xml"

    cat > "$output_file" << SITEMAP_HEAD
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>https://__DOMAIN__/index.html</loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
    </url>
    <url>
        <loc>https://__DOMAIN__/about.html</loc>
        <changefreq>monthly</changefreq>
        <priority>0.6</priority>
    </url>
    <url>
        <loc>https://__DOMAIN__/archives.html</loc>
        <changefreq>weekly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://__DOMAIN__/categories.html</loc>
        <changefreq>weekly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://__DOMAIN__/tags.html</loc>
        <changefreq>weekly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://__DOMAIN__/friends.html</loc>
        <changefreq>monthly</changefreq>
        <priority>0.5</priority>
    </url>
SITEMAP_HEAD

    local sitemap_idx=0
    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title excerpt category tags date <<< "$article"
        local slug="${ARTICLE_SLUGS[$sitemap_idx]}"
        cat >> "$output_file" << SITEMAP_URL
    <url>
        <loc>https://__DOMAIN__/posts/${slug}.html</loc>
        <lastmod>${date}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.8</priority>
    </url>
SITEMAP_URL
        sitemap_idx=$((sitemap_idx + 1))
    done

    echo "</urlset>" >> "$output_file"
}

# ============================================================
# 生成 robots.txt
# ============================================================
generate_robots() {
    cat > "$OUTPUT_DIR/robots.txt" << ROBOTS
User-agent: *
Allow: /
Sitemap: https://__DOMAIN__/sitemap.xml
ROBOTS
}

# ============================================================
# 生成 atom.xml (RSS)
# ============================================================
generate_atom() {
    local output_file="$OUTPUT_DIR/atom.xml"
    # 使用最新文章的发布时间作为 feed updated
    local first_article="${ARTICLES[0]}"
    IFS='|' read -r _ _ _ _ first_date <<< "$first_article"
    local feed_updated="${first_date}T00:00:00Z"

    cat > "$output_file" << ATOM_HEAD
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <title>${BLOG_NAME}</title>
    <subtitle>${BLOGGER_BIO}</subtitle>
    <link href="https://__DOMAIN__/atom.xml" rel="self"/>
    <link href="https://__DOMAIN__/" rel="alternate"/>
    <id>https://__DOMAIN__/</id>
    <updated>${feed_updated}</updated>
    <author>
        <name>${BLOGGER_NAME}</name>
        <email>${BLOGGER_EMAIL}</email>
    </author>
ATOM_HEAD

    local atom_idx=0
    for article in "${ARTICLES[@]}"; do
        IFS='|' read -r title excerpt category tags date <<< "$article"
        local slug="${ARTICLE_SLUGS[$atom_idx]}"
        local date_iso="${date}T00:00:00Z"
        cat >> "$output_file" << ATOM_ENTRY
    <entry>
        <title>${title}</title>
        <link href="https://__DOMAIN__/posts/${slug}.html" rel="alternate"/>
        <id>https://__DOMAIN__/posts/${slug}.html</id>
        <published>${date_iso}</published>
        <updated>${date_iso}</updated>
        <summary>${excerpt}</summary>
        <category term="${category}"/>
    </entry>
ATOM_ENTRY
        atom_idx=$((atom_idx + 1))
    done

    echo "</feed>" >> "$output_file"
}

# ============================================================
# 生成 CSS 文件（替换占位符为实际颜色值）
# ============================================================
generate_css_file() {
    generate_css | \
        sed "s/PRIMARY_COLOR_PLACEHOLDER/${PRIMARY_COLOR}/g" | \
        sed "s/PRIMARY_LIGHT_PLACEHOLDER/${PRIMARY_LIGHT}/g" | \
        sed "s/PRIMARY_DARK_PLACEHOLDER/${PRIMARY_DARK}/g" | \
        sed "s/BG_COLOR_PLACEHOLDER/${BG_COLOR}/g" | \
        sed "s/CARD_BG_PLACEHOLDER/${CARD_BG}/g" | \
        sed "s/TEXT_COLOR_PLACEHOLDER/${TEXT_COLOR}/g" | \
        sed "s/TEXT_SECONDARY_PLACEHOLDER/${TEXT_SECONDARY}/g" | \
        sed "s/CODE_BG_PLACEHOLDER/${CODE_BG}/g" | \
        sed "s/CODE_TEXT_PLACEHOLDER/${CODE_TEXT}/g" | \
        sed "s/ACCENT_PLACEHOLDER/${ACCENT}/g" | \
        sed "s/NAV_BG_PLACEHOLDER/${NAV_BG}/g" | \
        sed "s/NAV_TEXT_PLACEHOLDER/${NAV_TEXT}/g" \
        > "$OUTPUT_DIR/style.css"
}

# ============================================================
# 主流程：生成所有文件
# ============================================================

echo "  生成 CSS..."
generate_css_file

echo "  生成首页..."
generate_index

echo "  生成关于页面..."
generate_about

echo "  生成归档页面..."
generate_archives

echo "  生成分类页面..."
generate_categories

echo "  生成标签页面..."
generate_tags

echo "  生成友链页面..."
generate_friends

echo "  生成文章页面..."
generate_posts

echo "  生成 404 页面..."
generate_404

echo "  生成 sitemap.xml..."
generate_sitemap

echo "  生成 robots.txt..."
generate_robots

echo "  生成 atom.xml..."
generate_atom

echo "完成！模板 ${TEMPLATE_NUM}（${BLOG_NAME}）已生成到 ${OUTPUT_DIR}"
echo "生成文件列表："
ls -la "$OUTPUT_DIR"
echo ""
echo "文章页面："
ls -la "$OUTPUT_DIR/posts/"
