
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import BackupPlugin from '../plugins/BackupPlugin';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  private backupPlugin: BackupPlugin | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.backupPlugin = new BackupPlugin(this.context);
    flutterEngine.getPlugins()?.add(this.backupPlugin);
  }

  onForeground(): void {
    this.backupPlugin?.onForeground();
    super.onForeground();
  }

  onBackground(): void {
    this.backupPlugin?.onBackground();
    super.onBackground();
  }
}
