function buildPaymentReference(applicantId) {
  const suffix = cryptoRandom().toUpperCase();
  return `${String(applicantId).replace(/-/g, "")}-${Date.now()}-${suffix}`;
}

function buildReceiptNumber(reference, paidAt = new Date().toISOString()) {
  const date = new Date(paidAt).toISOString().slice(0, 10).replace(/-/g, "");
  return `DSP2-${date}-${String(reference).slice(-6).toUpperCase()}`;
}

function cryptoRandom() {
  return require("node:crypto").randomBytes(8).toString("hex");
}

module.exports = {
  buildPaymentReference,
  buildReceiptNumber
};
