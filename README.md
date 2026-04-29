# CatRest

A tiny cat Pomodoro timer that lives in your macOS menu bar.  
Focus for a while, then let the cat pop up and remind you to take a real break.

[中文 README](./README_zh.md)

Download: [CarRest.zip](https://github.com/timfaner/CatRest/releases/download/0.1/CarRest.zip)

![CatRest demo](./video.gif)

If CatRest makes your day a little better, please give the project a Star.  
You can also follow me on X / Twitter: [@cyberpigeonb](https://x.com/cyberpigeonb)

## Run It

You need macOS 13+ and Xcode Command Line Tools or Xcode.

From the project root:

```bash
./script/build_and_run.sh
```

CatRest will show up in your menu bar. Click the cat icon to get started.

## How To Use

Click the cat in the menu bar, then choose "Start".  
By default, CatRest gives you 25 minutes of focus time and 5 minutes of rest time. When it is break time, the cat takes over your screen so you actually stop staring at your work.

Want a different rhythm?

- "Work Duration": change how long you focus.
- "Rest Duration": change how long you rest.
- "Launch at Login": let the cat clock in automatically.
- "Quit CatRest": send the cat home for the day.

## Development

```bash
swift build
swift run CatRest
```

Build and launch the app bundle:

```bash
./script/build_and_run.sh
```

Run a very short smoke cycle:

```bash
./script/build_and_run.sh --smoke-cycle
```

## Tiny Pitch

CatRest is simple: start focusing, take a break, then keep going.  
You do the work. The cat handles the chair-escape negotiations.
