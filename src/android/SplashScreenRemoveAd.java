package org.apache.cordova.splashscreen;

import android.content.Context;
import android.os.AsyncTask;
import android.content.SharedPreferences;
import android.util.Log;

import org.apache.cordova.CordovaWebView;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SplashScreenRemoveAd implements Runnable {
    private static final String LOG_TAG = "SplashScreenRemoveAd";
    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private CordovaWebView webView;

    public SplashScreenRemoveAd(CordovaWebView webView) {
        this.webView = webView;
    }

    @Override
    public void run() {
        
        Context context = webView.getContext();
        String savePath = context.getFilesDir() + "/splashAd.png";
        File adFile = new File(savePath);
        
        if (adFile.exists()) {
            if (adFile.delete()) {
                Log.d(LOG_TAG, "Ad image file deleted.");
            } else {
                Log.e(LOG_TAG, "Failed to delete ad image file.");
            }
        }
        
        // SharedPreferences에서 광고 관련 데이터를 제거
        SharedPreferences sharedPref = context.getSharedPreferences(SplashScreen.SHARE_PREFERENCES_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPref.edit();
        
        // 광고 관련 데이터 키 삭제
        editor.remove("SplashId");
        editor.remove("SplashUpdatedAt");
        editor.remove("SplashBegin");
        editor.remove("SplashEnd");
        
        // 변경사항 적용
        editor.apply();
        
        Log.d(LOG_TAG, "Ad data removed from SharedPreferences.");
       
    }
    // 광고를 제거

    public static void removeAd(CordovaWebView webView ) {
        executor.submit(new SplashScreenRemoveAd(webView));
    }


}

