#!/bin/sh

Contents(){
cat <<EOF >./AppIcon.appiconset/Contents.json
   {
      "images" : [
        {
          "filename" : "icon_16x16.png",
          "idiom" : "Mac",
          "scale" : "1x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_16x16@2x.png",
          "idiom" : "Mac",
          "scale" : "2x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_32x32.png",
          "idiom" : "Mac",
          "scale" : "1x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_32x32@2x.png",
          "idiom" : "Mac",
          "scale" : "2x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_128x128.png",
          "idiom" : "Mac",
          "scale" : "1x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_128x128@2x.png",
          "idiom" : "Mac",
          "scale" : "2x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_256x256.png",
          "idiom" : "Mac",
          "scale" : "1x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_256x256@2x.png",
          "idiom" : "Mac",
          "scale" : "2x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_512x512.png",
          "idiom" : "Mac",
          "scale" : "1x",
          "size" : "512x512"
        },
        {
          "filename" : "icon_512x512@2x.png",
          "idiom" : "Mac",
          "scale" : "2x",
          "size" : "512x512"
        }
      ],
      "info" : {
        "author" : "Xcode",
        "version" : 1
      }
    }

EOF
}

setIconImage(){
    echo "开始生成图标······"
    echo "$1"
    sips -z 16 16     icon.png --out ./AppIcon.appiconset/icon_16x16.png
    sips -z 32 32     icon.png --out ./AppIcon.appiconset/icon_16x16@2x.png
    sips -z 32 32     $1 --out ./AppIcon.appiconset/icon_32x32.png
    sips -z 64 64     $1 --out ./AppIcon.appiconset/icon_32x32@2x.png
    sips -z 128 128   "$1" --out ./AppIcon.appiconset/icon_128x128.png
    sips -z 256 256   "$1" --out ./AppIcon.appiconset/icon_128x128@2x.png
    sips -z 256 256   "$1" --out ./AppIcon.appiconset/icon_256x256.png
    sips -z 512 512   "$1" --out ./AppIcon.appiconset/icon_256x256@2x.png
    sips -z 512 512   "$1" --out ./AppIcon.appiconset/icon_512x512.png
    sips -z 1024 1024   "$1" --out ./AppIcon.appiconset/icon_512x512@2x.png
    echo "全部图标生成······"
}

if [ -n "$1" ] ; then
    echo "icon地址： $1"
else
    echo "icon不能为空"
   exit 1
fi

mv "$1" ./icon.png
mkdir AppIcon.appiconset
Contents
setIconImage $1
mv AppIcon.appiconset ~/Desktop
