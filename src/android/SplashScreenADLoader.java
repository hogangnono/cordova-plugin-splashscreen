package org.apache.cordova.splashscreen;

import org.apache.cordova.*;
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
    private CordovaPreferences preferences;
    private CordovaWebView webView;
    private CordovaInterface cordova;

    public SplashScreenADLoader(CordovaInterface cordova, CordovaWebView webView, CordovaPreferences preferences) {
        this.webView = webView;
        this.preferences = preferences;
        this.cordova = cordova;
    }

    @Override
    public void run() {
        String urlString = preferences.getString("SplashScreenImageUrl", "https://hogangnono.com/api/v2/ads?type=4");
        HttpURLConnection connection = null;
        try {
            URL url = new URL(urlString);
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("x-hogangnono-platform", "android");
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(5000);


            StringBuilder response = new StringBuilder();
            if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
                try (BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()))) {
                    String line;
                    while ((line = in.readLine()) != null) {
                        response.append(line);
                    }
                }

                JSONObject jsonResponse = new JSONObject(response.toString());
                JSONObject data = jsonResponse.getJSONObject("data");
                JSONArray adItems = data.getJSONArray("adItems");
                JSONObject adItem = adItems.getJSONObject(0);

                Context context = webView.getContext();
                SharedPreferences sharedPref = context.getSharedPreferences("SplashScreen", Context.MODE_PRIVATE);
                String savedAdItemString = sharedPref.getString("SplashAdItem", "{}");
                JSONObject savedAdItem = new JSONObject(savedAdItemString);
                String localPath = sharedPref.getString("SplashScreenImageLocalPath", "");

                long currentId = adItem.getLong("id");
                String currentUpdatedAt = adItem.getString("updatedAt");
                File file = new File(localPath);

                boolean adExists = savedAdItem.has("id") && savedAdItem.getLong("id") == currentId &&
                                   savedAdItem.has("updatedAt") && savedAdItem.getString("updatedAt").equals(currentUpdatedAt);

                if (adExists && file.exists()) {
                    Log.d(LOG_TAG, "Splash AD is up-to-date and already exists locally. No download needed.");
                }else {
                    String imageDomain = preferences.getString("SplashScreenImageDomain", "https://image.hogangnono.com");
                    String imageUrl = imageDomain +"/"+ adItem.getJSONObject("image").getString("key");
                    String savePath = context.getFilesDir() + "/splashAd.png";
                    downloadImage(imageUrl, savePath);

                    // Update SharedPreferences with new ad item and local path
                    SharedPreferences.Editor editor = sharedPref.edit();
                    editor.putString("SplashAdItem", adItem.toString());
                    editor.putString("SplashScreenImageLocalPath", savePath);
                    editor.apply();

                    Log.d(LOG_TAG, "New Splash AD downloaded and info updated.");
                } 
                
            } else {
                throw new IOException("HTTP error code: " + connection.getResponseCode());
            }
        } catch (Exception e) {
            Log.e(LOG_TAG, "Error during SplashScreen advertisement handling", e);
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private void downloadImage(String downloadUrl, String savePath) {
        HttpURLConnection connection = null;
        try {
            Log.d(LOG_TAG, "Image Downloaded: " + downloadUrl);
            URL url = new URL(downloadUrl);
            connection = (HttpURLConnection) url.openConnection();
            connection.connect();

            File outputFile = new File(savePath);
            if (!outputFile.getParentFile().exists()) outputFile.getParentFile().mkdirs();
            if (!outputFile.exists()) outputFile.createNewFile();

            try (InputStream is = connection.getInputStream(); OutputStream os = new FileOutputStream(outputFile)) {
                byte[] buffer = new byte[1024];
                int length;
                while ((length = is.read(buffer)) != -1) {
                    os.write(buffer, 0, length);
                }
            }
        } catch (Exception e) {
            Log.e(LOG_TAG, "Failed to download image"+ e.getMessage());
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    public static void initiateDownload(CordovaInterface cordova, CordovaWebView webView, CordovaPreferences preferences) {
        executor.submit(new SplashScreenADLoader(cordova, webView, preferences));
    }
}
