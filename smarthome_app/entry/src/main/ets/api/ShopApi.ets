// api/ShopApi.ets —— 【铁律】所有 URL 只允许出现在 api/ 目录；页面禁止直接调 HttpClient（总方案 7.7）
// URL 一览见《03_接口文档.md》七。商品/轮播公开；购物车、订单需要登录。
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { Goods, CartItem, Order, OrderItemParam, BannerItem, Category } from '../model/Shop'

/** 加入购物车入参（同商品累加数量） */
export interface CartAddParam {
  goodsId: number
  quantity: number
}

/** 修改购物车数量入参 */
export interface CartUpdateParam {
  id: number
  quantity: number
}

/** 提交订单入参（对应后端 OrderCreateDTO） */
export interface OrderCreateParam {
  addressId: number
  items: OrderItemParam[]
}

export class ShopApi {
  // ---------- 商品浏览（公开，不用登录）----------

  /** 首页/商城轮播图（图片路径数组，按 sort 升序） */
  static banners(): Promise<ApiResponse<string[]>> {
    return HttpClient.get<string[]>('/api/goods/banners')
  }

  /** 轮播图完整列表（Banner 对象，position 区分 home/product/shop） */
  static bannerList(position: string): Promise<ApiResponse<BannerItem[]>> {
    return HttpClient.get<BannerItem[]>(`/api/banner/list?position=${position}`)
  }

  /** 商品分类（金刚区，带 id 可按分类筛选） */
  static categories(): Promise<ApiResponse<Category[]>> {
    return HttpClient.get<Category[]>('/api/goods/categories')
  }

  /** 商品列表：categoryId 传 0 = 全部分类；仅返回上架商品 */
  static goodsList(categoryId: number, keyword: string): Promise<ApiResponse<Goods[]>> {
    return HttpClient.get<Goods[]>(`/api/goods/list?categoryId=${categoryId}&keyword=${encodeURI(keyword)}`)
  }

  static goodsDetail(id: number): Promise<ApiResponse<Goods>> {
    return HttpClient.get<Goods>(`/api/goods/${id}`)
  }

  // ---------- 购物车（需登录）----------

  static addCart(goodsId: number, quantity: number): Promise<ApiResponse<void>> {
    const body: CartAddParam = { goodsId: goodsId, quantity: quantity }
    return HttpClient.post<void>('/api/cart', body)
  }

  static cartList(): Promise<ApiResponse<CartItem[]>> {
    return HttpClient.get<CartItem[]>('/api/cart/list')
  }

  static updateCart(id: number, quantity: number): Promise<ApiResponse<void>> {
    const body: CartUpdateParam = { id: id, quantity: quantity }
    return HttpClient.put<void>('/api/cart', body)
  }

  static removeCart(id: number): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>(`/api/cart/${id}`)
  }

  static clearCart(): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>('/api/cart/clear')
  }

  // ---------- 订单（需登录）----------

  /** 提交订单（一个事务：校验库存→扣库存→生成订单→清购物车） */
  static createOrder(addressId: number, items: OrderItemParam[]): Promise<ApiResponse<Order>> {
    const body: OrderCreateParam = { addressId: addressId, items: items }
    return HttpClient.post<Order>('/api/order/create', body)
  }

  /** 模拟支付：后端直接把订单状态改为已付款，不接真实支付 */
  static payOrder(orderId: number): Promise<ApiResponse<void>> {
    return HttpClient.post<void>(`/api/order/${orderId}/pay`)
  }

  /** 取消订单（回滚库存） */
  static cancelOrder(orderId: number): Promise<ApiResponse<void>> {
    return HttpClient.post<void>(`/api/order/${orderId}/cancel`)
  }

  /** 订单列表：-1 全部 / 0 待付款 / 1 已付款 / 2 已完成 */
  static orderList(status: number): Promise<ApiResponse<Order[]>> {
    return HttpClient.get<Order[]>(`/api/order/list?status=${status}`)
  }

  static orderDetail(orderId: number): Promise<ApiResponse<Order>> {
    return HttpClient.get<Order>(`/api/order/${orderId}`)
  }
}
