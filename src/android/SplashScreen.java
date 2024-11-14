/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
*/

package org.apache.cordova.splashscreen;

import static android.content.Context.MODE_PRIVATE;

import android.app.Dialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;

import com.hogangnono.hogangnono.R;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;
import org.apache.cordova.PluginResult;


public class SplashScreen extends CordovaPlugin {
    public static final String SHARE_PREFERENCES_NAME = "SplashScreen";
    private static final String LOG_TAG = "SplashScreen";
    private static final boolean HAS_BUILT_IN_SPLASH_SCREEN = false;
    private static final int DEFAULT_SPLASHSCREEN_DURATION = 3000;
    private static final int DEFAULT_FADE_DURATION = 500;
    private static Dialog splashDialog;
    private static boolean firstShow = true;
    private static boolean lastHideAfterDelay; // https://issues.apache.org/jira/browse/CB-9094

    private boolean isAdDisplayed = false;
    private int splashScreenAdId = -1;

    /**
     * Remember last device orientation to detect orientation changes.
     */
    private int orientation;

    // Helper to be compile-time compatible with both Cordova 3.x and 4.x.
    private View getView() {
        try {
            return (View)webView.getClass().getMethod("getView").invoke(webView);
        } catch (Exception e) {
            return (View)webView;
        }
    }

    private int getSplashId() {
        int layoutId = 0;
        String splashResource = preferences.getString("SplashScreen", "screen");
        if (splashResource != null) {
            layoutId = cordova.getActivity().getResources().getIdentifier(splashResource, "layout", cordova.getActivity().getClass().getPackage().getName());
            if (layoutId == 0) {
                layoutId = cordova.getActivity().getResources().getIdentifier(splashResource, "layout", cordova.getActivity().getPackageName());
            }
        }
        return layoutId;
    }

