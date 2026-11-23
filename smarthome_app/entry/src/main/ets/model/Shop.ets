// model/Shop.ets —— 数据模型：与后端 VO 字段一一对应（手册 5.5）
export interface Goods {
  id: number
  categoryId: number
  name: string
  cover: string
  images?: string         // JSON 数组字符串（轮播图）
  price: number
  originPrice?: number    // 划线原价
  stock: number
  sales: number
  detail?: string
  tags?: string           // 搜索标签（逗号分隔）
}

/** 商品分类（对应后端 GoodsCategory，GET /api/goods/categories） */
export interface Category {
  id: number
  name: string
  sort?: number
}

export interface CartItem {
  id: number
  goodsId: number
  goodsName: string
  goodsCover: string
  price: number
  quantity: number
  checked: boolean        // 前端本地状态，不存数据库
}

export interface OrderItem {
  goodsId: number
  goodsName: string
  goodsCover: string
  price: number
  quantity: number
}

/** 轮播图（对应后端 Banner，GET /api/banner/list） */
export interface BannerItem {
  id: number
  title?: string
  imageUrl?: string
  linkUrl?: string
  position?: string       // home / product / shop
  sort?: number
  enabled?: number
}

/** 提交订单的明细参数（对应后端 OrderCreateDTO.items，禁止裸字面量） */
export interface OrderItemParam {
  goodsId: number
  quantity: number
}

export interface Order {
  id: number
  orderNo: string
  totalAmount: number
  status: number          // 0 待付款 1 已付款 2 已完成 3 已取消
  createTime: string
  items: OrderItem[]
  // 下单时从地址表复制的快照（之后改地址不影响历史订单，接口文档七）
  receiverName?: string
  receiverPhone?: string
  receiverAddress?: string
}
