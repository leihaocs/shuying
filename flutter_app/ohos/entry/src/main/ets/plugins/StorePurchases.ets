import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@kit.BasicServicesKit';
import { iap } from '@kit.IAPKit';
import { HUAWEI_APP_ID, HUAWEI_CLIENT_ID, HUAWEI_PRODUCT_ID, SANDBOX_ONLY } from './HuaweiIapConfig';
import { VerifiedPurchaseOrder, verifyPurchaseOrder } from './PurchaseVerification';

interface PurchaseData {
  jwsPurchaseOrder: string;
}

interface StoreProduct {
  purchasesEnabled: boolean;
  sandbox: boolean;
  productId: string;
  price?: string;
  message?: string;
  code?: string;
}

class StoreFailure extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

// This first integration is deliberately sandbox-only. A verified sandbox
// entitlement lasts only for this foreground session, never as a paid license.
export default class StorePurchases implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private channel: MethodChannel | null = null;
  private pending: MethodResult | null = null;
  private pendingMethod: string = '';
  private attached: boolean = false;
  private foreground: boolean = true;
  private generation: number = 0;
  private sandboxEntitled: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  attach(binding: FlutterPluginBinding): void {
    this.attached = true;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.bookmovie.revisit/purchases');
    this.channel.setMethodCallHandler(this);
  }

  detach(): void {
    this.generation++;
    this.sandboxEntitled = false;
    const pending = this.pending;
    this.pending = null;
    this.pendingMethod = '';
    this.attached = false;
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    pending?.error('interrupted', '购买查询已中断，请重新打开高级功能页面。', null);
  }

  onForeground(): void {
    this.foreground = true;
  }

  onBackground(): void {
    this.foreground = false;
    this.generation++;
    this.setEntitlement(false);
    // A checkout can legitimately leave the app. Keep that request exclusive
    // until the store reports its real result; ordinary old queries are stale.
    if (this.pendingMethod !== 'buy') {
      const pending = this.pending;
      this.pending = null;
      this.pendingMethod = '';
      pending?.error('interrupted', '沙盒会话已结束，返回应用后请刷新。', null);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'status' && call.method !== 'product' && call.method !== 'buy' && call.method !== 'restore') {
      result.notImplemented();
      return;
    }
    if (!this.attached || !this.foreground) {
      result.error('interrupted', '请返回应用后重试购买。', null);
      return;
    }
    if (this.pending !== null) {
      result.error('busy', '商店请求尚未完成，请稍后重试。', null);
      return;
    }
    this.pending = result;
    this.pendingMethod = call.method;
    this.handle(call.method, result, this.generation);
  }

  private async handle(method: string, result: MethodResult, generation: number): Promise<void> {
    try {
      if (method === 'product') {
        const product = await this.product();
        this.assertCurrent(result, generation);
        this.success(result, product);
        return;
      }
      if (method === 'status') {
        // Return a safe negative for setup errors so Flutter can still read the
        // product diagnostics instead of being stopped by its status-first flow.
        if (this.configurationFailure() !== null) {
          this.setEntitlement(false);
          this.success(result, false);
          return;
        }
        try {
          await this.requireSandbox();
        } catch (error) {
          const failure = this.failure(error as Error);
          if (this.isSetupFailure(failure.code)) {
            this.assertCurrent(result, generation);
            this.setEntitlement(false);
            this.success(result, false);
            return;
          }
          throw failure;
        }
        this.assertCurrent(result, generation);
        const owned = await this.refreshEntitlement(result, generation, true);
        this.assertCurrent(result, generation);
        this.success(result, owned);
        return;
      }
      if (method === 'restore') {
        await this.requireSandbox();
        this.assertCurrent(result, generation);
        const owned = await this.refreshEntitlement(result, generation, true);
        this.assertCurrent(result, generation);
        if (!owned) {
          throw new StoreFailure('sandbox_restore_unavailable', '当前没有待恢复的沙盒订单。华为已确认发货的沙盒非消耗型订单不会再次返回，可重新购买进行测试。');
        }
        this.success(result, true);
        return;
      }
      await this.buy(result, generation);
    } catch (error) {
      if (this.pending !== result) return;
      const failure = this.failure(error as Error);
      if (this.isSetupFailure(failure.code)) this.setEntitlement(false);
      this.error(result, failure);
    }
  }

  private async product(): Promise<StoreProduct> {
    try {
      await this.requireSandbox();
      const product = await this.queryProduct();
      return {
        purchasesEnabled: true,
        sandbox: true,
        productId: HUAWEI_PRODUCT_ID,
        price: product.localPrice
      };
    } catch (error) {
      const failure = this.failure(error as Error);
      return {
        purchasesEnabled: false,
        sandbox: true,
        productId: HUAWEI_PRODUCT_ID,
        message: failure.message,
        code: failure.code
      };
    }
  }

  private async queryProduct(): Promise<iap.Product> {
    const products = await iap.queryProducts(this.context, {
      productType: iap.ProductType.NONCONSUMABLE,
      productIds: [HUAWEI_PRODUCT_ID]
    });
    const product = products.find((item: iap.Product): boolean => item.id === HUAWEI_PRODUCT_ID &&
      item.type === iap.ProductType.NONCONSUMABLE);
    if (product === undefined || typeof product.localPrice !== 'string' || product.localPrice.length === 0) {
      throw new StoreFailure('product', '暂时未查询到 Pro 商品，请检查后台商品、售价和测试账号。');
    }
    return product;
  }

  private async buy(result: MethodResult, generation: number): Promise<void> {
    await this.requireSandbox();
    await this.queryProduct();
    this.assertCurrent(result, generation);
    let purchase: iap.CreatePurchaseResult;
    try {
      purchase = await iap.createPurchase(this.context, {
        productId: HUAWEI_PRODUCT_ID,
        productType: iap.ProductType.NONCONSUMABLE
      });
    } catch (error) {
      const code = (error as BusinessError).code;
      if (code === iap.IAPErrorCode.USER_CANCELED) {
        this.success(result, 'cancelled');
        return;
      }
      if (code === iap.IAPErrorCode.PRODUCT_OWNED || code === iap.IAPErrorCode.SYSTEM_ERROR) {
        // Never interpret "already owned" or an ambiguous payment error as a
        // license. Query the current store account and verify its actual orders.
        const recoveryGeneration = this.generation;
        this.assertCurrent(result, recoveryGeneration);
        if (await this.refreshEntitlement(result, recoveryGeneration)) {
          this.success(result, 'purchased');
          return;
        }
      }
      throw this.failure(error as Error);
    }
    // A checkout is the only operation allowed to cross a background boundary.
    // Its NEW signed result still needs a live foreground and the same request.
    const checkoutGeneration = this.generation;
    this.assertCurrent(result, checkoutGeneration);
    const order = await this.verifiedOrder(purchase.purchaseData);
    this.assertCurrent(result, checkoutGeneration);
    if (order.revoked) {
      this.setEntitlement(false);
      throw new StoreFailure('revoked', '此笔购买已撤销，未解锁 Pro。');
    }
    if (!(order.purchaseTime > 0)) {
      this.success(result, 'pending');
      return;
    }
    // Non-consumable delivery is an idempotent verified set, never a counter.
    this.setEntitlement(true);
    await this.finish(order, result, checkoutGeneration);
    this.success(result, 'purchased');
  }

  private async refreshEntitlement(result: MethodResult, generation: number,
    preserveSandboxSession: boolean = false): Promise<boolean> {
    const current = await this.queryOrders(iap.PurchaseQueryType.CURRENT_ENTITLEMENT, result, generation);
    const unfinished = await this.queryOrders(iap.PurchaseQueryType.UNFINISHED, result, generation);
    this.assertCurrent(result, generation);
    const latest = new Map<string, VerifiedPurchaseOrder>();
    for (const order of current.concat(unfinished)) {
      const previous = latest.get(order.purchaseOrderId);
      if (previous === undefined || order.signedTime > previous.signedTime ||
        (order.signedTime === previous.signedTime && order.revoked)) {
        latest.set(order.purchaseOrderId, order);
      }
    }
    const deliverable: VerifiedPurchaseOrder[] = [];
    latest.forEach((order: VerifiedPurchaseOrder): void => {
      if (!order.revoked && order.purchaseTime > 0) deliverable.push(order);
    });
    // Huawei removes sandbox non-consumables from queryPurchases after finish.
    // Only an empty query may preserve a verified current foreground session.
    // A new signed negative order still revokes it, and background always clears.
    this.setEntitlement(deliverable.length > 0 ||
      (preserveSandboxSession && latest.size === 0 && this.sandboxEntitled));
    for (const order of deliverable) {
      this.assertCurrent(result, generation);
      await this.finish(order, result, generation);
    }
    return this.sandboxEntitled;
  }

  private async queryOrders(queryType: iap.PurchaseQueryType, result: MethodResult,
    generation: number): Promise<VerifiedPurchaseOrder[]> {
    const orders: VerifiedPurchaseOrder[] = [];
    let token: string = '';
    const seen = new Set<string>();
    do {
      this.assertCurrent(result, generation);
      const response = await iap.queryPurchases(this.context, {
        productType: iap.ProductType.NONCONSUMABLE,
        queryType: queryType,
        continuationToken: token.length === 0 ? undefined : token
      });
      this.assertCurrent(result, generation);
      for (const data of response.purchaseDataList) {
        orders.push(await this.verifiedOrder(data));
        this.assertCurrent(result, generation);
      }
      token = response.continuationToken ?? '';
      if (token.length > 0) {
        if (seen.has(token) || seen.size >= 100) {
          throw new StoreFailure('pagination', '商店订单分页异常，请稍后重新查询。');
        }
        seen.add(token);
      }
    } while (token.length > 0);
    return orders;
  }

  private async verifiedOrder(data: string): Promise<VerifiedPurchaseOrder> {
    try {
      if (typeof data !== 'string' || data.length > 256 * 1024) throw new Error('Invalid purchase data');
      const purchase = JSON.parse(data) as PurchaseData;
      if (typeof purchase.jwsPurchaseOrder !== 'string') throw new Error('Missing signed order');
      return await verifyPurchaseOrder(purchase.jwsPurchaseOrder, HUAWEI_APP_ID, true);
    } catch (_) {
      throw new StoreFailure('receipt', '购买凭证校验未通过，暂未解锁。请刷新商店状态或恢复购买。');
    }
  }

  private async finish(order: VerifiedPurchaseOrder, result: MethodResult, generation: number): Promise<void> {
    if (order.finishStatus === '1') return;
    try {
      await iap.finishPurchase(this.context, {
        productType: iap.ProductType.NONCONSUMABLE,
        purchaseToken: order.purchaseToken,
        purchaseOrderId: order.purchaseOrderId
      });
    } catch (error) {
      const code = (error as BusinessError).code;
      if (code === iap.IAPErrorCode.PURCHASE_FINISHED) return;
      if (this.pending === result && generation === this.generation &&
        (code === iap.IAPErrorCode.PURCHASE_ALREADY_REFUNDED || code === iap.IAPErrorCode.PURCHASE_NOT_PAID)) {
        this.setEntitlement(false);
      }
      throw this.failure(error as Error);
    }
  }

  private configurationFailure(): StoreFailure | null {
    if (!SANDBOX_ONLY) return new StoreFailure('configuration', '当前版本仅用于内购沙盒验证，正式购买尚未启用。');
    if (!/^\d+$/.test(HUAWEI_APP_ID) || HUAWEI_CLIENT_ID.length === 0) {
      return new StoreFailure('configuration', '鸿蒙内购调试配置尚未完成，请补齐应用身份和新的调试 Profile。');
    }
    return null;
  }

  private async requireSandbox(): Promise<void> {
    const configuration = this.configurationFailure();
    if (configuration !== null) throw configuration;
    await iap.queryEnvironmentStatus(this.context);
    if (!await iap.isSandboxActivated(this.context)) {
      throw new StoreFailure('sandbox', '当前未进入沙盒测试环境，购买入口已关闭。请检查测试账号和调试签名。');
    }
  }

  private assertCurrent(result: MethodResult, generation: number): void {
    if (!this.attached || !this.foreground || this.pending !== result || generation !== this.generation) {
      throw new StoreFailure('interrupted', '商店请求已中断，请返回应用后刷新。');
    }
  }

  private setEntitlement(owned: boolean): void {
    if (this.sandboxEntitled === owned) return;
    this.sandboxEntitled = owned;
    if (this.attached) this.channel?.invokeMethod('changed', owned);
  }

  private success(result: MethodResult, value: boolean | string | StoreProduct): void {
    if (this.pending !== result) return;
    this.pending = null;
    this.pendingMethod = '';
    result.success(value);
  }

  private error(result: MethodResult, failure: StoreFailure): void {
    if (this.pending !== result) return;
    this.pending = null;
    this.pendingMethod = '';
    result.error(failure.code, failure.message, null);
  }

  private isSetupFailure(code: string): boolean {
    return code === 'configuration' || code === 'sandbox' || code === 'iap_1001860002' ||
      code === 'iap_1001860050' || code === 'iap_1001860054' || code === 'iap_1001860057' ||
      code === 'iap_1001860058';
  }

  private failure(error: Error): StoreFailure {
    if (error instanceof StoreFailure) return error;
    const code = (error as BusinessError).code;
    let message: string;
    switch (code) {
      case iap.IAPErrorCode.APP_NOT_AUTHORIZED:
        message = '应用内购尚未获得授权，请检查能力开关、应用身份及更新后的调试 Profile。'; break;
      case iap.IAPErrorCode.ACCOUNT_NOT_LOGGED_IN:
        message = '请先在手机设置中登录已添加的华为沙盒测试账号。'; break;
      case iap.IAPErrorCode.APP_NOT_DEBUG:
        message = '当前签名不支持沙盒测试，需要使用更新后的调试 Profile。'; break;
      case iap.IAPErrorCode.ACCOUNT_NOT_TEST:
        message = '当前华为账号尚未获得沙盒测试资格，请添加账号并等待生效。'; break;
      case iap.IAPErrorCode.ACCOUNT_TERRITORY_NOT_SUPPORTED:
      case iap.IAPErrorCode.PRODUCT_TERRITORY_NOT_SUPPORTED:
        message = '当前账号服务地区不支持此商品购买。'; break;
      case iap.IAPErrorCode.INVALID_PRODUCT:
        message = '商品尚不可用，请检查后台商品 ID、类型、售价和销售范围。'; break;
      case iap.IAPErrorCode.FREQUENT_CALLS:
        message = '商店请求过于频繁，请稍后重试。'; break;
      case iap.IAPErrorCode.NETWORK_ERROR:
        message = '暂时无法连接华为商店，请检查网络后刷新或恢复购买。'; break;
      case iap.IAPErrorCode.PURCHASE_ALREADY_REFUNDED:
      case iap.IAPErrorCode.PURCHASE_NOT_PAID:
        message = '此笔购买已撤销或尚未付款，未保留 Pro 权益。'; break;
      case iap.IAPErrorCode.PRODUCT_OWNED:
        message = '商店提示已拥有此商品，但权益尚未验证，请恢复购买。'; break;
      default:
        message = '购买结果尚未确认，请刷新商店状态或恢复购买，避免重复操作。'; break;
    }
    return new StoreFailure(typeof code === 'number' ? `iap_${code}` : 'store', message);
  }
}
