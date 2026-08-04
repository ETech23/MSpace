import axios, {
  AxiosError,
  type AxiosRequestConfig,
  type AxiosResponse
} from "axios";
import type {
  ApplicantPayload,
  CreateApplicantResponse,
  PaymentReceipt
} from "./application";
import type {
  Stage1ApplicationResponse,
  Stage1Payload
} from "./stage1";

const baseUrl =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

type ApiOptions = {
  adminKey?: string;
  csrfToken?: string;
  responseType?: "json" | "text";
};

const apiClient = axios.create({
  baseURL: baseUrl,
  timeout: 30000,
  withCredentials: true
});

apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const config = error.config as (AxiosRequestConfig & { retryCount?: number }) | undefined;
    const status = error.response?.status ?? 0;
    const canRetry =
      config &&
      (status === 0 || status === 408 || status === 429 || status >= 500) &&
      (config.retryCount ?? 0) < 2;

    if (canRetry) {
      const retryCount = (config.retryCount ?? 0) + 1;
      config.retryCount = retryCount;
      await new Promise((resolve) => setTimeout(resolve, 350 * retryCount));
      return apiClient(config);
    }

    return Promise.reject(error);
  }
);

async function apiRequest<T>(
  path: string,
  config: AxiosRequestConfig = {},
  options: ApiOptions = {}
): Promise<T> {
  const headers: Record<string, string> = {};
  if (options.adminKey) {
    headers["X-Admin-Key"] = options.adminKey;
  }
  if (options.csrfToken) {
    headers["X-CSRF-Token"] = options.csrfToken;
  }

  try {
    const response: AxiosResponse<T> = await apiClient.request<T>({
      ...config,
      url: path,
      headers: {
        ...config.headers,
        ...headers
      },
      responseType: options.responseType === "text" ? "text" : "json"
    });
    return response.data;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      const responseData = error.response?.data as { error?: string } | string | undefined;
      const message =
        typeof responseData === "object" && responseData?.error
          ? responseData.error
          : typeof responseData === "string"
            ? responseData
            : error.message;
      throw new Error(message || "Request failed");
    }
    throw error;
  }
}

export async function getCsrfToken(): Promise<string> {
  const response = await apiRequest<{ csrfToken: string }>("/api/csrf");
  return response.csrfToken;
}

export function createApplicant(
  payload: ApplicantPayload,
  csrfToken: string
): Promise<CreateApplicantResponse> {
  return apiRequest<CreateApplicantResponse>(
    "/api/applicants",
    {
      method: "POST",
      data: payload
    },
    { csrfToken }
  );
}

export function verifyPayment(
  applicantId: string,
  reference: string,
  csrfToken: string
): Promise<PaymentReceipt> {
  return apiRequest<PaymentReceipt>(
    "/api/payments/verify",
    {
      method: "POST",
      data: { applicantId, reference }
    },
    { csrfToken }
  );
}

export function getAdminDashboard(
  adminKey: string,
  query: URLSearchParams
): Promise<unknown> {
  return apiRequest(`/api/admin/dashboard?${query.toString()}`, {}, { adminKey });
}

export function exportApplicants(
  adminKey: string,
  query: URLSearchParams
): Promise<string> {
  return apiRequest<string>(
    `/api/admin/export?${query.toString()}`,
    {},
    { adminKey, responseType: "text" }
  );
}

export function createStage1Application(
  payload: Stage1Payload,
  csrfToken: string
): Promise<Stage1ApplicationResponse> {
  return apiRequest<Stage1ApplicationResponse>(
    "/api/stage1/applications",
    {
      method: "POST",
      data: payload
    },
    { csrfToken }
  );
}

export function getStage1Application(applicantId: string): Promise<unknown> {
  return apiRequest(`/api/stage1/applications/${encodeURIComponent(applicantId)}`);
}
