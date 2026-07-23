import type { CreateApplicantResponse } from "./application";

type PaystackCallback = (response: { reference: string; trans?: string }) => void;

type PaystackPopupConfig = {
  key: string;
  email: string;
  amount: number;
  currency: "NGN";
  ref: string;
  metadata: {
    custom_fields: Array<{
      display_name: string;
      variable_name: string;
      value: string;
    }>;
  };
  callback: PaystackCallback;
  onClose: () => void;
};

declare global {
  interface Window {
    PaystackPop?: {
      setup(config: PaystackPopupConfig): {
        openIframe(): void;
      };
    };
  }
}

const scriptId = "paystack-inline-js";

export function loadPaystack(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.PaystackPop) {
      resolve();
      return;
    }

    const existingScript = document.getElementById(scriptId) as HTMLScriptElement | null;
    if (existingScript) {
      existingScript.addEventListener("load", () => resolve(), { once: true });
      existingScript.addEventListener("error", () => reject(new Error("Paystack failed to load")), {
        once: true
      });
      return;
    }

    const script = document.createElement("script");
    script.id = scriptId;
    script.src = "https://js.paystack.co/v1/inline.js";
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Paystack failed to load"));
    document.head.appendChild(script);
  });
}

export async function openPaystackCheckout(
  payment: CreateApplicantResponse,
  onSuccess: PaystackCallback,
  onClose: () => void
): Promise<void> {
  const publicKey = process.env.NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY;
  if (!publicKey) {
    throw new Error("Paystack public key is not configured");
  }

  await loadPaystack();

  const popup = window.PaystackPop?.setup({
    key: publicKey,
    email: payment.email,
    amount: payment.amount,
    currency: payment.currency,
    ref: payment.paymentReference,
    metadata: {
      custom_fields: [
        {
          display_name: "Applicant ID",
          variable_name: "applicant_id",
          value: payment.applicantId
        }
      ]
    },
    callback: onSuccess,
    onClose
  });

  if (!popup) {
    throw new Error("Paystack checkout is unavailable");
  }

  popup.openIframe();
}

