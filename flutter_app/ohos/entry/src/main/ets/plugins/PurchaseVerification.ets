import cert from '@ohos.security.cert';
import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

export const PRO_PRODUCT_ID: string = 'com.bookmovie.revisit.app.pro.lifetime';

// Public trust anchor downloaded from Huawei's IAP verification documentation:
// https://pki.consumer.huawei.com/ca/cer/RootCaG2Ecdsa.cer
// SHA-256(DER): DF21A3C09F7954579305F85C64F80CAD86F79853EE3A887C1DEC95D218DF3A37
// This is a public CA certificate, never a merchant signing key.
const HUAWEI_ROOT_DER_BASE64: string =
  'MIICGjCCAaGgAwIBAgIIShhpn519jNAwCgYIKoZIzj0EAwMwUzELMAkGA1UEBhMC' +
  'Q04xDzANBgNVBAoMBkh1YXdlaTETMBEGA1UECwwKSHVhd2VpIENCRzEeMBwGA1UE' +
  'AwwVSHVhd2VpIENCRyBSb290IENBIEcyMB4XDTIwMDMxNjAzMDQzOVoXDTQ5MDMx' +
  'NjAzMDQzOVowUzELMAkGA1UEBhMCQ04xDzANBgNVBAoMBkh1YXdlaTETMBEGA1UE' +
  'CwwKSHVhd2VpIENCRzEeMBwGA1UEAwwVSHVhd2VpIENCRyBSb290IENBIEcyMHYw' +
  'EAYHKoZIzj0CAQYFK4EEACIDYgAEWidkGnDSOw3/HE2y2GHl+fpWBIa5S+IlnNrs' +
  'GUvwC1I2QWvtqCHWmwFlFK95zKXiM8s9yV3VVXh7ivN8ZJO3SC5N1TCrvB2lpHMB' +
  'wcz4DA0kgHCMm/wDec6kOHx1xvCRo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0T' +
  'AQH/BAUwAwEB/zAdBgNVHQ4EFgQUo45a9Vq8cYwqaiVyfkiS4pLcIAAwCgYIKoZI' +
  'zj0EAwMDZwAwZAIwMypeB7P0IbY7c6gpWcClhRznOJFj8uavrNu2PIoz9KIqr3jn' +
  'BlBHJs0myI7ntYpEAjBbm8eDMZY5zq5iMZUC6H7UzYSix4Uy1YlsLVV738PtKP9h' +
  'FTjgDHctXJlC5L7+ZDY=';
const IAP_LEAF_OID: string = '1.3.6.1.4.1.2011.2.415.1.1';

interface JwsHeader {
  alg: string;
  typ: string;
  x5c: string[];
  crit?: string[];
  b64?: boolean;
}

interface PurchaseOrderPayload {
  applicationId: string;
  productId: string;
  productType: string;
  purchaseOrderId: string;
  purchaseToken: string;
  purchaseTime: number;
  finishStatus?: string;
  needFinish?: boolean;
  environment: string;
  signedTime: number;
  price: number;
  currency: string;
  countryCode: string;
  purchaseOrderRevocationReasonCode?: string;
  revocationTime?: number;
}

export interface VerifiedPurchaseOrder {
  applicationId: string;
  productId: string;
  productType: string;
  purchaseOrderId: string;
  purchaseToken: string;
  purchaseTime: number;
  finishStatus?: string;
  needFinish?: boolean;
  environment: string;
  signedTime: number;
  price: number;
  currency: string;
  revoked: boolean;
}

function check(condition: boolean): void {
  if (!condition) throw new Error('购买凭证校验未通过');
}

function equalBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  for (let i = 0; i < left.length; i++) {
    if (left[i] !== right[i]) return false;
  }
  return true;
}

function base64UrlDecode(value: string): Uint8Array {
  check(typeof value === 'string' && value.length > 0 && /^[A-Za-z0-9_-]+$/.test(value) && value.length % 4 !== 1);
  const base64 = new util.Base64Helper();
  const padded = value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4);
  const bytes = base64.decodeSync(padded);
  check(base64.encodeToStringSync(bytes).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_') === value);
  return bytes;
}

function certificateBytes(value: string): Uint8Array {
  check(typeof value === 'string' && value.length > 0 && value.length <= 16384 && /^[A-Za-z0-9+/]+={0,2}$/.test(value));
  const base64 = new util.Base64Helper();
  const bytes = base64.decodeSync(value);
  check(base64.encodeToStringSync(bytes) === value);
  return bytes;
}

function decodeText(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
}

function integerBytes(bytes: Uint8Array): bigint {
  let hex: string = '';
  for (let i = 0; i < bytes.length; i++) hex += bytes[i].toString(16).padStart(2, '0');
  return BigInt(`0x${hex}`);
}

function validTimestamp(value: number): boolean {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
}

function nonempty(value: string, max: number): boolean {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= max;
}

/**
 * Only accepts Huawei-signed, app/SKU/type/environment-bound orders. The caller
 * must obtain the JWS from the current account's IAP APIs; no JSON-backup receipt
 * or local boolean can be passed as a substitute for that authoritative query.
 * Throws on malformed/untrusted receipts; a correctly signed refund returns
 * revoked=true so the caller can remove entitlement rather than retain it.
 */
