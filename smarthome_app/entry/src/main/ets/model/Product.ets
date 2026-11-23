// model/Product.ets —— 数据模型：与后端 VO 字段一一对应（手册 5.4）
export interface Product {
  id: number
  name: string
  category: string
  cover: string
  slogan: string          // 一句话卖点
  description?: string
  specs?: string          // JSON 字符串：规格参数数组
  tags?: string           // 'WiFi,联动'
  relatedGoodsId?: number // 关联商品，用于"去商城看看"
}
