# CatRest

一个住在 macOS 菜单栏里的猫咪番茄钟。  
专注一会儿，猫咪就会跳出来提醒你休息一下。

![CatRest 使用演示](./video.gif)

如果你喜欢 CatRest，欢迎给这个项目点个 Star。  
也可以来 X / Twitter 找我：[@cyberpigeonb](https://x.com/cyberpigeonb)

## 怎么运行

需要 macOS 13+，并安装 Xcode Command Line Tools 或 Xcode。

在项目根目录运行：

```bash
./script/build_and_run.sh
```

运行后，CatRest 会出现在菜单栏。点击猫咪图标就能开始使用。

## 怎么用

点一下菜单栏里的猫咪，选择“开始”。  
默认先专注 25 分钟，然后休息 5 分钟。休息时间到，猫咪会铺满屏幕提醒你别硬撑。

想换节奏也很简单：

- “工作时长”：改专注多久。
- “休息时长”：改休息多久。
- “开机启动”：让猫咪每天自动上班。
- “退出 CatRest”：今天先放猫下班。

## 开发命令

```bash
swift build
swift run CatRest
```

打包并启动：

```bash
./script/build_and_run.sh
```

快速测试一轮超短番茄钟：

```bash
./script/build_and_run.sh --smoke-cycle
```

## 小尾巴

CatRest 很简单：开始专注，到点休息，休息完继续。  
你负责写东西，猫咪负责把你从椅子上劝起来。
