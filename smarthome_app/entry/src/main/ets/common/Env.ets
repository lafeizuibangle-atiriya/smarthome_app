// common/Env.ets —— 服务器地址：切环境只改这一个文件，页面里禁止写死地址（总方案 7.4）
export class Env {
  // 真机联调：改成后端电脑的局域网 IP（电脑上 ipconfig 查看），手机与电脑连同一 WiFi
  static readonly BASE_URL_DEV: string = 'http://172.28.0.1'
  // 模拟器：10.0.2.2 指向宿主机
  static readonly BASE_URL_EMULATOR: string = 'http://10.0.2.2:8080'

  // 当前使用哪个环境：真机联调时改这里
  static readonly BASE_URL: string = Env.BASE_URL_EMULATOR
}
