const express = require("express");
const Stage1Controller = require("../controllers/Stage1Controller");
const { applicantLimiter } = require("../middleware/rateLimiter");

const router = express.Router();

router.post("/", applicantLimiter, Stage1Controller.create);
router.get("/:id", Stage1Controller.getById);

module.exports = router;
