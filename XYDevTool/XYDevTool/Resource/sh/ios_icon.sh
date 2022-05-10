#!/bin/sh

Contents(){
    cat ./Contents.json >./AppIcon.appiconset/Contents.json
}

setIconImage(){
    echo "开始生成图标······"
    echo "$1"
    sips -z 40 40       "$1" --out ./AppIcon.appiconset/iPhone\ Notification-20@2x.png
    sips -z 60 60       "$1" --out ./AppIcon.appiconset/iPhone\ Notification-20@3x.png
    sips -z 58 58       "$1" --out ./AppIcon.appiconset/iPhone\ Settings-29@2x.png
    sips -z 87 87       "$1" --out ./AppIcon.appiconset/iPhone\ Settings-29@3x.png
    sips -z 80 80       "$1" --out ./AppIcon.appiconset/iPhone\ Spotlight-40@2x.png
    sips -z 120 120     "$1" --out ./AppIcon.appiconset/iPhone\ Spotlight-40@3x.png
    sips -z 120 120     "$1" --out ./AppIcon.appiconset/iPhone\ App-60@2x.png
    sips -z 180 180     "$1" --out ./AppIcon.appiconset/iPhone\ App-60@3x.png
    sips -z 20 20       "$1" --out ./AppIcon.appiconset/iPad\ Notifications-20.png
    sips -z 40 40       "$1" --out ./AppIcon.appiconset/iPad\ Notifications-20@2x.png
    sips -z 29 29       "$1" --out ./AppIcon.appiconset/iPad\ Settings-29.png
    sips -z 58 58       "$1" --out ./AppIcon.appiconset/iPad\ Settings-29@2x.png
    sips -z 40 40       "$1" --out ./AppIcon.appiconset/iPad\ Spotlight-40.png
    sips -z 80 80       "$1" --out ./AppIcon.appiconset/iPad\ Spotlight-40@2x.png
    sips -z 76 76       "$1" --out ./AppIcon.appiconset/iPad\ App-76.png
    sips -z 152 152     "$1" --out ./AppIcon.appiconset/iPad\ App-76@2x.png
    sips -z 167 167     "$1" --out ./AppIcon.appiconset/iPad\ Pro\ App-83.5@2x.png
    sips -z 120 120     "$1" --out ./AppIcon.appiconset/CarPlay-60@2x.png
    sips -z 180 180     "$1" --out ./AppIcon.appiconset/CarPlay-60@3x.png
    sips -z 1024 1024   "$1" --out ./AppIcon.appiconset/App\ Store-1024.png
    echo "全部图标生成······"
}

if [ -n "$1" ] ; then
    echo "icon地址： $1"
else
    echo "icon不能为空"
   exit 1
fi

# 不能执行这一步，操作完之后就把原文件，拷贝到当前 bundle.sourcePath 了
#mv "$1" ./icon.png
mkdir AppIcon.appiconset
Contents
setIconImage $1

if [ -n "$2" ] ; then
    echo "输出目标地址： $2"
    mv AppIcon.appiconset "$2"
else
    echo "输出目标地址为空, 默认为桌面"
    mv AppIcon.appiconset ~/Desktop
fi

