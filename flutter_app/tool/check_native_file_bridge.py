#!/usr/bin/env python3
"""只读检查原生文件桥的线程、收尾与分块源码约束；不编译或替代真机验收。"""

from pathlib import Path
import re


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    app = Path(__file__).resolve().parents[1]
    android = (app / "android/app/src/main/kotlin/com/shuying/app/shuying/MainActivity.kt").read_text()
    ios = (app / "ios/Runner/AppDelegate.swift").read_text()
    ohos = (app / "ohos/entry/src/main/ets/plugins/BackupPlugin.ets").read_text()

    activity_result = android.split("override fun onActivityResult", 1)[1].split(
        "override fun cleanUpFlutterEngine", 1
    )[0]
    require("fileIO.execute" in activity_result, "Android 文件结果回调须把完整 IO 交给后台队列")
    require("runOnUiThread { if (pending === operation)" in activity_result,
            "Android 旧任务回调须检查请求身份，并在 UI 线程完成 Result")
    require("requestCode != fileRequestCode" in activity_result and
            "requestCode == shareRequestCode" in activity_result and
            "return nextRequestCode++" in android,
            "Android 文件及分享选择器须逐请求路由，不能误接引擎重建前的旧结果")
    require("abandonFileOperations()" in android and "fileIO.shutdown()" in android,
            "Android 销毁路径须结束等待并释放后台队列")
    require("generation == fileGeneration" in android and "generation: Int" in android,
            "Android 分块读写须识别已中断的旧请求")

    require('DispatchQueue(label: "com.bookmovie.revisit.file-io"' in ios,
            "iOS 文件 IO 须使用专用后台队列")
    require("nonisolated static func readBackup" in ios and "nonisolated static func exportURL" in ios,
            "iOS 后台文件帮助函数不得隐式依赖 MainActor 状态")
    require("self.fileToken == token" in ios and "guard fileToken == token" in ios,
            "iOS 异步结果须按请求身份完成")
    require("presentationControllerDidDismiss" in ios and "documentPickerWasCancelled" in ios,
            "iOS 须处理文件选择器取消及交互关闭")
    require("appServices?.detach()" in ios and "func detach()" in ios,
            "iOS 替换引擎服务时须结束旧的待处理请求")

    require(not re.search(r"fs\.(?:open|read|write|fsync|close|stat)Sync\(", ohos),
            "鸿蒙文件读写不能退回主线程同步 IO")
    require("await fs.read(file.fd, chunk)" in ohos and
            not re.search(r"fs\.read\(file\.fd, chunk,\s*\{\s*offset:", ohos),
            "鸿蒙分块顺序读取须沿用 fd 当前指针，不能额外累加 offset 跳读")
    require("if (this.pending !== result) return;" in ohos and "pending?.error(" in ohos,
            "鸿蒙引擎分离须结束等待，旧续体须拒绝重复回复")
    require("bytes.slice(offset, Math.min(offset + 65536, bytes.length))" in ohos,
            "鸿蒙部分写入只复制最多 64 KiB，不能反复复制全部剩余数据")
    require("call.argument('bytes') as Uint8Array | null" in ohos,
            "鸿蒙通道二进制参数须显式声明类型，不能隐式推断 Any")
    require("controller.off('dismiss', dismiss)" in ohos,
            "鸿蒙移除分享监听须传入原回调，匹配本机 SDK 的必填参数")
    require("await fs.fsync(file.fd)" in ohos and "finally { await fs.close(file); }" in ohos,
            "鸿蒙保存完成前须刷盘，并确保关闭文件")

    for name, source in (("Android", android), ("iOS", ios), ("HarmonyOS", ohos)):
        require("20 * 1024 * 1024" in source, f"{name} 须保留默认大备份确认边界")
    print("原生文件桥源码约束检查通过；未进行 Kotlin/Swift/ArkTS 编译或真机验收。")


if __name__ == "__main__":
    main()
