// api/UserApi.ets —— 【阶段① · C 负责】用户相关接口。
// 【铁律】所有 URL 只允许出现在 api/ 目录；页面禁止直接调 HttpClient（总方案 7.7）。
//
// ⚠️ ArkTS 严格模式（手册 5.0 ①）：裸对象字面量不能直接传进 object 参数。
//    所有请求体都必须先声明 interface，再赋给一个有类型的变量传下去。
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { UserInfo, Address } from '../model/User'

/** 登录请求体（对应后端 LoginDTO） */
export interface LoginParam {
  username: string
  password: string
}

/** 注册请求体（对应后端 RegisterDTO） */
export interface RegisterParam {
  username: string
  nickname: string
  password: string
}

/** 发送邮箱验证码请求体（对应后端 EmailCodeDTO） */
export interface EmailCodeParam {
  email: string
}

/** 邮箱注册请求体（对应后端 EmailRegisterDTO；2026-09-29 加手机号） */
export interface EmailRegisterParam {
  email: string
  code: string
  phone: string
  password: string
  nickname: string
}

/** 收货地址入参（对应后端 AddressDTO，body 带 id 即为修改） */
export interface AddressParam {
  id?: number
  receiver: string
  phone: string
  region: string
  detail: string
  isDefault: number
}

export class UserApi {
  /** 登录成功时 data 就是 JWT 字符串 */
  static login(username: string, password: string): Promise<ApiResponse<string>> {
    const body: LoginParam = { username: username, password: password }
    return HttpClient.post<string>('/api/user/login', body)
  }

  static register(username: string, nickname: string, password: string): Promise<ApiResponse<void>> {
    const body: RegisterParam = { username: username, nickname: nickname, password: password }
    return HttpClient.post<void>('/api/user/register', body)
  }

  /** 发送邮箱验证码（60 秒有效，存 Redis；60 秒内不可重发） */
  static sendEmailCode(email: string): Promise<ApiResponse<void>> {
    const body: EmailCodeParam = { email: email }
    return HttpClient.post<void>('/api/user/email/code', body)
  }

  /** 邮箱注册：username 复用邮箱，带手机号（2026-09-29）；注册后直接用邮箱 + 密码登录 */
  static registerByEmail(email: string, code: string, phone: string, password: string,
    nickname: string): Promise<ApiResponse<void>> {
    const body: EmailRegisterParam = {
      email: email,
      code: code,
      phone: phone,
      password: password,
      nickname: nickname
    }
    return HttpClient.post<void>('/api/user/register/email', body)
  }

  /** 需要带 token（拦截器放行白名单里没有 /api/user/info） */
  static info(): Promise<ApiResponse<UserInfo>> {
    return HttpClient.get<UserInfo>('/api/user/info')
  }

  static addressList(): Promise<ApiResponse<Address[]>> {
    return HttpClient.get<Address[]>('/api/address/list')
  }

  // ---------- 收货地址（阶段⑤，下单要用；对应后端 AddressController 4 个端点）----------

  static addAddress(param: AddressParam): Promise<ApiResponse<Address>> {
    return HttpClient.post<Address>('/api/address', param)
  }

  static updateAddress(param: AddressParam): Promise<ApiResponse<Address>> {
    return HttpClient.put<Address>('/api/address', param)
  }

  static removeAddress(id: number): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>(`/api/address/${id}`)
  }
}
