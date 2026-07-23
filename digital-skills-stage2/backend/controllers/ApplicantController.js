const ApplicantService = require("../services/ApplicantService");

class ApplicantController {
  async create(request, response, next) {
    try {
      const applicant = await ApplicantService.createApplicant(request.body, request);
      response.status(201).json(applicant);
    } catch (error) {
      next(error);
    }
  }

  async getById(request, response, next) {
    try {
      const applicant = await ApplicantService.getApplicant(request.params.id);
      response.status(200).json(applicant);
    } catch (error) {
      next(error);
    }
  }

  async update(request, response, next) {
    try {
      const applicant = await ApplicantService.updateApplicant(request.params.id, request.body);
      response.status(200).json(applicant);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ApplicantController();