export async function verifyPurchaseOrder(jws: string, expectedApplicationId: string,
  sandbox: boolean): Promise<VerifiedPurchaseOrder> {
  check(nonempty(expectedApplicationId, 64));
  check(typeof jws === 'string' && jws.length > 0 && jws.length <= 98304);
  const parts = jws.split('.');
  check(parts.length === 3);
  const header = JSON.parse(decodeText(base64UrlDecode(parts[0]))) as JwsHeader;
  check(header !== null && typeof header === 'object' && !Array.isArray(header));
  check(header.alg === 'ES256' && header.typ === 'JWT' && header.crit === undefined && header.b64 === undefined);
  check(Array.isArray(header.x5c) && header.x5c.length === 3);
  const rootBytes = certificateBytes(HUAWEI_ROOT_DER_BASE64);
  const chainBytes: Uint8Array[] = [];
  for (const encoded of header.x5c) chainBytes.push(certificateBytes(encoded));
  // The x5c root is untrusted input. It must be the independently pinned CA.
  check(equalBytes(chainBytes[2], rootBytes));
  const trustedRoot = await cert.createX509Cert({ data: rootBytes, encodingFormat: cert.EncodingFormat.FORMAT_DER });
  const leaf = await cert.createX509Cert({ data: chainBytes[0], encodingFormat: cert.EncodingFormat.FORMAT_DER });
  const intermediate = await cert.createX509Cert({ data: chainBytes[1], encodingFormat: cert.EncodingFormat.FORMAT_DER });
  const chain = cert.createX509CertChain([leaf, intermediate]);
  const validationDate = new Date().toISOString().replace(/[-:T]/g, '').replace(/\.\d{3}Z$/, 'Z');
  await chain.validate({
    // ASN.1 GeneralizedTime in UTC, never an untrusted receipt's signedTime.
    date: validationDate,
    trustAnchors: [{ CACert: trustedRoot }],
    trustSystemCa: false,
    keyUsage: [cert.KeyUsageType.KEYUSAGE_DIGITAL_SIGNATURE],
    // Obtain the certificate's OCSP/CRL status online and fail closed if it
    // cannot be checked. Never suppress network or certificate-revocation errors.
    revocationCheckParam: {
      options: [cert.RevocationCheckOptions.REVOCATION_CHECK_OPTION_ACCESS_NETWORK,
        cert.RevocationCheckOptions.REVOCATION_CHECK_OPTION_PREFER_OCSP,
        cert.RevocationCheckOptions.REVOCATION_CHECK_OPTION_FALLBACK_NO_PREFER]
    }
  });
  const oids = leaf.getExtensionsObject().getOidList(cert.ExtensionOidType.EXTENSION_OID_TYPE_ALL).data;
  let hasIapOid: boolean = false;
  for (const oid of oids) {
    // Native OID strings can include the C terminator; compare the complete OID.
    if (decodeText(oid).replace(/\u0000$/, '') === IAP_LEAF_OID) hasIapOid = true;
  }
  check(hasIapOid);
  const signature = base64UrlDecode(parts[2]);
  check(signature.length === 64);
  const derSignature = cryptoFramework.SignatureUtils.genEccSignature({
    r: integerBytes(signature.slice(0, 32)), s: integerBytes(signature.slice(32))
  });
  // Certificate PubKey instances are intended for X509Cert.verify. Reimport
  // the verified leaf's SPKI into CryptoFramework for the ES256 operation.
  const keyPair = await cryptoFramework.createAsyKeyGenerator('ECC256').convertKey(leaf.getPublicKey().getEncoded(), null);
  const verifier = cryptoFramework.createVerify('ECC256|SHA256');
  await verifier.init(keyPair.pubKey);
  const signedBytes = new util.TextEncoder().encodeInto(`${parts[0]}.${parts[1]}`);
  check(await verifier.verify({ data: signedBytes }, { data: derSignature }));

  // Interpret entitlement fields only after certificate and JWS verification.
  const order = JSON.parse(decodeText(base64UrlDecode(parts[1]))) as PurchaseOrderPayload;
  check(order !== null && typeof order === 'object' && !Array.isArray(order));
  check(order.applicationId === expectedApplicationId && order.productId === PRO_PRODUCT_ID && order.productType === '1');
  check(order.environment === (sandbox ? 'SANDBOX' : 'NORMAL'));
  check(nonempty(order.purchaseOrderId, 256) && nonempty(order.purchaseToken, 4096));
  check(validTimestamp(order.purchaseTime) && validTimestamp(order.signedTime));
  check(order.purchaseTime <= order.signedTime + 300000 && order.signedTime <= Date.now() + 300000);
  check(typeof order.price === 'number' && Number.isSafeInteger(order.price) && order.price >= 0);
  check(typeof order.currency === 'string' && /^[A-Z]{3}$/.test(order.currency));
  check(typeof order.countryCode === 'string' && /^[A-Z]{2}$/.test(order.countryCode));
  check(order.finishStatus === undefined || order.finishStatus === '1' || order.finishStatus === '2');
  check(order.needFinish === undefined || typeof order.needFinish === 'boolean');
  check(order.purchaseOrderRevocationReasonCode === undefined || nonempty(order.purchaseOrderRevocationReasonCode, 64));
  check(order.revocationTime === undefined || validTimestamp(order.revocationTime));
  const revoked = order.purchaseOrderRevocationReasonCode !== undefined || order.revocationTime !== undefined;
  return {
    applicationId: order.applicationId, productId: order.productId, productType: order.productType,
    purchaseOrderId: order.purchaseOrderId, purchaseToken: order.purchaseToken,
    purchaseTime: order.purchaseTime, finishStatus: order.finishStatus, needFinish: order.needFinish,
    environment: order.environment, signedTime: order.signedTime,
    price: order.price, currency: order.currency, revoked: revoked
  };
}
