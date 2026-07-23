const axios = require("axios");

const paystackClient = axios.create({
  baseURL: "https://api.paystack.co",
  timeout: 20000,
  headers: {
    Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
    "Content-Type": "application/json"
  }
});

module.exports = {
  paystackClient
};