    @Override
    protected void pluginInitialize() {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // Make WebView invisible while loading URL
        // CB-11326 Ensure we're calling this on UI thread
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                getView().setVisibility(View.INVISIBLE);
            }
        });

        // Save initial orientation.
        orientation = cordova.getActivity().getResources().getConfiguration().orientation;

        if (firstShow) {
            boolean autoHide = preferences.getBoolean("AutoHideSplashScreen", true);
            showSplashScreen(autoHide);
        }

        if (preferences.getBoolean("SplashShowOnlyFirstTime", true)) {
            firstShow = false;
        }
    }

    /**
     * Shorter way to check value of "SplashMaintainAspectRatio" preference.
     */
    private boolean isMaintainAspectRatio () {
        return preferences.getBoolean("SplashMaintainAspectRatio", false);
    }

    private int getFadeDuration () {
        int fadeSplashScreenDuration = preferences.getBoolean("FadeSplashScreen", true) ?
            preferences.getInteger("FadeSplashScreenDuration", DEFAULT_FADE_DURATION) : 0;

        if (fadeSplashScreenDuration < 30) {
            // [CB-9750] This value used to be in decimal seconds, so we will assume that if someone specifies 10
            // they mean 10 seconds, and not the meaningless 10ms
            fadeSplashScreenDuration *= 1000;
        }

        return fadeSplashScreenDuration;
    }

    @Override
    public void onPause(boolean multitasking) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // hide the splash screen to avoid leaking a window
        this.removeSplashScreen(true);
    }

    @Override
    public void onDestroy() {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // hide the splash screen to avoid leaking a window
        this.removeSplashScreen(true);
        // If we set this to true onDestroy, we lose track when we go from page to page!
        //firstShow = true;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("hide")) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    webView.postMessage("splashscreen", "hide");
                }
            });
        } else if (action.equals("show")) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    webView.postMessage("splashscreen", "show");
                }
            });
        } else if (action.equals("settingAd")) {

            SplashScreenADLoader.initiateDownload( webView, args);

        } else if (action.equals("removeAd")) {

            SplashScreenRemoveAd.removeAd( webView);

        } else if (action.equals("info")) {            
            JSONObject result = new JSONObject();
            try {
                result.put("id", splashScreenAdId); 
                result.put("isAdDisplayed", isAdDisplayed); 
            } catch (JSONException e) {
                e.printStackTrace();
            }
            
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, result);
            pluginResult.setKeepCallback(true);
            callbackContext.sendPluginResult(pluginResult);
            return true;
        } else {
            return false;
        }

        callbackContext.success();
        return true;
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return null;
        }
        if ("splashscreen".equals(id)) {
            if ("hide".equals(data.toString())) {
                this.removeSplashScreen(false);
            } else {
                this.showSplashScreen(false);
            }
        } else if ("spinner".equals(id)) {
            if ("stop".equals(data.toString())) {
                getView().setVisibility(View.VISIBLE);
            }
        }
        return null;
    }

    // Don't add @Override so that plugin still compiles on 3.x.x for a while
    public void onConfigurationChanged(Configuration newConfig) {
        if (newConfig.orientation != orientation) {
            orientation = newConfig.orientation;

            // Splash drawable may change with orientation, so reload it.
            if (splashDialog != null) {
                int layoutId = getSplashId();
                if (layoutId != 0) {
                    splashDialog.setContentView(layoutId);
                }
            }
        }
    }


    private void removeSplashScreen(final boolean forceHideImmediately) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        cordova.getActivity().runOnUiThread(new Runnable() {
            public void run() {
                if (splashDialog != null && splashDialog.isShowing()) {//check for non-null splashImageView, see https://issues.apache.org/jira/browse/CB-12277
                    Context context = webView.getContext();
                    SharedPreferences prefs = context.getSharedPreferences(SHARE_PREFERENCES_NAME, MODE_PRIVATE);
                    final int delayTime = prefs.getInt("SplashDelayTime", 0);
                    if (delayTime > 0 && forceHideImmediately == false) {
                        final Handler handler = new Handler();
                        handler.postDelayed(new Runnable() {
                            public void run() {
                                if (splashDialog != null) {
                                    splashDialog.dismiss();
                                    splashDialog = null;
                                }
                            }
                        }, delayTime);
                    } else {
                        splashDialog.dismiss();
                        splashDialog = null;
                    }
                }
            }
        });
    }

    /**
     * Shows the splash screen over the full Activity
     */
    @SuppressWarnings("deprecation")
    private void showSplashScreen(final boolean hideAfterDelay) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        final int splashscreenTime = preferences.getInteger("SplashScreenDelay", DEFAULT_SPLASHSCREEN_DURATION);
        final int layoutId = getSplashId();

        final int fadeSplashScreenDuration = getFadeDuration();
        final int effectiveSplashDuration = Math.max(0, splashscreenTime - fadeSplashScreenDuration);

        lastHideAfterDelay = hideAfterDelay;

        // Prevent to show the splash dialog if the activity is in the process of finishing
        if (cordova.getActivity().isFinishing()) {
            return;
        }
        // If the splash dialog is showing don't try to show it again
        if (splashDialog != null && splashDialog.isShowing()) {
            return;
        }
        if (layoutId == 0 || (splashscreenTime <= 0 && hideAfterDelay)) {
            return;
        }

        cordova.getActivity().runOnUiThread(new Runnable() {
            public void run() {
                // Get reference to display
                Context context = webView.getContext();

                // Create and show the dialog
                splashDialog = new Dialog(context, R.style.Theme_Custom_Splash);
                // check to see if the splash screen should be full screen
                if ((cordova.getActivity().getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN)
                        == WindowManager.LayoutParams.FLAG_FULLSCREEN) {
                    splashDialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                            WindowManager.LayoutParams.FLAG_FULLSCREEN);
                }

                splashDialog.setContentView(layoutId);
                splashDialog.setCancelable(false);
                splashDialog.show();

                updateAdImage();

                // Set Runnable to remove splash screen just in case
                if (hideAfterDelay) {
                    final Handler handler = new Handler();
                    handler.postDelayed(new Runnable() {
                        public void run() {
                            if (lastHideAfterDelay) {
                                removeSplashScreen(true);
                            }
                        }
                    }, effectiveSplashDuration);
                }
            }
        });
    }

    private void updateAdImage() {
        ImageView adImageView = splashDialog.findViewById(R.id.ad_image);
        if (adImageView != null) {
            // 광고 이미지 표시 여부 결정
            if (shouldDisplaySplashScreenAd()) {
                loadAndDisplaySplashScreenAdImage();
            }
        }
    }

    /**
     * 광고 이미지 표시 여부를 결정하는 함수
     * - SharedPreferences에 저장된 광고 begin과 end를 비교하여 현재 시간이 광고 기간에 속하는지 확인
     */
    private boolean shouldDisplaySplashScreenAd() {
        Context context = webView.getContext();
        SharedPreferences prefs = context.getSharedPreferences(SHARE_PREFERENCES_NAME, MODE_PRIVATE);
        String beginString = prefs.getString("SplashBegin", null);
        String endString = prefs.getString("SplashEnd", null);
        int id = prefs.getInt("SplashId", -1);
        splashScreenAdId = id;
        Log.w(LOG_TAG, "beginString="+beginString);
        Log.w(LOG_TAG, "endString="+endString);


        if (beginString != null && endString != null) {
            try {
                Date beginDate = convertUtcStringToDate(beginString);
                Date endDate = convertUtcStringToDate(endString);
                Date now = new Date();
                return now.after(beginDate) && now.before(endDate);
            } catch (Exception e) {
                Log.e(LOG_TAG, "SplashAdItem JSON 파싱 또는 날짜 에러", e);
                return false;
            }
        } else {
            return false;
        }
    }

    /**
     * 광고 이미지를 불러와서 표시하는 함수
     * - SharedPreferences에서 저장된 이미지 파일 경로를 불러와서 이미지를 표시
     */
    private void loadAndDisplaySplashScreenAdImage() {
        Context context = webView.getContext();
        String imagePath = context.getFilesDir() + "/splashAd.png";
        ImageView adImageView = splashDialog.findViewById(R.id.ad_image);

        if (adImageView != null && imagePath != null) {
            try {
                File file = new File(imagePath);
                if (file.exists()) {
                    Bitmap bitmap = BitmapFactory.decodeFile(imagePath);
                    adImageView.setImageBitmap(bitmap);
                    isAdDisplayed = true;
                }
            } catch (Exception e) {
            }

            Log.d(LOG_TAG, "SplashScreenActivity - imagePath:" + imagePath);
            // imagePath가 유효한 경로인 경우, 이미지 로딩 라이브러리를 사용하여 표시
        } else {
            Log.d(LOG_TAG, "SplashScreenActivity - 광고 이미지를 찾을 수 없거나 경로가 유효하지 않음");
        }
    }


    private static Date convertUtcStringToDate(String utcString) {
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
        dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
        try {
            return dateFormat.parse(utcString);
        } catch (ParseException e) {
            e.printStackTrace();
            return null;
        }
    }
}
