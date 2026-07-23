const app = require("./app");
const logger = require("./utils/logger");

const port = Number(process.env.PORT || 8080);

app.listen(port, () => {
  logger.info(`Express backend listening on port ${port}`);
});
