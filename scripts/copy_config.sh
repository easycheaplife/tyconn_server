#!/bin/bash

# 设置源目录和目标目录
SOURCE_DIR="../client/client/WuXiaDFW/assets/resources/config"
CONFIG_DIR="./config"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录 $SOURCE_DIR 不存在"
    exit 1
fi

# 检查配置目录是否存在
if [ ! -d "$CONFIG_DIR" ]; then
    echo "错误: 配置目录 $CONFIG_DIR 不存在"
    exit 1
fi

# 遍历config目录下的所有文件
find "$CONFIG_DIR" -type f -print0 | while IFS= read -r -d '' file; do
    # 获取相对于CONFIG_DIR的路径
    relative_path="${file#$CONFIG_DIR/}"
    # 构建源文件路径
    source_file="$SOURCE_DIR/$relative_path"
    
    # 检查源文件是否存在
    if [ -f "$source_file" ]; then
        echo "正在复制: $relative_path"
        # 确保目标目录存在
        target_dir=$(dirname "$file")
        mkdir -p "$target_dir"
        # 复制文件
        cp "$source_file" "$file"
    else
        echo "警告: 源文件不存在: $source_file"
    fi
done

echo "配置文件复制完成"
