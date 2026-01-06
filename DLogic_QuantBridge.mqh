//+------------------------------------------------------------------+
//|                                          DLogic_QuantBridge.mqh |
//|                                 Project: D-LOGIC QUANT v5.0     |
//|                     Bridge: MT5 <-> Google Colab (ngrok tunnel) |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"

#include "DLogic_QuantDash.mqh"

//+------------------------------------------------------------------+
//| QUANT Bridge Class - Communication with Colab                    |
//+------------------------------------------------------------------+
class C_QuantBridge {
private:
      string   m_url;
      int      m_timeout;
      int      m_priceCount;    // Number of price bars to send

      // --- JSON EXTRACTION ---
      string ExtractString(string json, string key) {
            string search = "\"" + key + "\":";
            int start = StringFind(json, search);
            if(start == -1) return "";
            start += StringLen(search);

            // Skip whitespace and quotes
            while(start < StringLen(json) && (StringSubstr(json, start, 1) == " " || StringSubstr(json, start, 1) == "\"")) start++;

            int end = start;
            string delim = StringSubstr(json, start-1, 1) == "\"" ? "\"" : ",";
            while(end < StringLen(json) && StringSubstr(json, end, 1) != delim && StringSubstr(json, end, 1) != "}") end++;

            return StringSubstr(json, start, end-start);
      }

      int ExtractInt(string json, string key) {
            string val = ExtractString(json, key);
            return (int)StringToInteger(val);
      }

      double ExtractDouble(string json, string key) {
            string val = ExtractString(json, key);
            StringReplace(val, ",", "");
            return StringToDouble(val);
      }

      bool ExtractBool(string json, string key) {
            string val = ExtractString(json, key);
            return (val == "true" || val == "True" || val == "1");
      }

      // --- BUILD PRICE ARRAY JSON ---
      string BuildPriceArray() {
            double closes[];
            int copied = CopyClose(_Symbol, PERIOD_H1, 0, m_priceCount, closes);

            if(copied < 20) {
                  Print("[QUANT BRIDGE] Error: Not enough price data. Got: ", copied);
                  return "[]";
            }

            string result = "[";
            for(int i=0; i<copied; i++) {
                  result += DoubleToString(closes[i], 5);
                  if(i < copied-1) result += ",";
            }
            result += "]";

            return result;
      }

public:
      C_QuantBridge() {
            m_url = "http://127.0.0.1:5000/analyze";  // Default local
            m_timeout = 20000;  // 20 seconds for Colab
            m_priceCount = 100; // 100 H1 candles for analysis
      }

      // Set ngrok URL from Colab
      void SetEndpoint(string url) {
            m_url = url;
            Print("[QUANT BRIDGE] Endpoint set: ", m_url);
      }

      string GetEndpoint() { return m_url; }

      // Main query function
      bool SendQuery(string h4, string h1, string zone, string liq, string sig, string time, QuantResponse &result) {

            // Build price array
            string prices = BuildPriceArray();

            // Build JSON payload
            string jsonPayload = StringFormat(
                  "{\"prices\":%s,\"h4_bias\":\"%s\",\"h1_bias\":\"%s\",\"zone\":\"%s\",\"liquidity\":\"%s\",\"signals\":\"%s\",\"time\":\"%s\",\"symbol\":\"%s\"}",
                  prices, h4, h1, zone, liq, sig, time, _Symbol
            );

            char postData[];
            int len = StringToCharArray(jsonPayload, postData, 0, WHOLE_ARRAY, CP_UTF8);

            // Remove NULL terminator
            if(len > 0) ArrayResize(postData, len - 1);

            char resData[];
            string headers = "Content-Type: application/json\r\n";

            Print("[QUANT BRIDGE] Sending request to: ", m_url);
            Print("[QUANT BRIDGE] Payload size: ", ArraySize(postData), " bytes");

            // Send HTTP request
            int res = WebRequest("POST", m_url, headers, m_timeout, postData, resData, headers);

            if(res == 200) {
                  string rawJson = CharArrayToString(resData, 0, WHOLE_ARRAY, CP_UTF8);
                  Print("[QUANT BRIDGE] Response received: ", StringLen(rawJson), " chars");

                  // Parse response
                  result.decision = ExtractString(rawJson, "decision");
                  result.confidence = ExtractInt(rawJson, "confidence");
                  result.comment = ExtractString(rawJson, "comment");

                  // Risk metrics
                  result.var_95 = ExtractDouble(rawJson, "var_95");
                  result.cvar = ExtractDouble(rawJson, "cvar");
                  result.sharpe = ExtractDouble(rawJson, "sharpe");
                  result.sortino = ExtractDouble(rawJson, "sortino");
                  result.max_dd = ExtractDouble(rawJson, "max_dd");
                  result.volatility = ExtractDouble(rawJson, "volatility");

                  // Regime
                  result.regime = ExtractString(rawJson, "regime");
                  result.regime_conf = ExtractInt(rawJson, "regime_conf");

                  // Trend
                  result.trend_strength = ExtractInt(rawJson, "trend_strength");
                  result.trend_dir = ExtractString(rawJson, "trend_dir");

                  // Probability
                  result.prob_profit = ExtractInt(rawJson, "prob_profit");
                  result.expected_ret = ExtractDouble(rawJson, "expected_ret");

                  // Anomaly
                  result.is_anomaly = ExtractBool(rawJson, "is_anomaly");
                  result.anomaly_score = ExtractDouble(rawJson, "anomaly_score");

                  // Distribution
                  result.skewness = ExtractDouble(rawJson, "skewness");
                  result.kurtosis = ExtractDouble(rawJson, "kurtosis");

                  Print("[QUANT BRIDGE] Decision: ", result.decision, " | Conf: ", result.confidence, "%");
                  return true;

            } else {
                  Print("[QUANT BRIDGE] HTTP Error: ", res);
                  if(ArraySize(resData) > 0)
                        Print("[QUANT BRIDGE] Server msg: ", CharArrayToString(resData));

                  // Return default values on error
                  result.decision = "WAIT";
                  result.confidence = 0;
                  result.comment = "Connection error (code: " + IntegerToString(res) + ")";
                  result.regime = "UNKNOWN";
                  result.trend_dir = "NONE";
                  result.prob_profit = 50;

                  return false;
            }
      }

      // Health check
      bool CheckHealth() {
            string healthUrl = m_url;
            StringReplace(healthUrl, "/analyze", "/health");

            char postData[], resData[];
            string headers = "";

            int res = WebRequest("GET", healthUrl, headers, 5000, postData, resData, headers);

            if(res == 200) {
                  string response = CharArrayToString(resData);
                  Print("[QUANT BRIDGE] Health check OK: ", response);
                  return true;
            }

            Print("[QUANT BRIDGE] Health check FAILED: ", res);
            return false;
      }
};
