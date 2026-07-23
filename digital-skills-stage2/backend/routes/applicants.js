const express = require("express");
const ApplicantController = require("../controllers/ApplicantController");
const { applicantLimiter } = require("../middleware/rateLimiter");
const { validateApplicant } = require("../middleware/validation");

const router = express.Router();

router.post("/", applicantLimiter, validateApplicant, ApplicantController.create);
router.get("/:id", ApplicantController.getById);
router.put("/:id", applicantLimiter, ApplicantController.update);

module.exports = router;
