const Stage1Service = require("../services/Stage1Service");

class Stage1Controller {
  async create(request, response, next) {
    try {
      const application = await Stage1Service.createApplication(request.body, request);
      response.status(201).json(application);
    } catch (error) {
      next(error);
    }
  }

  async getById(request, response, next) {
    try {
      const application = await Stage1Service.getApplication(request.params.id);
      response.status(200).json(application);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new Stage1Controller();
