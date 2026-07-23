const { validateApplicantPayload } = require("../utils/validators");

function validateApplicant(request, response, next) {
  const error = validateApplicantPayload(request.body);
  if (error) {
    response.status(400).json({ error });
    return;
  }

  next();
}

function validatePaymentVerification(request, response, next) {
  if (!request.body?.applicantId || !request.body?.reference) {
    response.status(400).json({ error: "Applicant ID and payment reference are required." });
    return;
  }

  next();
}

module.exports = {
  validateApplicant,
  validatePaymentVerification
};
