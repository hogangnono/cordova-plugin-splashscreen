package org.apache.cordova.splashscreen;

import org.apache.cordova.*;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SplashScreenADLoader implements Runnable {
    private static final String LOG_TAG = "SplashScreenADLoader";
    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private CordovaWebView webView;
    private JSONArray args;

    public SplashScreenADLoader(CordovaWebView webView, JSONArray args) {
        this.webView = webView;
        this.args = args;
    }

    @Override
    public void run() {
        Context context = webView.getContext();
        HttpURLConnection connection = null;
        try {
            JSONObject options = this.args.getJSONObject(0);
            int id = options.getInt("id");
            String updatedAt = options.getString("updatedAt");
            String begin = options.getString("begin");
            String end = options.getString("end");
            String imageUrl = options.getString("url"); // 'imageUrl' 대신 'url' 사용
            String savePath = context.getFilesDir() + "/splashAd.png";

            SharedPreferences sharedPref = context.getSharedPreferences(SplashScreen.SHARE_PREFERENCES_NAME, Context.MODE_PRIVATE);
            int previousId = sharedPref.getInt("SplashId", -1);
            String previousUpdateAt = sharedPref.getString("SplashUpdatedAt", "");

            File outputFile = new File(savePath);
            // 추가된 조건: SplashId가 동일하고, 파일이 이미 존재하는 경우 다운로드 하지 않음
            if (id == previousId && updatedAt.equals(previousUpdateAt) && outputFile.exists()) {
                Log.d(LOG_TAG, "Image already downloaded and key matches. Skipping download.");
                return; // 다운로드를 진행하지 않고 메서드 종료
            }

            SharedPreferences.Editor editor = sharedPref.edit();
            editor.putInt("SplashId", id);
            editor.putString("SplashUpdatedAt", updatedAt);
            editor.putString("SplashBegin", begin);
            editor.putString("SplashEnd", end);
            editor.apply();

            URL url = new URL(imageUrl);
            connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(5000);
            connection.connect();

            if (!outputFile.getParentFile().exists()) outputFile.getParentFile().mkdirs();
            if (!outputFile.exists()) outputFile.createNewFile();

            try (InputStream is = connection.getInputStream(); OutputStream os = new FileOutputStream(outputFile)) {
                byte[] buffer = new byte[1024];
                int length;
                while ((length = is.read(buffer)) != -1) {
                    os.write(buffer, 0, length);
                }
                Log.d(LOG_TAG, "Image Downloaded: " + imageUrl);
            }
        } catch (JSONException e) {
            Log.e(LOG_TAG, "JSON parsing error: " + e.getMessage(), e);
        } catch (Exception e) {
            Log.e(LOG_TAG, "Failed to download image: " + e.getMessage(), e);
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    public static void initiateDownload(CordovaWebView webView, JSONArray args) {
        executor.submit(new SplashScreenADLoader(webView, args));
    }
}
