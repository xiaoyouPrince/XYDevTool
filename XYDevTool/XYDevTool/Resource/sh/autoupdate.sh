#!/bin/sh

# feature: 自动更新脚本
# date：2022/05/26 20:08
# authre： xiaoyou

# 应用内不能直接下载，这样直接使用文件吧

#S_PATH="https://github.com/xiaoyouPrince/XYDevTool/releases/download/1.3.0/XYDevTool.zip"

# download
#wget $S_PATH
mv $1 XYDevTool.zip
tar xf XYDevTool.zip

# quit old
ps aux | grep "XYDevTool.app" > pids
for pid in `awk '{print $2}' pids`; do
	kill "$pid"
done

rm pids

# copy history
# /Applications/XYDevTool.app/Contents/Resources/history.json
cp /Applications/XYDevTool.app/Contents/Resources/history.json XYDevTool.app/Contents/Resources/

rm -rf /Applications/XYDevTool.app

# copy new app
# Desktop/XYDevToolApp/XYDevTool.app
mv XYDevTool.app /Applications/XYDevTool.app

# run new
open /Applications/XYDevTool.app

