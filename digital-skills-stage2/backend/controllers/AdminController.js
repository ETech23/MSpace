const { escapeHtml } = require("../utils/helpers");
const { FirestoreService, formatTimestamp } = require("../services/FirestoreService");

class AdminController {
  async dashboard(request, response, next) {
    try {
      const applicants = await FirestoreService.listApplicants(request.query);
      const stats = applicants.reduce(
        (accumulator, applicant) => {
          const paymentStatus = String(applicant.paymentStatus ?? "Pending");
          const verificationStatus = String(applicant.verificationStatus ?? "");
          if (paymentStatus === "Paid") {
            accumulator.paid += 1;
            accumulator.revenue += Number(applicant.amountPaid ?? 0);
          } else {
            accumulator.pending += 1;
          }
          if (verificationStatus === "Rejected") {
            accumulator.rejected += 1;
          }
          if (verificationStatus === "Approved") {
            accumulator.approved += 1;
          }
          return accumulator;
        },
        { pending: 0, paid: 0, rejected: 0, approved: 0, revenue: 0 }
      );

      response.status(200).json({
        stats,
        charts: {
          bySkill: countBy(applicants, "preferredDigitalSkill"),
          byState: countBy(applicants, "state"),
          byPaymentStatus: countBy(applicants, "paymentStatus")
        },
        applicants: applicants.map(toApplicantRow)
      });
    } catch (error) {
      next(error);
    }
  }

  async applicants(request, response, next) {
    try {
      const applicants = await FirestoreService.listApplicants(request.query);
      response.status(200).json({ applicants: applicants.map(toApplicantRow) });
    } catch (error) {
      next(error);
    }
  }

  async payments(request, response, next) {
    try {
      const payments = await FirestoreService.listPayments(request.query);
      response.status(200).json({
        payments: payments.map((payment) => ({
          applicantId: String(payment.applicantId ?? ""),
          amount: Number(payment.amountPaid ?? payment.amount ?? 0),
          currency: String(payment.currency ?? "NGN"),
          paymentReference: String(payment.paymentReference ?? payment.id ?? ""),
          paymentStatus: String(payment.paymentStatus ?? ""),
          receiptNumber: String(payment.receiptNumber ?? ""),
          paidAt: formatTimestamp(payment.paidAt),
          createdAt: formatTimestamp(payment.createdAt)
        }))
      });
    } catch (error) {
      next(error);
    }
  }

  async export(request, response, next) {
    try {
      const applicants = await FirestoreService.listApplicants(request.query);
      const rows = applicants.map(toApplicantRow);
      const format = String(request.query.format ?? "csv");
      const stageName = String(request.query.stage ?? "all").toLowerCase() === "stage1"
        ? "stage1"
        : String(request.query.stage ?? "all").toLowerCase() === "stage2"
          ? "stage2"
          : "digital-skills";

      if (format === "excel") {
        response.setHeader("Content-Type", "application/vnd.ms-excel; charset=utf-8");
        response.setHeader(
          "Content-Disposition",
          `attachment; filename=${stageName}-applicants.xls`
        );
        response.status(200).send(toExcelHtml(rows));
        return;
      }

      response.setHeader("Content-Type", "text/csv; charset=utf-8");
      response.setHeader(
        "Content-Disposition",
        `attachment; filename=${stageName}-applicants.csv`
      );
      response.status(200).send(toCsv(rows));
    } catch (error) {
      next(error);
    }
  }
}

function toApplicantRow(applicant) {
  return {
    applicantId: String(applicant.applicantId ?? ""),
    fullName: `${String(applicant.firstName ?? "")} ${String(applicant.lastName ?? "")}`.trim(),
    email: String(applicant.email ?? ""),
    phone: String(applicant.phone ?? ""),
    state: String(applicant.state ?? ""),
    preferredDigitalSkill: String(
      applicant.preferredDigitalSkill ?? applicant.primarySkill ?? ""
    ),
    paymentStatus: String(applicant.paymentStatus ?? ""),
    stage: String(applicant.stage ?? ""),
    verificationStatus: String(applicant.verificationStatus ?? ""),
    submittedAt: formatTimestamp(applicant.submissionTime)
  };
}

function countBy(items, field) {
  return items.reduce((accumulator, item) => {
    const key = String(
      field === "preferredDigitalSkill"
        ? item.preferredDigitalSkill ?? item.primarySkill ?? "Unknown"
        : item[field] ?? "Unknown"
    );
    accumulator[key] = (accumulator[key] ?? 0) + 1;
    return accumulator;
  }, {});
}

function toCsv(rows) {
  const headers = [
    "Applicant ID",
    "Full Name",
    "Email",
    "Phone",
    "State",
    "Skill",
    "Payment Status",
    "Stage",
    "Verification Status",
    "Submitted At"
  ];
  const values = rows.map((row) => [
    row.applicantId,
    row.fullName,
    row.email,
    row.phone,
    row.state,
    row.preferredDigitalSkill,
    row.paymentStatus,
    row.stage,
    row.verificationStatus,
    row.submittedAt
  ]);
  return [headers, ...values]
    .map((row) => row.map((value) => `"${String(value).replace(/"/g, '""')}"`).join(","))
    .join("\n");
}

function toExcelHtml(rows) {
  const htmlRows = rows
    .map(
      (row) =>
        `<tr><td>${escapeHtml(row.applicantId)}</td><td>${escapeHtml(
          row.fullName
        )}</td><td>${escapeHtml(row.email)}</td><td>${escapeHtml(
          row.phone
        )}</td><td>${escapeHtml(row.state)}</td><td>${escapeHtml(
          row.preferredDigitalSkill
        )}</td><td>${escapeHtml(row.paymentStatus)}</td><td>${escapeHtml(
          row.stage
        )}</td><td>${escapeHtml(row.verificationStatus)}</td><td>${escapeHtml(
          row.submittedAt
        )}</td></tr>`
    )
    .join("");

  return `<table><thead><tr><th>Applicant ID</th><th>Full Name</th><th>Email</th><th>Phone</th><th>State</th><th>Skill</th><th>Payment Status</th><th>Stage</th><th>Verification Status</th><th>Submitted At</th></tr></thead><tbody>${htmlRows}</tbody></table>`;
}

module.exports = new AdminController();
