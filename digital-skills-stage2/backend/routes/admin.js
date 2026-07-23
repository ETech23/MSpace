const express = require("express");
const AdminController = require("../controllers/AdminController");
const { requireAdmin } = require("../middleware/auth");
const { adminLimiter } = require("../middleware/rateLimiter");

const router = express.Router();

router.use(adminLimiter, requireAdmin);
router.get("/dashboard", AdminController.dashboard);
router.get("/applicants", AdminController.applicants);
router.get("/payments", AdminController.payments);
router.get("/export", AdminController.export);

module.exports = router;
