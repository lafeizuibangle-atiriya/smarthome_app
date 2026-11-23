// api/ProductApi.ets —— 【铁律】所有 URL 只允许出现在 api/ 目录；页面禁止直接调 HttpClient（总方案 7.7）
// URL 一览见《03_接口文档.md》六。产品库是公开接口，不用登录。
// 注意：category/keyword 都是中文，拼进 URL 前必须 encodeURI，否则后端收到乱码。
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { Product } from '../model/Product'

export class ProductApi {
  /** 产品分类（字符串数组，如 ["照明","安防","环境","厨电"]） */
  static categories(): Promise<ApiResponse<string[]>> {
    return HttpClient.get<string[]>('/api/product/categories')
  }

  /** 产品列表：category 传空串 = 全部分类；keyword 模糊匹配名称 */
  static list(category: string, keyword: string): Promise<ApiResponse<Product[]>> {
    return HttpClient.get<Product[]>(`/api/product/list?category=${encodeURI(category)}&keyword=${encodeURI(keyword)}`)
  }

  /** 产品详情（含规格参数、卖点、关联商品 id） */
  static detail(id: number): Promise<ApiResponse<Product>> {
    return HttpClient.get<Product>(`/api/product/${id}`)
  }
}
