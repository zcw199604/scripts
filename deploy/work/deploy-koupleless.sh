#!/bin/bash
# ============================================================================================
# 脚本名称: deploy_biz.sh
# 脚本描述: 用于 Koupleless (Sofa-Ark) 模块的热部署通用脚本
# 使用场景: 配合 IntelliJ IDEA 的 Cloud Toolkit 插件，在文件上传后自动执行模块更新与重启
#
# 参数说明:
#   --file       : [必填] 待部署的模块 JAR 文件名 (例如: baymax-system-ark-biz.jar)
#   --target     : [必填] 模块部署的目标绝对路径 (例如: /app/merce/system/biz)
#   --arkctl     : [必填] arkctl 工具的绝对路径 (例如: /app/merce/bin/arkctl)
#   --bizName    : [可选] 模块名称，用于执行 undeploy (例如: baymax-system)
#   --bizVersion : [可选] 模块版本号，用于执行 undeploy (例如: 1.0.0)
#   --port       : [可选] 指定基座的管控端口。若一台机器运行多个基座，需通过此参数区分
#   --tmp        : [可选] 临时上传目录，Cloud Toolkit 上传文件的落脚点 (默认: /app/zcw/upload)
#
# 使用示例:
#   sh deploy_biz.sh --file biz.jar --target /app/biz --arkctl /usr/bin/arkctl --port 1244 --bizName my-biz --bizVersion 0.0.1
# ============================================================================================
# --- 1. 初始化默认变量 ---

TMP_DIR="/app/zcw/upload"
FILE_NAME=""
TARGET_DIR=""
ARKCTL_PATH=""
BIZ_NAME=""
BIZ_VERSION=""
PORT=""
TIME_STAMP=$(date +%Y%m%d_%H%M%S)

# --- 2. 解析命令行参数 ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --file) FILE_NAME="$2"; shift ;;
        --target) TARGET_DIR="$2"; shift ;;
        --arkctl) ARKCTL_PATH="$2"; shift ;;
        --bizName) BIZ_NAME="$2"; shift ;;
        --bizVersion) BIZ_VERSION="$2"; shift ;;
        --port) PORT="$2"; shift ;;
        --tmp) TMP_DIR="$2"; shift ;;
        *) echo "[错误] 未知参数: $1"; exit 1 ;;
    esac
    shift
done

# --- 3. 核心参数合法性校验 ---
if [ -z "$FILE_NAME" ] || [ -z "$TARGET_DIR" ] || [ -z "$ARKCTL_PATH" ]; then
    echo "[错误] 缺少必要参数！"
    echo "用法说明: sh $0 --file [文件名] --target [目标目录] --arkctl [arkctl路径] [--bizName 模块名] [--bizVersion 版本号] [--port 端口号] [--tmp 临时目录]"
    exit 1
fi

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# --- 4. 备份旧包 (保留最近3个记录) ---
if [ -f "$TARGET_DIR/$FILE_NAME" ]; then
    echo "[步骤1] 发现旧包，正在备份..."
    mv "$TARGET_DIR/$FILE_NAME" "$TARGET_DIR/${FILE_NAME}.${TIME_STAMP}.bak_zcw"
    # 清理逻辑：按时间排序，删除 3 个以外的旧备份文件
    ls -t "$TARGET_DIR"/${FILE_NAME}.*.bak_zcw 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
    echo "       备份完成，旧包已更名为: ${FILE_NAME}.${TIME_STAMP}.bak_zcw"
else
    echo "[步骤1] 目标目录未发现旧包，跳过备份。"
fi

# --- 5. 移入新包 ---
if [ ! -f "$TMP_DIR/$FILE_NAME" ]; then
    echo "[错误] 临时目录 $TMP_DIR 中未找到上传的文件 $FILE_NAME"
    exit 1
fi
echo "[步骤2] 正在从临时目录移入新包..."
mv "$TMP_DIR/$FILE_NAME" "$TARGET_DIR/$FILE_NAME"

# --- 6. 执行卸载 (Undeploy) 逻辑 ---
# 如果提供了 bizName 和 bizVersion，则先尝试卸载
if [ -n "$BIZ_NAME" ] && [ -n "$BIZ_VERSION" ]; then
    echo "[步骤3] 准备执行 arkctl 卸载旧模块: ${BIZ_NAME}:${BIZ_VERSION}"
    UNDEPLOY_CMD="$ARKCTL_PATH undeploy ${BIZ_NAME}:${BIZ_VERSION}"
    
    if [ -n "$PORT" ]; then
        UNDEPLOY_CMD="$UNDEPLOY_CMD --port $PORT"
    fi
    
    echo "       执行卸载命令: $UNDEPLOY_CMD"
    # 执行卸载，不处理错误（因为如果模块本就不存在，命令会返回非0，但不应影响后续部署）
    $UNDEPLOY_CMD 2>/dev/null
    echo "       卸载流程结束（无论是否存在该模块）。"
else
    echo "[步骤3] 未提供 --bizName 或 --bizVersion，跳过卸载步骤，直接尝试部署。"
fi

# --- 7. 调用 arkctl 执行部署 (Deploy) ---
echo "[步骤4] 准备执行 arkctl 部署..."
# 组装动态命令
DEPLOY_CMD="$ARKCTL_PATH deploy $TARGET_DIR/$FILE_NAME"

# 关键判断：如果传递了 --port 参数，则在命令后追加
if [ -n "$PORT" ]; then
    echo "       检测到指定管控端口: $PORT"
    DEPLOY_CMD="$DEPLOY_CMD --port $PORT"
else
    echo "       未指定端口，将使用 arkctl 默认端口(12382)进行部署"
fi

echo "       执行部署命令: $DEPLOY_CMD"
$DEPLOY_CMD
# --- 8. 结果反馈 ---

if [ $? -eq 0 ]; then

echo "===================================================="

echo ">> 部署成功: $FILE_NAME"

echo "===================================================="

else

echo "===================================================="

echo ">> [失败] 部署任务执行异常"

echo "===================================================="

exit 1

fi
